from django.urls import path
from . import views

urlpatterns = [
    path('', views.categories_and_products, name='products'),
    path('packages/', views.packages, name='packages'), 
    path('package/<int:id>/', views.package, name='package'),  
    path('product/<int:id>/packages/', views.products_and_packages, name='products_and_packages'),
    

    # path('product/packages//<int:id>', views.favorite_package, name='products_and_packages'),
    # path('show_favorite_package', views.show_favorite_package, name='show_favorite_package'), 

]
