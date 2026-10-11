from django.contrib import messages
from django.contrib import admin
from django.http import HttpResponseRedirect
from django.urls import path, reverse
from orders.models import OrderDetails
from .models import Category, Product, Package, Agent, ExchangeRate
from django.utils.html import format_html

class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'ordering', 'image', "input_label", "input_placeholder")
    search_fields = ('name',)
    list_filter = ('parent_category',) 

class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'category','is_active', 'allow_decimal_qty', 'created_at', 'image') 
    list_filter = ('category','is_active', 'allow_decimal_qty')  
    search_fields = ('name', 'description')
    fieldsets = (
        ('معلومات أساسية', {
            'fields': ('name', 'category', 'description', 'image', 'is_active')
        }),
        ('إعدادات السعر', {
            'fields': ('coins_price',)
        }),
        ('إعدادات الكمية', {
            'fields': ('min_custom_quantity', 'max_custom_quantity', 'allow_decimal_qty'),
            'description': 'allow_decimal_qty: تفعيل هذا الخيار للسماح بإدخال الكمية كعدد عشري (مثل 1.5)'
        }),
        ('معلومات إضافية', {
            'fields': ('created_at',),
            'classes': ('collapse',)
        }),
    )
    readonly_fields = ('created_at',)  

class PackageAdmin(admin.ModelAdmin):
    list_display = ('name','price', 'product', 'is_active',)  
    list_filter = ('product__category','is_active', 'product', )  # 👈 أضفنا product__category
    search_fields = ('name', 'description')  
 

class AgentAdmin(admin.ModelAdmin):
    list_display = ('name', 'address', 'is_active',)  
    list_filter = ('name',)  
    search_fields = ('name', 'address')  


class ExchangeRateAdmin(admin.ModelAdmin):
    list_display = ('rate', 'is_active', 'created_at', 'updated_at')
    list_filter = ('is_active', 'created_at')
    search_fields = ('notes',)
    readonly_fields = ('created_at', 'updated_at')
    fields = ('rate', 'is_active', 'notes', 'created_at', 'updated_at')
    list_editable = ('is_active',)
    
    def has_delete_permission(self, request, obj=None):
        # منع حذف سعر الصرف النشط
        if obj and obj.is_active:
            return False
        return True
    
    def get_readonly_fields(self, request, obj=None):
        if obj and obj.is_active:
            # عند التعديل، السماح بتعديل السعر فقط
            return ['created_at', 'updated_at']
        return self.readonly_fields

admin.site.register(Category, CategoryAdmin)
admin.site.register(Product, ProductAdmin)
admin.site.register(Package, PackageAdmin)
admin.site.register(Agent, AgentAdmin)
admin.site.register(ExchangeRate, ExchangeRateAdmin)

