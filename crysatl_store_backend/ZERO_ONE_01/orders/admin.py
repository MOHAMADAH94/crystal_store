# from django.contrib import admin, messages
# from django.http import HttpResponseRedirect
# from django.urls import path, reverse
# from django.utils.html import format_html
# from decimal import Decimal
# from django.core.mail import send_mail
# from django.conf import settings
# from django.utils import timezone
# from datetime import timedelta

# from .models import Order, OrderDetails, MailSender

# # =========================
# # Inline لتفاصيل الطلب داخل Order
# class OrderDetailsInline(admin.TabularInline):
#     model = OrderDetails
#     extra = 0
#     readonly_fields = ('Package', 'gamer_id', 'price', 'quantity', 'status')


# # =========================
# # فلتر التاريخ الزمني المصحح
# class OrderDateFilter(admin.SimpleListFilter):
#     title = 'By order date'
#     parameter_name = 'order_date'

#     def lookups(self, request, model_admin):
#         return [
#             ('any', 'Any date'),
#             ('today', 'Today'),
#             ('7days', 'Past 7 days'),
#             ('month', 'This month'),
#             ('year', 'This year'),
#         ]

#     def queryset(self, request, queryset):
#         now = timezone.now()
#         val = self.value()

#         if val == 'today':
#             start = timezone.datetime(now.year, now.month, now.day, tzinfo=timezone.get_current_timezone())
#             end = start + timedelta(days=1)
#             return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

#         if val == '7days':
#             return queryset.filter(order__order_date__gte=now - timedelta(days=7))

#         if val == 'month':
#             start = timezone.datetime(now.year, now.month, 1, tzinfo=timezone.get_current_timezone())
#             if now.month == 12:
#                 end = timezone.datetime(now.year + 1, 1, 1, tzinfo=timezone.get_current_timezone())
#             else:
#                 end = timezone.datetime(now.year, now.month + 1, 1, tzinfo=timezone.get_current_timezone())
#             return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

#         if val == 'year':
#             start = timezone.datetime(now.year, 1, 1, tzinfo=timezone.get_current_timezone())
#             end = timezone.datetime(now.year + 1, 1, 1, tzinfo=timezone.get_current_timezone())
#             return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

#         return queryset


# # =========================
# # إدارة Orders
# class OrderAdmin(admin.ModelAdmin):
#     list_display = ('user_with_order', 'order_date', 'is_finished')

#     def user_with_order(self, obj):
#         return f"{obj.user.username} (Order #{obj.id})"
#     user_with_order.short_description = "User & Order ID"
    
#     list_filter = ('is_finished', ('order_date', admin.DateFieldListFilter), 'user')
#     search_fields = ('user__username', 'user__email')
#     inlines = [OrderDetailsInline]


# # =========================
# # إدارة OrderDetails كقسم مستقل
# class OrderDetailsAdmin(admin.ModelAdmin):
#     list_display = (
#         'user_with_order', 'gamer_id', 'Package',
#         'price', 'final_price_display', 'quantity', 'status', 'is_finished', 'reject_action'
#     )

#     search_fields = ('order__user__username', 'order__user__email')
#     list_filter = ('status', 'order__is_finished', OrderDateFilter)
#     list_editable = ('status',)

#     # =========================
#     # حساب نسبة الزيادة (Profit)
#     def get_profit_percent(self, user_profile):
#         PROFIT_CHOICES = {
#             'vip1': Decimal('0.01'),
#             'vip2': Decimal('0.02'),
#             'vip3': Decimal('0.03'),
#             'vip4': Decimal('0.04'),
#             'vip5': Decimal('0.05'),
#         }
#         return PROFIT_CHOICES.get(user_profile.level, Decimal('0.00'))

#     # =========================
#     # السعر النهائي بعد الزيادة
#     def final_price(self, order_detail):
#         user_profile = order_detail.order.user.userprofile
#         profit_rate = self.get_profit_percent(user_profile)
#         return order_detail.price * (Decimal(1) + profit_rate)

#     def final_price_display(self, obj):
#         return f"${self.final_price(obj):.4f}"
#     final_price_display.short_description = "purchased price"

#     # =========================
#     # بيانات المستخدم والطلب
#     def user_with_order(self, obj):
#         return f"{obj.order.user.username} (Order #{obj.order.id})"
#     user_with_order.short_description = "User & Order ID"

#     def user_username(self, obj):
#         return obj.order.user.username if obj.order.user else 'غير متوفر'
#     user_username.short_description = 'Username'

#     def user_email(self, obj):
#         return obj.order.user.email if obj.order.user else 'غير متوفر'
#     user_email.short_description = 'Email'

#     def order_number(self, obj):
#         return obj.order.id
#     order_number.short_description = 'Order ID'

#     def is_finished(self, obj):
#         return format_html(
#             '<span style="color: green;">✔</span>' if obj.order.is_finished
#             else '<span style="color: red;">✘</span>'
#         )
#     is_finished.short_description = 'تم الدفع'

#     # =========================
#     # زر رفض واسترداد المبلغ
#     def reject_action(self, obj):
#         if obj.order.is_finished and obj.status not in ['rejected', 'done']:
#             return format_html(
#                 '<a class="button" href="{}" '
#                 'style="background-color: #dc3545;color: white;padding: 5px 10px;'
#                 'border-radius: 4px;">رفض واسترداد</a>',
#                 reverse('admin:reject_order', args=[obj.id])
#             )
#         return "-"
#     reject_action.short_description = 'إجراءات'
#     reject_action.allow_tags = True

#     # =========================
#     # إضافة URL مخصص لرفض الطلب
#     def get_urls(self):
#         urls = super().get_urls()
#         custom_urls = [
#             path('<path:object_id>/reject/', self.admin_site.admin_view(self.reject_order_view),
#                  name='reject_order')
#         ]
#         return custom_urls + urls

#     # =========================
#     # دالة رفض الطلب الفردي واسترداد المبلغ
#     def reject_order_view(self, request, object_id, *args, **kwargs):
#         order_detail = self.get_object(request, object_id)
#         if not order_detail:
#             messages.error(request, 'العنصر غير موجود')
#             return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

#         if order_detail.status == 'rejected':
#             messages.warning(request, 'تم رفض هذا الطلب مسبقًا واسترداد المبلغ')
#         elif order_detail.status == 'done':
#             messages.warning(request, 'تم تنفيذ هذا الطلب ولا يمكن رفضه')
#         elif order_detail.order.is_finished:
#             user_profile = order_detail.order.user.userprofile
#             user_profile.balance += self.final_price(order_detail)
#             user_profile.save()

#             order_detail.status = 'rejected'
#             order_detail.has_been_refunded = True
#             order_detail.save()
#             messages.success(request, f'تم رفض الطلب #{order_detail.order.id} واسترداد المبلغ للمستخدم')
#         else:
#             messages.error(request, 'لا يمكن رفض هذا الطلب (غير مدفوع)')

#         return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

#     # =========================
#     # الإجراء الجماعي لرفض الطلبات واسترداد المبالغ
#     def reject_order_action(self, request, queryset):
#         count = 0
#         for order_detail in queryset:
#             if (order_detail.order.is_finished and
#                 order_detail.status not in ['rejected', 'done'] and
#                 not order_detail.has_been_refunded):
#                 user_profile = order_detail.order.user.userprofile
#                 user_profile.balance += self.final_price(order_detail)
#                 user_profile.save()
#                 order_detail.status = 'rejected'
#                 order_detail.has_been_refunded = True
#                 order_detail.save()
#                 count += 1

#         if count:
#             self.message_user(request, f'تم رفض {count} طلب واسترداد المبالغ', messages.SUCCESS)
#         else:
#             self.message_user(request,
#                               'لم يتم رفض أي طلب (قد تكون مرفوضة أو منفذة مسبقًا)',
#                               messages.WARNING)


# # =========================
# # إدارة المرسل MailSender
# class MailSenderAdmin(admin.ModelAdmin):
#     list_display = ('email', 'code', 'created_at', 'sent')
#     search_fields = ('email',)
#     actions = ['send_email']

#     def send_email(self, request, queryset):
#         for mail_sender in queryset:
#             subject = 'Your Subject Here'
#             full_message = f'{mail_sender.message}\n\nCode: {mail_sender.code}'
#             try:
#                 send_mail(
#                     subject,
#                     full_message,
#                     settings.EMAIL_HOST_USER,
#                     [mail_sender.email],
#                     fail_silently=False,
#                 )
#                 mail_sender.sent = True
#                 mail_sender.save()
#                 messages.success(request, f'Email sent to {mail_sender.email}.')
#             except Exception as e:
#                 mail_sender.sent = False
#                 mail_sender.save()
#                 messages.error(request, f'Failed to send email to {mail_sender.email}. Error: {str(e)}')

#     send_email.short_description = "Send email to selected MailSenders"


# # =========================
# # تسجيل الموديلات في لوحة التحكم
# admin.site.register(Order, OrderAdmin)
# admin.site.register(OrderDetails, OrderDetailsAdmin)
# admin.site.register(MailSender, MailSenderAdmin)




# from django.contrib import admin, messages
# from django.http import HttpResponseRedirect
# from django.urls import path, reverse
# from django.utils.html import format_html
# from decimal import Decimal
# from django.core.mail import send_mail
# from django.conf import settings
# from django.utils import timezone
# from datetime import timedelta

# from .models import Order, OrderDetails, MailSender
# from .views import retry_api  # استيراد دالة إعادة الإرسال من views


# # =========================
# # Inline لتفاصيل الطلب داخل Order
# class OrderDetailsInline(admin.TabularInline):
#     model = OrderDetails
#     extra = 0
#     readonly_fields = ('Package', 'gamer_id', 'price', 'quantity', 'status')


# # =========================
# # فلتر التاريخ الزمني المصحح
# class OrderDateFilter(admin.SimpleListFilter):
#     title = 'By order date'
#     parameter_name = 'order_date'

#     def lookups(self, request, model_admin):
#         return [
#             ('any', 'Any date'),
#             ('today', 'Today'),
#             ('7days', 'Past 7 days'),
#             ('month', 'This month'),
#             ('year', 'This year'),
#         ]

#     def queryset(self, request, queryset):
#         now = timezone.now()
#         val = self.value()

#         if val == 'today':
#             start = timezone.datetime(now.year, now.month, now.day, tzinfo=timezone.get_current_timezone())
#             end = start + timedelta(days=1)
#             return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

#         if val == '7days':
#             return queryset.filter(order__order_date__gte=now - timedelta(days=7))

#         if val == 'month':
#             start = timezone.datetime(now.year, now.month, 1, tzinfo=timezone.get_current_timezone())
#             if now.month == 12:
#                 end = timezone.datetime(now.year + 1, 1, 1, tzinfo=timezone.get_current_timezone())
#             else:
#                 end = timezone.datetime(now.year, now.month + 1, 1, tzinfo=timezone.get_current_timezone())
#             return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

#         if val == 'year':
#             start = timezone.datetime(now.year, 1, 1, tzinfo=timezone.get_current_timezone())
#             end = timezone.datetime(now.year + 1, 1, 1, tzinfo=timezone.get_current_timezone())
#             return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

#         return queryset


# # =========================
# # إدارة Orders
# class OrderAdmin(admin.ModelAdmin):
#     list_display = ('user_with_order', 'order_date', 'is_finished')

#     def user_with_order(self, obj):
#         return f"{obj.user.username} (Order #{obj.id})"
#     user_with_order.short_description = "User & Order ID"
    
#     list_filter = ('is_finished', ('order_date', admin.DateFieldListFilter), 'user')
#     search_fields = ('user__username', 'user__email')
#     inlines = [OrderDetailsInline]


# # =========================
# # إدارة OrderDetails كقسم مستقل
# class OrderDetailsAdmin(admin.ModelAdmin):
#     list_display = (
#         'user_with_order', 'gamer_id', 'Package',
#         'price', 'final_price_display', 'quantity', 'status', 'is_finished', 'reject_action', 'retry_action'
#     )

#     search_fields = ('order__user__username', 'order__user__email')
#     list_filter = ('status', 'order__is_finished', OrderDateFilter)
#     list_editable = ('status',)

#     # =========================
#     # حساب نسبة الزيادة (Profit)
#     def get_profit_percent(self, user_profile):
#         PROFIT_CHOICES = {
#             'vip1': Decimal('0.01'),
#             'vip2': Decimal('0.02'),
#             'vip3': Decimal('0.03'),
#             'vip4': Decimal('0.04'),
#             'vip5': Decimal('0.05'),
#         }
#         return PROFIT_CHOICES.get(user_profile.level, Decimal('0.00'))

#     # =========================
#     # السعر النهائي بعد الزيادة
#     def final_price(self, order_detail):
#         user_profile = order_detail.order.user.userprofile
#         profit_rate = self.get_profit_percent(user_profile)
#         return order_detail.price * (Decimal(1) + profit_rate)

#     def final_price_display(self, obj):
#         return f"${self.final_price(obj):.4f}"
#     final_price_display.short_description = "purchased price"

#     # =========================
#     # بيانات المستخدم والطلب
#     def user_with_order(self, obj):
#         return f"{obj.order.user.username} (Order #{obj.order.id})"
#     user_with_order.short_description = "User & Order ID"

#     def user_username(self, obj):
#         return obj.order.user.username if obj.order.user else 'غير متوفر'
#     user_username.short_description = 'Username'

#     def user_email(self, obj):
#         return obj.order.user.email if obj.order.user else 'غير متوفر'
#     user_email.short_description = 'Email'

#     def order_number(self, obj):
#         return obj.order.id
#     order_number.short_description = 'Order ID'

#     def is_finished(self, obj):
#         return format_html(
#             '<span style="color: green;">✔</span>' if obj.order.is_finished
#             else '<span style="color: red;">✘</span>'
#         )
#     is_finished.short_description = 'تم الدفع'

#     # =========================
#     # زر رفض واسترداد المبلغ
#     def reject_action(self, obj):
#         if obj.order.is_finished and obj.status not in ['rejected', 'done']:
#             return format_html(
#                 '<a class="button" href="{}" '
#                 'style="background-color: #dc3545;color: white;padding: 5px 10px;'
#                 'border-radius: 4px;">رفض واسترداد</a>',
#                 reverse('admin:reject_order', args=[obj.id])
#             )
#         return "-"
#     reject_action.short_description = 'إجراءات'
#     reject_action.allow_tags = True

#     # =========================
#     # زر إعادة التوجيه (Retry) إلى نفس الـ API
#     def retry_action(self, obj):
#         # فقط إظهار الزر إذا كان الطلب مدفوعاً والحالة لا تزال pending
#         if obj.order.is_finished and obj.status == 'pending':
#             return format_html(
#                 '<a class="button" href="{}" '
#                 'style="background-color: #1e88e5;color: white;padding: 5px 10px;'
#                 'border-radius: 4px;">إعادة التوجيه</a>',
#                 reverse('admin:send_order', args=[obj.id])
#             )
#         return "-"
#     retry_action.short_description = 'إعادة توجيه للـ API'
#     retry_action.allow_tags = True

#     # =========================
#     # إضافة URL مخصص لرفض الطلب وإعادة التوجيه
#     def get_urls(self):
#         urls = super().get_urls()
#         custom_urls = [
#             path('<path:object_id>/reject/', self.admin_site.admin_view(self.reject_order_view),
#                  name='reject_order'),
#             path('<path:object_id>/send/', self.admin_site.admin_view(self.send_order_view),
#                  name='send_order'),
#         ]
#         return custom_urls + urls

#     # =========================
#     # دالة رفض الطلب الفردي واسترداد المبلغ
#     def reject_order_view(self, request, object_id, *args, **kwargs):
#         order_detail = self.get_object(request, object_id)
#         if not order_detail:
#             messages.error(request, 'العنصر غير موجود')
#             return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

#         if order_detail.status == 'rejected':
#             messages.warning(request, 'تم رفض هذا الطلب مسبقًا واسترداد المبلغ')
#         elif order_detail.status == 'done':
#             messages.warning(request, 'تم تنفيذ هذا الطلب ولا يمكن رفضه')
#         elif order_detail.order.is_finished:
#             user_profile = order_detail.order.user.userprofile
#             user_profile.balance += self.final_price(order_detail)
#             user_profile.save()

#             order_detail.status = 'rejected'
#             order_detail.has_been_refunded = True
#             order_detail.save()
#             messages.success(request, f'تم رفض الطلب #{order_detail.order.id} واسترداد المبلغ للمستخدم')
#         else:
#             messages.error(request, 'لا يمكن رفض هذا الطلب (غير مدفوع)')

#         return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

#     # =========================
#     # دالة إعادة التوجيه (Retry) من لوحة الإدارة
#     def send_order_view(self, request, object_id, *args, **kwargs):
#         order_detail = self.get_object(request, object_id)
#         if not order_detail:
#             messages.error(request, 'العنصر غير موجود')
#             return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

#         # شرط السماح: الطلب مدفوع والحالة pending
#         if not order_detail.order.is_finished:
#             messages.error(request, 'لا يمكن إعادة التوجيه: الطلب غير مدفوع.')
#             return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

#         if order_detail.status in ['done', 'rejected']:
#             messages.warning(request, 'لا يمكن إعادة التوجيه: الطلب منفذ أو مرفوض مسبقًا.')
#             return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

#         # استدعاء دالة retry من views.py
#         success, msg = retry_api(order_detail)

#         if success:
#             messages.success(request, msg)
#         else:
#             messages.error(request, msg)

#         return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

#     # =========================
#     # الإجراء الجماعي لرفض الطلبات واسترداد المبالغ
#     def reject_order_action(self, request, queryset):
#         count = 0
#         for order_detail in queryset:
#             if (order_detail.order.is_finished and
#                 order_detail.status not in ['rejected', 'done'] and
#                 not order_detail.has_been_refunded):
#                 user_profile = order_detail.order.user.userprofile
#                 user_profile.balance += self.final_price(order_detail)
#                 user_profile.save()
#                 order_detail.status = 'rejected'
#                 order_detail.has_been_refunded = True
#                 order_detail.save()
#                 count += 1

#         if count:
#             self.message_user(request, f'تم رفض {count} طلب واسترداد المبالغ', messages.SUCCESS)
#         else:
#             self.message_user(request,
#                               'لم يتم رفض أي طلب (قد تكون مرفوضة أو منفذة مسبقًا)',
#                               messages.WARNING)


# # =========================
# # إدارة المرسل MailSender
# class MailSenderAdmin(admin.ModelAdmin):
#     list_display = ('email', 'code', 'created_at', 'sent')
#     search_fields = ('email',)
#     actions = ['send_email']

#     def send_email(self, request, queryset):
#         for mail_sender in queryset:
#             subject = 'Your Subject Here'
#             full_message = f'{mail_sender.message}\n\nCode: {mail_sender.code}'
#             try:
#                 send_mail(
#                     subject,
#                     full_message,
#                     settings.EMAIL_HOST_USER,
#                     [mail_sender.email],
#                     fail_silently=False,
#                 )
#                 mail_sender.sent = True
#                 mail_sender.save()
#                 messages.success(request, f'Email sent to {mail_sender.email}.')
#             except Exception as e:
#                 mail_sender.sent = False
#                 mail_sender.save()
#                 messages.error(request, f'Failed to send email to {mail_sender.email}. Error: {str(e)}')

#     send_email.short_description = "Send email to selected MailSenders"


# # =========================
# # تسجيل الموديلات في لوحة التحكم
# admin.site.register(Order, OrderAdmin)
# admin.site.register(OrderDetails, OrderDetailsAdmin)
# admin.site.register(MailSender, MailSenderAdmin)






from django.contrib import admin, messages
from django.http import HttpResponseRedirect
from django.urls import path, reverse
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from decimal import Decimal, ROUND_DOWN
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone
from datetime import timedelta

from .models import Order, OrderDetails, MailSender
from .views import retry_api  # استيراد دالة إعادة الإرسال من views


# =========================
# Inline لتفاصيل الطلب داخل Order
class OrderDetailsInline(admin.TabularInline):
    model = OrderDetails
    extra = 0
    readonly_fields = ('Package', 'gamer_id', 'price', 'quantity', 'status')


# =========================
# فلتر التاريخ الزمني المصحح
class OrderDateFilter(admin.SimpleListFilter):
    title = 'حسب تاريخ الطلب'
    parameter_name = 'order_date'

    def lookups(self, request, model_admin):
        return [
            ('any', 'أي تاريخ'),
            ('today', 'اليوم'),
            ('7days', 'آخر 7 أيام'),
            ('month', 'هذا الشهر'),
            ('year', 'هذه السنة'),
        ]

    def queryset(self, request, queryset):
        now = timezone.now()
        val = self.value()

        if val == 'today':
            start = timezone.datetime(now.year, now.month, now.day, tzinfo=timezone.get_current_timezone())
            end = start + timedelta(days=1)
            return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

        if val == '7days':
            return queryset.filter(order__order_date__gte=now - timedelta(days=7))

        if val == 'month':
            start = timezone.datetime(now.year, now.month, 1, tzinfo=timezone.get_current_timezone())
            if now.month == 12:
                end = timezone.datetime(now.year + 1, 1, 1, tzinfo=timezone.get_current_timezone())
            else:
                end = timezone.datetime(now.year, now.month + 1, 1, tzinfo=timezone.get_current_timezone())
            return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

        if val == 'year':
            start = timezone.datetime(now.year, 1, 1, tzinfo=timezone.get_current_timezone())
            end = timezone.datetime(now.year + 1, 1, 1, tzinfo=timezone.get_current_timezone())
            return queryset.filter(order__order_date__gte=start, order__order_date__lt=end)

        return queryset


# =========================
# إدارة Orders
class OrderAdmin(admin.ModelAdmin):
    list_display = ('user_with_order', 'order_date', 'is_finished')

    def user_with_order(self, obj):
        return f"{obj.user.username} (طلب #{obj.id})"
    user_with_order.short_description = "المستخدم ورقم الطلب"
    
    list_filter = ('is_finished', ('order_date', admin.DateFieldListFilter), 'user')
    search_fields = ('user__username', 'user__email')
    inlines = [OrderDetailsInline]


# =========================
# إدارة OrderDetails كقسم مستقل
class OrderDetailsAdmin(admin.ModelAdmin):
    list_display = (
        'user_with_order', 'gamer_id', 'Package',
        'price_display', 'final_price_display', 'quantity', 'status', 'is_finished', 'reject_action', 'retry_action'
    )

    search_fields = ('order__user__username', 'order__user__email')
    list_filter = ('status', 'order__is_finished', OrderDateFilter)
    list_editable = ('status',)

    # =========================
    # حساب نسبة الزيادة (Profit)
    def get_profit_percent(self, user_profile):
        PROFIT_CHOICES = {
            'vip1': Decimal('0.01'),
            'vip2': Decimal('0.02'),
            'vip3': Decimal('0.03'),
            'vip4': Decimal('0.04'),
            'vip5': Decimal('0.05'),
        }
        return PROFIT_CHOICES.get(user_profile.level, Decimal('0.00'))

    # =========================
    # السعر الأصلي (رأس المال)
    def base_price(self, order_detail):
        """
        يرجع السعر الأصلي (رأس المال) قبل إضافة نسبة الربح
        """
        # إذا كان final_price موجوداً و > 0: طلب قديم (price = السعر الأصلي)
        if order_detail.final_price and order_detail.final_price > 0:
            return order_detail.price  # السعر الأصلي للطلبات القديمة
        else:
            # طلب جديد: price يحتوي على السعر بعد الزيادة، نحسب السعر الأصلي
            user_profile = order_detail.order.user.userprofile
            profit_rate = self.get_profit_percent(user_profile)
            if profit_rate > 0:
                # حساب السعر الأصلي: base_price = final_price / (1 + profit_rate)
                base = order_detail.price / (Decimal('1') + profit_rate)
                return base.quantize(Decimal('0.0001'), rounding=ROUND_DOWN)
            else:
                return order_detail.price

    # =========================
    # السعر المدفوع (بعد الزيادة)
    def final_price(self, order_detail):
        """
        يرجع السعر الذي دفعه المستخدم فعلياً (بعد إضافة نسبة الربح)
        """
        # إذا كان final_price موجوداً و > 0: طلب قديم
        if order_detail.final_price and order_detail.final_price > 0:
            return order_detail.final_price  # السعر المدفوع للطلبات القديمة
        else:
            # طلب جديد: price يحتوي على السعر بعد الزيادة
            return order_detail.price

    def price_display(self, obj):
        """
        عرض السعر الأساسي (رأس المال):
        - إذا كان للباقة سعر مباشر → استخدمه
        - وإلا احسب السعر من (سعر الوحدة × الكمية)
        """
        # 1️⃣ سعر مباشر داخل الباقة
        if obj.Package and obj.Package.price is not None:
            return f"${obj.Package.price:.4f}"

        # 2️⃣ سعر محسوب حسب الكمية من المنتج
        if (
            obj.Package
            and hasattr(obj.Package, 'product')
            and obj.Package.product
            and obj.Package.product.coins_price is not None
            and obj.quantity
        ):
            base_price = obj.Package.product.coins_price * obj.quantity
            return f"${base_price:.4f}"

        return "-"
    price_display.short_description = "السعر الأساسي"

    def final_price_display(self, obj):
        """عرض السعر المدفوع (بعد الزيادة)"""
        return f"${self.final_price(obj):.4f}"
    final_price_display.short_description = "السعر النهائي"

    # =========================
    # بيانات المستخدم والطلب
    def user_with_order(self, obj):
        return f"{obj.order.user.username} (طلب #{obj.order.id})"
    user_with_order.short_description = "المستخدم ورقم الطلب"

    def user_username(self, obj):
        return obj.order.user.username if obj.order.user else 'غير متوفر'
    user_username.short_description = 'اسم المستخدم'

    def user_email(self, obj):
        return obj.order.user.email if obj.order.user else 'غير متوفر'
    user_email.short_description = 'البريد الإلكتروني'

    def order_number(self, obj):
        return obj.order.id
    order_number.short_description = 'رقم الطلب'

    def is_finished(self, obj):
        if obj.order.is_finished:
            return mark_safe('<span style="color: green;">✔</span>')
        else:
            return mark_safe('<span style="color: red;">✘</span>')
    is_finished.short_description = 'تم الدفع'

    # =========================
    # زر رفض واسترداد المبلغ
    def reject_action(self, obj):
        if obj.order.is_finished and obj.status not in ['rejected', 'done']:
            return format_html(
                '<a class="button" href="{}" '
                'style="background-color: #dc3545;color: white;padding: 5px 10px;'
                'border-radius: 4px;">رفض واسترداد</a>',
                reverse('admin:reject_order', args=[obj.id])
            )
        return "-"
    reject_action.short_description = 'إجراءات'
    reject_action.allow_tags = True

    # =========================
    # زر إعادة التوجيه (Retry) إلى نفس الـ API
    def retry_action(self, obj):
        # فقط إظهار الزر إذا كان الطلب مدفوعاً والحالة لا تزال pending
        if obj.order.is_finished and obj.status == 'pending':
            return format_html(
                '<a class="button" href="{}" '
                'style="background-color: #1e88e5;color: white;padding: 5px 10px;'
                'border-radius: 4px;">إعادة التوجيه</a>',
                reverse('admin:send_order', args=[obj.id])
            )
        return "-"
    retry_action.short_description = 'إعادة توجيه للـ API'
    retry_action.allow_tags = True

    # =========================
    # إضافة URL مخصص لرفض الطلب وإعادة التوجيه
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('<path:object_id>/reject/', self.admin_site.admin_view(self.reject_order_view),
                 name='reject_order'),
            path('<path:object_id>/send/', self.admin_site.admin_view(self.send_order_view),
                 name='send_order'),
        ]
        return custom_urls + urls

    # =========================
    # دالة رفض الطلب الفردي واسترداد المبلغ
    def reject_order_view(self, request, object_id, *args, **kwargs):
        order_detail = self.get_object(request, object_id)
        if not order_detail:
            messages.error(request, 'العنصر غير موجود')
            return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

        # إذا تم رفضه مسبقًا
        if order_detail.status == 'rejected' or getattr(order_detail, 'has_been_refunded', False):
            messages.warning(request, 'تم رفض هذا الطلب مسبقًا واسترداد المبلغ')
            return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

        # إذا تم تنفيذه
        if order_detail.status == 'done':
            messages.warning(request, 'تم تنفيذ هذا الطلب ولا يمكن رفضه')
            return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

        # إذا كان مدفوعًا (is_finished=True)
        if order_detail.order.is_finished:
            # استخدام final_price (الدالة) التي ترجع السعر الصحيح
            refund_amount = self.final_price(order_detail)

            user_profile = order_detail.order.user.userprofile
            user_profile.balance += refund_amount
            user_profile.save()

            order_detail.status = 'rejected'
            order_detail.has_been_refunded = True
            order_detail.save()

            messages.success(request, f'تم رفض الطلب #{order_detail.order.id} واسترداد {refund_amount} للمستخدم')
            return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

        # إذا لم يكن مدفوعًا
        messages.error(request, 'لا يمكن رفض هذا الطلب (غير مدفوع)')
        return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))


    # =========================
    # دالة إعادة التوجيه (Retry) من لوحة الإدارة
    def send_order_view(self, request, object_id, *args, **kwargs):
        order_detail = self.get_object(request, object_id)
        if not order_detail:
            messages.error(request, 'العنصر غير موجود')
            return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

        # شرط السماح: الطلب مدفوع والحالة pending
        if not order_detail.order.is_finished:
            messages.error(request, 'لا يمكن إعادة التوجيه: الطلب غير مدفوع.')
            return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

        if order_detail.status in ['done', 'rejected']:
            messages.warning(request, 'لا يمكن إعادة التوجيه: الطلب منفذ أو مرفوض مسبقًا.')
            return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

        # استدعاء دالة retry من views.py
        success, msg = retry_api(order_detail)

        if success:
            messages.success(request, msg)
        else:
            messages.error(request, msg)

        return HttpResponseRedirect(reverse('admin:orders_orderdetails_changelist'))

    # =========================
    # الإجراء الجماعي لرفض الطلبات واسترداد المبالغ
    def reject_order_action(self, request, queryset):
        count = 0
        for order_detail in queryset:
            if (order_detail.order.is_finished and
                order_detail.status not in ['rejected', 'done'] and
                not getattr(order_detail, 'has_been_refunded', False)):
                # استخدام final_price من النموذج أو price (كلاهما يحتوي على السعر بعد الزيادة)
                refund_amount = self.final_price(order_detail)
                user_profile = order_detail.order.user.userprofile
                user_profile.balance += refund_amount
                user_profile.save()
                order_detail.status = 'rejected'
                order_detail.has_been_refunded = True
                order_detail.save()
                count += 1

        if count:
            self.message_user(request, f'تم رفض {count} طلب واسترداد المبالغ', messages.SUCCESS)
        else:
            self.message_user(request,
                              'لم يتم رفض أي طلب (قد تكون مرفوضة أو منفذة مسبقًا)',
                              messages.WARNING)


# =========================
# إدارة المرسل MailSender
class MailSenderAdmin(admin.ModelAdmin):
    list_display = ('email', 'code', 'created_at', 'sent')
    search_fields = ('email',)
    list_filter = ('sent', 'created_at')
    actions = ['send_email']

    def send_email(self, request, queryset):
        for mail_sender in queryset:
            subject = 'Your Subject Here'
            full_message = f'{mail_sender.message}\n\nCode: {mail_sender.code}'
            try:
                send_mail(
                    subject,
                    full_message,
                    settings.EMAIL_HOST_USER,
                    [mail_sender.email],
                    fail_silently=False,
                )
                mail_sender.sent = True
                mail_sender.save()
                messages.success(request, f'تم إرسال البريد الإلكتروني إلى {mail_sender.email}.')
            except Exception as e:
                mail_sender.sent = False
                mail_sender.save()
                messages.error(request, f'فشل إرسال البريد الإلكتروني إلى {mail_sender.email}. الخطأ: {str(e)}')

    send_email.short_description = "إرسال بريد إلكتروني للمحددين"


# =========================
# تسجيل الموديلات في لوحة التحكم
admin.site.register(Order, OrderAdmin)
admin.site.register(OrderDetails, OrderDetailsAdmin)
admin.site.register(MailSender, MailSenderAdmin)


