from django.urls import path
from . import views


urlpatterns=[
    path('',views.index,name="index"),
    path('about',views.about,name="about"),
    path('terms',views.terms,name="terms"),
    path('api-docs/',views.api_docs,name="api_docs"),


]