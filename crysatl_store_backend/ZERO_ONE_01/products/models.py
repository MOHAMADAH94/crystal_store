
from django.db import models
# from decimal import Decimal, InvalidOperation

# Create your models here.



class Category(models.Model):
    name = models.CharField(max_length=255, verbose_name='الاسم')
    ordering = models.IntegerField(default=0, verbose_name='الترتيب')
    image = models.ImageField(upload_to='photos/category_images', blank=True, null=True, verbose_name='الصورة')
    input_label = models.CharField(max_length=255, blank=True, null=True, verbose_name='نص الحقل')
    input_placeholder = models.CharField(max_length=255, blank=True, null=True, verbose_name='Placeholder')
    parent_category = models.ForeignKey('self', on_delete=models.CASCADE, blank=True, null=True, related_name='subcategories', help_text='الفئة الأساسية (اتركه فارغاً للفئات الأساسية)', verbose_name='الفئة الأساسية')

    class Meta:
        ordering = ['ordering']
        verbose_name = 'فئة'
        verbose_name_plural = 'الفئات'

    def __str__(self):
        return self.name
    
    def is_parent(self):
        """تحقق إذا كانت هذه فئة أساسية"""
        return self.parent_category is None
    
    def is_subcategory(self):
        """تحقق إذا كانت هذه فئة فرعية"""
        return self.parent_category is not None



class Product(models.Model):
    category = models.ForeignKey(Category, related_name='products', on_delete=models.CASCADE, verbose_name='الفئة')
    name = models.CharField(max_length=225, verbose_name='الاسم')
    description = models.TextField(blank=False, null=False, verbose_name='الوصف')
    coins_price = models.DecimalField(max_digits=10, decimal_places=6, blank=True, null=True, verbose_name='سعر العملة', help_text='عدد العملات لكل دولار')
    image = models.ImageField(upload_to='photos/product_images', blank=False, null=False, verbose_name='الصورة')
    is_active = models.BooleanField(default=True, verbose_name='نشط')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')
    min_custom_quantity = models.PositiveIntegerField(blank=True, null=True, help_text='أصغر قيمة للباقات المفتوحة', verbose_name='الحد الأدنى للكمية')
    max_custom_quantity = models.PositiveIntegerField(blank=True, null=True, help_text='أكبر قيمة للباقات المفتوحة', verbose_name='الحد الأقصى للكمية')
    allow_decimal_qty = models.BooleanField(default=False, verbose_name='السماح بالكمية العشرية', help_text='تفعيل هذا الخيار للسماح بإدخال الكمية كعدد عشري (مثل 1.5)')

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'منتج'
        verbose_name_plural = 'المنتجات' 

    def __str__(self):
        return self.name





class Package(models.Model):
    product = models.ForeignKey(Product, related_name='packages', on_delete=models.CASCADE, verbose_name='المنتج')
    name = models.CharField(max_length=100, verbose_name='الاسم')
    description = models.TextField(blank=True, verbose_name='الوصف')
    quantity = models.PositiveIntegerField(blank=False, null=False, verbose_name='الكمية')
    price = models.DecimalField(max_digits=10, decimal_places=4, blank=True, null=True, verbose_name='السعر')
    image = models.ImageField(upload_to='photos/package_images', blank=True, null=True, verbose_name='الصورة')
    is_active = models.BooleanField(default=True, verbose_name='نشط')
    is_custom = models.BooleanField(default=False, verbose_name='باقة مخصصة')
    denomination_id = models.IntegerField(blank=True, null=True, verbose_name='معرف الفئة')
    
    class Meta:
        ordering = ['-id']
        verbose_name = 'باقة'
        verbose_name_plural = 'الباقات'

    def __str__(self):
        return self.name
    



    def calculate_custom_price(self):
        if self.is_custom:
            coins_price = self.product.coins_price
            if coins_price is not None and coins_price > 0:
                if self.quantity > 0:  # تأكد من أن الكمية أكبر من 0
                    total_price = round(self.quantity * coins_price, 4)
                    return total_price if total_price > 0 else 0
                return 0  # إذا كانت الكمية غير صحيحة
            return 0  # إذا كان coins_price غير متاح
        return self.price  # استخدم سعر الوحدة إذا لم تكن مخصصة
    

    

class Agent(models.Model):
    name = models.CharField(max_length=255, verbose_name='الاسم')
    address = models.TextField(blank=True, verbose_name='العنوان')
    image = models.ImageField(upload_to='photos/agent_images', blank=True, null=True, verbose_name='الصورة')
    contact_info = models.CharField(max_length=255, blank=True, verbose_name='معلومات الاتصال')
    is_active = models.BooleanField(default=True, verbose_name='نشط')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'وكيل'
        verbose_name_plural = 'الوكلاء'

    def __str__(self):
        return self.name


class ExchangeRate(models.Model):
    """نموذج لإدارة سعر الصرف بين الدولار والليرة السورية"""
    rate = models.DecimalField(
        max_digits=12, 
        decimal_places=4, 
        default=15000.0,
        help_text='سعر الصرف: 1 USD = ? SYP'
    )
    is_active = models.BooleanField(default=True, help_text='السعر النشط الحالي')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    notes = models.TextField(blank=True, null=True, help_text='ملاحظات حول التغيير')
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = 'سعر الصرف'
        verbose_name_plural = 'أسعار الصرف'
    
    def __str__(self):
        return f'1 USD = {self.rate} SYP'
    
    def save(self, *args, **kwargs):
        # عند تفعيل سعر صرف جديد، إلغاء تفعيل الباقي
        if self.is_active:
            ExchangeRate.objects.filter(is_active=True).exclude(pk=self.pk).update(is_active=False)
        super().save(*args, **kwargs)
    
    @classmethod
    def get_current_rate(cls):
        """الحصول على سعر الصرف النشط الحالي"""
        active_rate = cls.objects.filter(is_active=True).first()
        if active_rate:
            return active_rate.rate
        # إذا لم يكن هناك سعر نشط، إرجاع آخر سعر
        last_rate = cls.objects.first()
        if last_rate:
            return last_rate.rate
        # القيمة الافتراضية
        from decimal import Decimal
        return Decimal('15000.0')
    
    