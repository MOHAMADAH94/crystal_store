from django.urls import path
from . import views



urlpatterns=[
    path('signin',views.signin,name='signin'),
    path('signup',views.signup,name='signup'),
    path('signout',views.signout,name='signout'),
    path('profile',views.profile,name='profile'),
    path('products/packages/favorite_package/<int:pack_id>/', views.favorite_package, name='favorite_package'),
    path('show_favorite_package', views.show_favorite_package, name='show_favorite_package'), 
    path('balance_history/',views.balance_history, name='balance_history'),
    path('send_money/',views.send_money, name='send_money'),
    path('notifications/', views.send_notification, name='notifications'),
    path('mark_as_read/<int:notification_id>/', views.mark_as_read, name='mark_as_read'),
    path('verify_pin/', views.verify_pin, name='verify_pin'),





    # path('admin/balance_add/', views.admin_balance_add, name='admin_balance_add'),


]