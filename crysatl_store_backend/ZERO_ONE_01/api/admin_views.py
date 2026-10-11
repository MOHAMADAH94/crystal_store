"""
API Views خاصة بتطبيق الإدارة
تتطلب صلاحيات staff أو superuser
"""
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.authentication import TokenAuthentication
from django.contrib.auth.models import User
from django.db.models import Sum, Count, Q
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal

from products.models import Category, Product, Package, Agent, ExchangeRate
from orders.models import Order, OrderDetails
from accounts.models import UserProfile, PaymentMethod, BalanceLog, Notification, UserNotification, Balance_add
from .models import APIKey, ExternalStore
from .serializers import (
    UserSerializer, UserProfileSerializer, CategorySerializer, ProductSerializer,
    PackageSerializer, OrderSerializer, CreateOrderSerializer, PaymentMethodSerializer,
    BalanceLogSerializer, NotificationSerializer, APIKeySerializer, ExternalStoreSerializer,
    AgentSerializer, BalanceAddSerializer
)


class IsStaffOrReadOnly(permissions.BasePermission):
    """صلاحية للسماح للموظفين فقط"""
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return request.user.is_authenticated
        return request.user.is_authenticated and request.user.is_staff


class AdminCategoryViewSet(viewsets.ModelViewSet):
    """إدارة الفئات - للمديرين فقط"""
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        queryset = Category.objects.all()
        parent_only = self.request.query_params.get('parent_only', 'false').lower() == 'true'
        if parent_only:
            queryset = queryset.filter(parent_category__isnull=True)
        return queryset.order_by('ordering')


class AdminProductViewSet(viewsets.ModelViewSet):
    """إدارة المنتجات - للمديرين فقط"""
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        queryset = Product.objects.all()
        category_id = self.request.query_params.get('category', None)
        if category_id:
            queryset = queryset.filter(category_id=category_id)
        return queryset.order_by('-created_at')


class AdminPackageViewSet(viewsets.ModelViewSet):
    """إدارة الباقات - للمديرين فقط"""
    queryset = Package.objects.all()
    serializer_class = PackageSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        queryset = Package.objects.all()
        product_id = self.request.query_params.get('product', None)
        if product_id:
            queryset = queryset.filter(product_id=product_id)
        return queryset.order_by('-id')


class AdminOrderViewSet(viewsets.ModelViewSet):
    """إدارة الطلبات - للمديرين فقط"""
    queryset = Order.objects.all()
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        queryset = Order.objects.all()
        user_id = self.request.query_params.get('user', None)
        status_filter = self.request.query_params.get('status', None)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        if status_filter:
            queryset = queryset.filter(detail__status=status_filter).distinct()
        return queryset.order_by('-id')
    
    @action(detail=True, methods=['get'])
    def details(self, request, pk=None):
        """الحصول على تفاصيل الطلب"""
        order = self.get_object()
        details = OrderDetails.objects.filter(order=order)
        serializer = OrderSerializer(order)
        return Response(serializer.data)


class AdminOrderDetailsViewSet(viewsets.ModelViewSet):
    """إدارة تفاصيل الطلبات - للمديرين فقط"""
    queryset = OrderDetails.objects.all()
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        queryset = OrderDetails.objects.all()
        order_id = self.request.query_params.get('order', None)
        status_filter = self.request.query_params.get('status', None)
        if order_id:
            queryset = queryset.filter(order_id=order_id)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return queryset.order_by('-id')
    
    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        """تحديث حالة الطلب"""
        order_detail = self.get_object()
        new_status = request.data.get('status')
        if new_status not in ['pending', 'rejected', 'done']:
            return Response(
                {'error': 'حالة غير صحيحة'},
                status=status.HTTP_400_BAD_REQUEST
            )
        order_detail.status = new_status
        order_detail.save()
        return Response({'status': 'تم التحديث بنجاح'})


class AdminUserViewSet(viewsets.ModelViewSet):
    """إدارة المستخدمين - للمديرين فقط"""
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        queryset = User.objects.all()
        search = self.request.query_params.get('search', None)
        if search:
            queryset = queryset.filter(
                Q(username__icontains=search) |
                Q(email__icontains=search)
            )
        return queryset.order_by('-date_joined')
    
    @action(detail=True, methods=['get'])
    def profile(self, request, pk=None):
        """الحصول على ملف المستخدم"""
        user = self.get_object()
        try:
            profile = user.userprofile
            serializer = UserProfileSerializer(profile)
            return Response(serializer.data)
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'ملف المستخدم غير موجود'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=True, methods=['patch'])
    def update_balance(self, request, pk=None):
        """تحديث رصيد المستخدم"""
        user = self.get_object()
        try:
            profile = user.userprofile
            new_balance = Decimal(str(request.data.get('balance', 0)))
            old_balance = profile.balance
            profile.balance = new_balance
            profile.save()
            
            # تسجيل التغيير
            BalanceLog.objects.create(
                user_profile=profile,
                old_balance=old_balance,
                new_balance=new_balance,
                description='تحديث الرصيد — لوحة التحكم'
            )
            return Response({'status': 'تم التحديث بنجاح'})
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'ملف المستخدم غير موجود'},
                status=status.HTTP_404_NOT_FOUND
            )


class AdminUserProfileViewSet(viewsets.ModelViewSet):
    """إدارة ملفات المستخدمين - للمديرين فقط"""
    queryset = UserProfile.objects.all()
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        queryset = UserProfile.objects.all()
        search = self.request.query_params.get('search', None)
        level = self.request.query_params.get('level', None)
        if search:
            queryset = queryset.filter(
                Q(user__username__icontains=search) |
                Q(user__email__icontains=search) |
                Q(phone__icontains=search)
            )
        if level:
            queryset = queryset.filter(level=level)
        return queryset.order_by('-user__date_joined')


class AdminNotificationViewSet(viewsets.ModelViewSet):
    """إدارة الإشعارات - للمديرين فقط"""
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        return Notification.objects.all().order_by('-created_at')
    
    @action(detail=True, methods=['post'])
    def send(self, request, pk=None):
        """إرسال الإشعار لجميع المستخدمين"""
        notification = self.get_object()
        users = User.objects.all()
        for user in users:
            UserNotification.objects.get_or_create(
                user=user,
                notification=notification
            )
        notification.is_sent = True
        notification.save()
        return Response({'status': 'تم الإرسال بنجاح'})


class AdminPaymentMethodViewSet(viewsets.ModelViewSet):
    """إدارة طرق الدفع - للمديرين فقط"""
    queryset = PaymentMethod.objects.all()
    serializer_class = PaymentMethodSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]


class AdminBalanceAddViewSet(viewsets.ModelViewSet):
    """إدارة طلبات إضافة الرصيد - للمديرين فقط"""
    queryset = Balance_add.objects.all()
    serializer_class = BalanceAddSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def get_queryset(self):
        queryset = Balance_add.objects.all()
        is_processed = self.request.query_params.get('is_processed', None)
        if is_processed is not None:
            queryset = queryset.filter(is_processed=is_processed.lower() == 'true')
        return queryset.order_by('-created_at')
    
    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """الموافقة على طلب إضافة الرصيد"""
        balance_add = self.get_object()
        if balance_add.is_processed:
            return Response(
                {'error': 'تم معالجة هذا الطلب مسبقاً'},
                status=status.HTTP_400_BAD_REQUEST
            )
        balance_add.is_processed = True
        balance_add.save()
        return Response({'status': 'تمت الموافقة بنجاح'})


class AdminAgentViewSet(viewsets.ModelViewSet):
    """إدارة الوكلاء - للمديرين فقط"""
    queryset = Agent.objects.all()
    serializer_class = AgentSerializer
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]


class AdminExchangeRateViewSet(viewsets.ModelViewSet):
    """إدارة أسعار الصرف - للمديرين فقط"""
    queryset = ExchangeRate.objects.all()
    serializer_class = None  # سيتم إنشاء serializer لاحقاً
    permission_classes = [permissions.IsAdminUser]
    authentication_classes = [TokenAuthentication]
    
    def list(self, request):
        """الحصول على جميع أسعار الصرف"""
        rates = ExchangeRate.objects.all().order_by('-created_at')
        data = [{
            'id': rate.id,
            'rate': str(rate.rate),
            'is_active': rate.is_active,
            'created_at': rate.created_at,
            'updated_at': rate.updated_at,
            'notes': rate.notes,
        } for rate in rates]
        return Response(data)
    
    def create(self, request):
        """إنشاء سعر صرف جديد"""
        rate = Decimal(str(request.data.get('rate', 0)))
        is_active = request.data.get('is_active', False)
        notes = request.data.get('notes', '')
        
        # إذا كان السعر نشطاً، إلغاء تفعيل الباقي
        if is_active:
            ExchangeRate.objects.filter(is_active=True).update(is_active=False)
        
        exchange_rate = ExchangeRate.objects.create(
            rate=rate,
            is_active=is_active,
            notes=notes
        )
        return Response({
            'id': exchange_rate.id,
            'rate': str(exchange_rate.rate),
            'is_active': exchange_rate.is_active,
            'created_at': exchange_rate.created_at,
            'updated_at': exchange_rate.updated_at,
            'notes': exchange_rate.notes,
        }, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([permissions.IsAdminUser])
def admin_dashboard(request):
    """لوحة تحكم المدير - إحصائيات عامة"""
    today = timezone.now()
    last_7_days = today - timedelta(days=7)
    
    # إحصائيات المستخدمين
    total_users = User.objects.count()
    active_users = User.objects.filter(is_active=True).count()
    new_users_last_7_days = User.objects.filter(date_joined__gte=last_7_days).count()
    
    # إحصائيات الطلبات
    total_orders = Order.objects.count()
    pending_orders = OrderDetails.objects.filter(status='pending').count()
    done_orders = OrderDetails.objects.filter(status='done').count()
    rejected_orders = OrderDetails.objects.filter(status='rejected').count()
    
    # إحصائيات المبيعات
    total_revenue = OrderDetails.objects.filter(
        order__is_finished=True
    ).aggregate(total=Sum('final_price'))['total'] or Decimal('0')
    
    # إحصائيات المنتجات
    total_products = Product.objects.count()
    total_packages = Package.objects.count()
    total_categories = Category.objects.count()
    
    # إجمالي الرصيد
    total_balance = UserProfile.objects.aggregate(
        total_balance=Sum('balance')
    )['total_balance'] or Decimal('0')
    
    # طلبات إضافة الرصيد المعلقة
    pending_balance_adds = Balance_add.objects.filter(is_processed=False).count()
    
    return Response({
        'users': {
            'total': total_users,
            'active': active_users,
            'new_last_7_days': new_users_last_7_days,
        },
        'orders': {
            'total': total_orders,
            'pending': pending_orders,
            'done': done_orders,
            'rejected': rejected_orders,
        },
        'revenue': {
            'total': str(total_revenue),
        },
        'products': {
            'total': total_products,
            'packages': total_packages,
            'categories': total_categories,
        },
        'balance': {
            'total': str(total_balance),
            'pending_adds': pending_balance_adds,
        },
    })
