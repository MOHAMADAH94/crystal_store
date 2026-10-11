from django.urls import path
from . import views

urlpatterns = [
    path('add_to_cart/<int:pack_id>/', views.add_to_cart, name='add_to_cart'),
    path('cart/', views.cart, name='cart'),
    path('<int:orderdetails_id>', views.remove_from_cart, name='remove_from_cart'),
    path('payment/', views.payment, name='payment'),
    path('show_orders/', views.show_orders, name='show_orders'),
    path('update_status/<int:order_detail_id>/', views.update_order_status, name='update_order_status'),
    path('update_all_pending/', views.update_all_pending_orders, name='update_all_pending_orders'),
]
