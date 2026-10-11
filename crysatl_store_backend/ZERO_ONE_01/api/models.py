from django.db import models
from django.contrib.auth.models import User
from products.models import Package
import secrets
import json


class APIKey(models.Model):
    """نموذج لإدارة API Keys - للمتاجر التي تستخدم منتجاتك (تأتي إليك)"""
    name = models.CharField(max_length=255, verbose_name="اسم المتجر")
    key = models.CharField(max_length=64, unique=True, verbose_name="API Key")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='api_keys', verbose_name="المستخدم")
    is_active = models.BooleanField(default=True, verbose_name="نشط")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="تاريخ الإنشاء")
    last_used = models.DateTimeField(null=True, blank=True, verbose_name="آخر استخدام")
    webhook_url = models.URLField(blank=True, null=True, verbose_name="Webhook URL")
    
    class Meta:
        verbose_name = "مفتاح API"
        verbose_name_plural = "مفاتيح API"
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.name} - {self.key[:8]}..."
    
    def save(self, *args, **kwargs):
        if not self.key:
            self.key = secrets.token_urlsafe(32)
        super().save(*args, **kwargs)


class ExternalStore(models.Model):
    """نموذج للمتاجر الخارجية - للمتاجر التي تستخدم منتجاتهم (تذهب إليهم)"""
    name = models.CharField(max_length=255, verbose_name="اسم المتجر")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='external_stores', verbose_name="المستخدم", help_text="حسابك في موقعهم - سيتم خصم المبلغ من رصيدك في موقعهم", null=True, blank=True)
    api_key = models.CharField(max_length=64, unique=True, verbose_name="API Key الخاص بهم", help_text="API Key الذي يعطيك إياه المتجر الخارجي - تستخدمه لإرسال طلبات إلى موقعهم")
    base_url = models.URLField(verbose_name="رابط المتجر")
    webhook_url = models.URLField(blank=True, null=True, verbose_name="Webhook URL")
    is_active = models.BooleanField(default=True, verbose_name="نشط")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="تاريخ الإنشاء")
    
    class Meta:
        verbose_name = "متجر خارجي"
        verbose_name_plural = "متاجر خارجية"
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.name} - {self.user.username if self.user else 'بدون مستخدم'}"


