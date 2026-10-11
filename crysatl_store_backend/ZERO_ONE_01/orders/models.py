from django.db import models
from django.contrib.auth.models import User
from products.models import Product
from products.models import Package
from django.dispatch import receiver
from django.db.models.signals import post_save
from django.core.mail import send_mail
from django.conf import settings 



# Create your models here.

class Order(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, verbose_name='المستخدم')
    order_date = models.DateTimeField(verbose_name='تاريخ الطلب')
    detail = models.ManyToManyField(Package, through='OrderDetails', verbose_name='التفاصيل')
    is_finished = models.BooleanField(verbose_name='مكتمل')

    class Meta:
        verbose_name = 'طلب'
        verbose_name_plural = 'الطلبات'
        ordering = ['-order_date']

    def __str__(self):
        return f'المستخدم: {self.user.username} - رقم الطلب: {self.id}'
    


class OrderDetails(models.Model):
    STATUS_CHOICES = [
        ('pending', 'قيد المعالجة'),
        ('rejected', 'مرفوض'),
        ('done', 'مكتمل'),
    ]
    
    Package = models.ForeignKey(Package, on_delete=models.CASCADE, verbose_name='الباقة')
    order = models.ForeignKey(Order, on_delete=models.CASCADE, verbose_name='الطلب')
    price = models.DecimalField(max_digits=10, decimal_places=4, verbose_name='السعر الأصلي')
    final_price = models.DecimalField(max_digits=10, decimal_places=4, default=0.0, verbose_name='السعر النهائي')
    gamer_id = models.CharField(max_length=225, verbose_name='معرف اللاعب')
    quantity = models.DecimalField(max_digits=10, decimal_places=4, verbose_name='الكمية')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending', verbose_name='الحالة')
    response = models.CharField(max_length=225, blank=True, null=True, verbose_name='الرد')
    external_order_id = models.CharField(max_length=225, blank=True, null=True, verbose_name='رقم الطلب الخارجي', help_text='رقم الطلب من API الخارجي')
    has_been_refunded = models.BooleanField(default=False, verbose_name='تم استرداد المبلغ')

    class Meta:
        ordering = ['-id']
        verbose_name = 'تفاصيل الطلب'
        verbose_name_plural = 'تفاصيل الطلبات'

    def __str__(self):
        return f'المستخدم: {self.order.user.username}, الباقة: {self.Package.name}, معرف اللاعب: {self.gamer_id}, رقم الطلب: {self.order.id}'





class MailSender(models.Model):
    email = models.EmailField(verbose_name='البريد الإلكتروني')
    code = models.CharField(max_length=100, verbose_name='الكود')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')
    message = models.TextField(verbose_name='الرسالة')
    sent = models.BooleanField(default=False, verbose_name='تم الإرسال')

    class Meta:
        verbose_name = 'مرسل البريد'
        verbose_name_plural = 'مرسلو البريد'
        ordering = ['-created_at']

    def send_email(self):
        subject = 'Your Subject Here'
        full_message = f'{self.message}\n\nCode: {self.code}'
        send_mail(
            subject,
            full_message,
            settings.EMAIL_HOST_USER,
            [self.email],
            fail_silently=False,
        )

    def __str__(self):
        return f"Mail to {self.email} with code {self.code}"