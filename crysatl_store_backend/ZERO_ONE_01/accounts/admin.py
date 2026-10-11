from django.contrib import admin, messages
from django.shortcuts import render, redirect
from django.urls import path
from django.db.models import Sum, Count
from django.utils.html import format_html
from django.contrib.auth.models import User
from .models import Reports  # استيراد الموديل الوهمي
# استيراد الموديلات الخاصة بالحسابات
from .models import Notification, UserNotification, UserProfile, Balance_add, PaymentMethod
    
# استيراد موديلات الطلبات من تطبيق orders
from orders.models import Order, OrderDetails
from products.models import Product,Package,Category
from datetime import timedelta
from django.utils import timezone

class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'balance', 'level', 'currency', 'phone')
    search_fields = ('user__username', 'user__email')
    list_filter = ('level', 'currency', 'is_active') if hasattr(UserProfile, 'is_active') else ('level', 'currency')
    
    def total_balance_all_users(self, obj):
        # جمع كل الرصيد من قاعدة البيانات
        total = UserProfile.objects.aggregate(total_balance=Sum('balance'))['total_balance'] or 0
        return f"${total}"

    total_balance_all_users.short_description = "إجمالي الرصيد لجميع المستخدمين"
    

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('title', 'created_at', 'is_sent', 'view_users', 'mark_as_sent_button')
    list_filter = ('created_at', 'is_sent')
    search_fields = ('title', 'message')

    # عرض عدد المستخدمين الذين تلقوا الإشعار
    def view_users(self, obj):
        return obj.usernotification_set.count()

    view_users.short_description = 'عدد المستخدمين'
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related()

    def mark_as_sent_button(self, obj):
        if not obj.is_sent:
            return format_html(
                '<a class="button" href="{}">تعيين كمرسل</a>', 
                f'/admin/{obj._meta.app_label}/{obj._meta.model_name}/{obj.id}/mark_as_sent/'
            )
        return "تم الإرسال"

    mark_as_sent_button.short_description = 'حالة الإرسال'

    # تخصيص الإجراء لإرسال الإشعار للمستخدمين عند تغييره إلى "تم الإرسال"
    def save_model(self, request, obj, form, change):
        if obj.is_sent and not change:  # إذا كانت الإشعارات جديدة وليست محدثة
            # أولاً احفظ الإشعار
            super().save_model(request, obj, form, change)

            # ثم إضافة إشعار لجميع المستخدمين (بدون تخصيص إشعار لكل مستخدم)
            users = User.objects.all()
            for user in users:
                # إنشاء أو جلب الكائن UserNotification الذي يربط المستخدم بالإشعار
                UserNotification.objects.get_or_create(user=user, notification=obj)
        else:
            super().save_model(request, obj, form, change)

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('<int:pk>/mark_as_sent/', self.mark_as_sent, name='mark_as_sent'),
        ]
        return custom_urls + urls

    def mark_as_sent(self, request, pk):
        notification = self.get_object(request, pk)
        notification.is_sent = True
        notification.save()

        # إرسال الإشعارات إلى جميع المستخدمين
        users = User.objects.all()
        for user in users:
            UserNotification.objects.get_or_create(user=user, notification=notification)

        self.message_user(request, "تم تعيين الإشعار كمرسل.")
        return redirect('admin:%s_%s_changelist' % (self.model._meta.app_label, self.model._meta.model_name))



class PaymentMethodAdmin(admin.ModelAdmin):
    list_display = ('name', 'discount_percentage', 'image', 'details')
    search_fields = ('name',)
    list_filter = ('discount_percentage',)

class BalanceAddAdmin(admin.ModelAdmin):
    list_display = ('user', 'amount', 'is_processed', 'created_at', 'payment_method', 'receipt')
    search_fields = ('user__username', 'payment_method__name')
    list_filter = ('is_processed', 'payment_method', 'created_at')
    readonly_fields = ('amount', 'created_at', 'receipt', 'payment_method', 'user')
    
    def mark_as_processed(self, request, queryset):
        updated = queryset.update(is_processed=True)
        self.message_user(request, f'تم تعيين {updated} طلب كمعالج.', messages.SUCCESS)
    mark_as_processed.short_description = "تعيين كمعالج"
    
    actions = [mark_as_processed]
    
    
# ==============================
# صفحة التقارير
# ==============================
class ReportsAdmin(admin.ModelAdmin):
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path("", self.admin_site.admin_view(self.reports_view), name="reports"),
        ]
        return custom_urls + urls

    def reports_view(self, request):
        today = timezone.now()
        last_7_days = today - timedelta(days=7)

        total_users = User.objects.count()
        active_users = User.objects.filter(is_active=True).count()
        new_users_last_7_days = User.objects.filter(date_joined__gte=last_7_days).count()

        total_orders = Order.objects.count()
        cancelled_orders = OrderDetails.objects.filter(status='rejected').count()

        avg_orders_per_user = total_orders / total_users if total_users else 0

        total_revenue = OrderDetails.objects.aggregate(total=Sum("price"))["total"] or 0

        top_products = (
            OrderDetails.objects.values("Package__name")
            .annotate(total_sold=Count("id"), total_revenue=Sum("price"))
            .order_by("-total_sold")[:20]
        )
        total_products = Product.objects.count()
        total_packages = Package.objects.count()
        total_categories = Category.objects.count()
        total_balance = UserProfile.objects.aggregate(total_balance=Sum('balance'))['total_balance'] or 0


        context = dict(
            self.admin_site.each_context(request),
            title="التقارير",
            total_users=total_users,
            active_users=active_users,
            new_users_last_7_days=new_users_last_7_days,
            total_orders=total_orders,
            cancelled_orders=cancelled_orders,
            avg_orders_per_user=avg_orders_per_user,
            total_revenue=total_revenue,
            total_balance=total_balance,
            top_products=top_products,
            total_products=total_products,
            total_packages=total_packages,
            total_categories=total_categories,
            
        )
        return render(request, "admin/reports.html", context)


# ==============================
# ربط صفحة التقارير بالـ AdminSite
# ==============================
def add_reports_view(admin_site):
    """إضافة صفحة التقارير بأمان"""
    reports_admin = ReportsAdmin()
    reports_admin.admin_site = admin_site
    admin_site.get_urls = lambda old_get_urls=admin_site.get_urls: reports_admin.get_urls() + old_get_urls()
# تسجيل الموديل الوهمي
admin.site.register(Reports, ReportsAdmin)




# ==============================
# تسجيل كل الموديلات في لوحة التحكم
# ==============================
admin.site.register(PaymentMethod, PaymentMethodAdmin)
admin.site.register(Balance_add, BalanceAddAdmin)
admin.site.register(UserProfile, UserProfileAdmin)



