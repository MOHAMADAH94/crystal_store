from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    CategoryViewSet, ProductViewSet, PackageViewSet, OrderViewSet,
    UserProfileViewSet, PaymentMethodViewSet, NotificationViewSet,
    APIKeyViewSet, ExternalStoreViewSet, AgentViewSet, register, login, external_order,
    get_exchange_rate, set_pin, verify_pin, update_pin, check_pin_status
)
from .admin_views import (
    AdminCategoryViewSet, AdminProductViewSet, AdminPackageViewSet,
    AdminOrderViewSet, AdminOrderDetailsViewSet, AdminUserViewSet,
    AdminUserProfileViewSet, AdminNotificationViewSet, AdminPaymentMethodViewSet,
    AdminBalanceAddViewSet, AdminAgentViewSet, AdminExchangeRateViewSet,
    admin_dashboard
)

router = DefaultRouter()
router.register(r'categories', CategoryViewSet, basename='category')
router.register(r'products', ProductViewSet, basename='product')
router.register(r'packages', PackageViewSet, basename='package')
router.register(r'orders', OrderViewSet, basename='order')
router.register(r'profile', UserProfileViewSet, basename='profile')
router.register(r'payment-methods', PaymentMethodViewSet, basename='payment-method')
router.register(r'notifications', NotificationViewSet, basename='notification')
router.register(r'api-keys', APIKeyViewSet, basename='api-key')
router.register(r'external-stores', ExternalStoreViewSet, basename='external-store')
router.register(r'agents', AgentViewSet, basename='agent')

# Router للإدارة
admin_router = DefaultRouter()
admin_router.register(r'admin/categories', AdminCategoryViewSet, basename='admin-category')
admin_router.register(r'admin/products', AdminProductViewSet, basename='admin-product')
admin_router.register(r'admin/packages', AdminPackageViewSet, basename='admin-package')
admin_router.register(r'admin/orders', AdminOrderViewSet, basename='admin-order')
admin_router.register(r'admin/order-details', AdminOrderDetailsViewSet, basename='admin-order-detail')
admin_router.register(r'admin/users', AdminUserViewSet, basename='admin-user')
admin_router.register(r'admin/user-profiles', AdminUserProfileViewSet, basename='admin-user-profile')
admin_router.register(r'admin/notifications', AdminNotificationViewSet, basename='admin-notification')
admin_router.register(r'admin/payment-methods', AdminPaymentMethodViewSet, basename='admin-payment-method')
admin_router.register(r'admin/balance-adds', AdminBalanceAddViewSet, basename='admin-balance-add')
admin_router.register(r'admin/agents', AdminAgentViewSet, basename='admin-agent')
admin_router.register(r'admin/exchange-rates', AdminExchangeRateViewSet, basename='admin-exchange-rate')

urlpatterns = [
    path('', include(router.urls)),
    path('', include(admin_router.urls)),
    path('auth/register/', register, name='register'),
    path('auth/login/', login, name='login'),
    path('external/order/', external_order, name='external-order'),
    path('exchange-rate/', get_exchange_rate, name='exchange-rate'),
    path('admin/dashboard/', admin_dashboard, name='admin-dashboard'),
    path('pin/set/', set_pin, name='set-pin'),
    path('pin/verify/', verify_pin, name='verify-pin'),
    path('pin/update/', update_pin, name='update-pin'),
    path('pin/check/', check_pin_status, name='check-pin-status'),
]

