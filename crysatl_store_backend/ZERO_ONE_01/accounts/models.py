from django.db import models
from django.contrib.auth.models import User
from products.models import Package
from decimal import Decimal


# Create your models here.

class UserProfile(models.Model):
    LEVEL_CHOICES = [
        ('vip1', 'vip1'),
        ('vip2', 'vip2'),
        ('vip3', 'vip3'),
        ('vip4', 'vip4'),
        ('vip5', 'vip5'),
    ]
    
    CURRENCY_CHOICES = [
        ('USD', 'دولار أمريكي'),
        ('SYP', 'ليرة سورية'),
    ]
    
    user = models.OneToOneField(User, on_delete=models.CASCADE, verbose_name='المستخدم')
    favorite_package = models.ManyToManyField(Package, blank=True, verbose_name='الباقات المفضلة')
    address = models.CharField(max_length=60, verbose_name='العنوان')
    address2 = models.CharField(max_length=60, blank=True, null=True, verbose_name='العنوان الثاني')
    city = models.CharField(max_length=60, verbose_name='المدينة')
    state = models.CharField(max_length=60, verbose_name='المحافظة')
    phone = models.CharField(max_length=60, verbose_name='الهاتف')
    balance = models.DecimalField(max_digits=10, decimal_places=4, default=0.00, verbose_name='الرصيد')
    level = models.CharField(choices=LEVEL_CHOICES, max_length=4, default='vip1', verbose_name='المستوى')
    currency = models.CharField(choices=CURRENCY_CHOICES, max_length=3, default='USD', verbose_name='العملة')
    pin = models.CharField(max_length=4, blank=True, null=True, help_text='رمز PIN للحماية (4 أرقام)', verbose_name='رمز PIN')
    
    class Meta:
        verbose_name = 'ملف المستخدم'
        verbose_name_plural = 'ملفات المستخدمين'
    def save(self, *args, **kwargs):
        if self.pk:  # إذا كان هناك سجل موجود بالفعل
            original = UserProfile.objects.get(pk=self.pk)
            if original.balance != self.balance:  # إذا تم تغيير الرصيد
                BalanceLog.objects.create(
                    user_profile=self,
                    old_balance=original.balance,
                    new_balance=self.balance,
                    description='تحديث الرصيد'
                )
        super().save(*args, **kwargs)

    def __str__(self):
        return self.user.username
        


class BalanceLog(models.Model):
    user_profile = models.ForeignKey(UserProfile, on_delete=models.CASCADE, verbose_name='ملف المستخدم')
    old_balance = models.DecimalField(max_digits=10, decimal_places=4, verbose_name='الرصيد القديم')
    new_balance = models.DecimalField(max_digits=10, decimal_places=4, verbose_name='الرصيد الجديد')
    change_date = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ التغيير')
    description = models.CharField(max_length=255, verbose_name='الوصف')

    class Meta:
        verbose_name = 'سجل الرصيد'
        verbose_name_plural = 'سجلات الرصيد'
        ordering = ['-change_date']

    def __str__(self):
        return f"{self.user_profile.user.username} - {self.change_date}"
    
class PaymentMethod(models.Model):
    name = models.CharField(max_length=100, verbose_name='الاسم')
    image = models.ImageField(upload_to='photos/payment_methods', blank=True, null=True, verbose_name='الصورة')
    address = models.CharField(max_length=100, verbose_name='العنوان')
    details = models.TextField(blank=True, null=True, verbose_name='التفاصيل')
    discount_percentage = models.DecimalField(max_digits=5, decimal_places=2, default=0, verbose_name='نسبة الخصم')

    class Meta:
        verbose_name = 'طريقة الدفع'
        verbose_name_plural = 'طرق الدفع'

    def __str__(self):
        return self.name    
    
class Balance_add(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, verbose_name='المستخدم')
    amount = models.DecimalField(max_digits=10, decimal_places=2, verbose_name='المبلغ')
    receipt = models.ImageField(upload_to='photos/receipts_images', blank=False, null=False, verbose_name='الإيصال')
    is_processed = models.BooleanField(default=False, verbose_name='تم المعالجة')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')
    payment_method = models.ForeignKey(PaymentMethod, on_delete=models.CASCADE, verbose_name='طريقة الدفع')

    class Meta:
        verbose_name = 'طلب إضافة رصيد'
        verbose_name_plural = 'طلبات إضافة الرصيد'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.amount} - {self.payment_method.name}"

    def save(self, *args, **kwargs):
        if self.is_processed:
            user_profile = self.user.userprofile
            user_profile.balance += self.amount
            user_profile.save()

        super().save(*args, **kwargs)

    
    

class Notification(models.Model):
    title = models.CharField(max_length=255, verbose_name='العنوان')
    message = models.TextField(verbose_name='الرسالة')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')
    is_sent = models.BooleanField(default=False, verbose_name='تم الإرسال')

    class Meta:
        verbose_name = 'إشعار'
        verbose_name_plural = 'الإشعارات'
        ordering = ['-created_at']

    def __str__(self):
        return self.title


class UserNotification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, verbose_name='المستخدم')
    notification = models.ForeignKey(Notification, on_delete=models.CASCADE, verbose_name='الإشعار')
    read = models.BooleanField(default=False, verbose_name='مقروء')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ القراءة')

    class Meta:
        unique_together = ('user', 'notification')
        verbose_name = 'إشعار المستخدم'
        verbose_name_plural = 'إشعارات المستخدمين'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.notification.title}"
        


# accounts/models.py
from django.db import models

class Reports(models.Model):
    class Meta:
        verbose_name = "Report"
        managed = False  # لن يتم إنشاء جدول في قاعدة البيانات

        
        