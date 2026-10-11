# سجل التغييرات - تحديث عرض الأسعار

## التاريخ: 19 ديسمبر 2025 (تم التحديث)

## الهدف من التحديث
عرض السعر حسب مستوى المستخدم فقط دون الإفصاح عن السعر الأصلي أو نسبة الربح، وضمان أن السعر المعروض في المودال يطابق السعر المقتطع من الرصيد.

---

## الملفات المعدلة

### 1. `orders/admin.py` ⭐ جديد

#### التغييرات:

**أ. تعديل دالة `final_price` (السطور 653-661):**
- **قبل:** كانت تحسب السعر بإضافة نسبة الربح على `price` (مما يسبب زيادة مضاعفة)
- **بعد:** 
  - استخدام `final_price` من النموذج إذا كان موجوداً (السعر المقتطع فعلياً)
  - أو استخدام `price` مباشرة (لأنه الآن يحتوي على السعر بعد الزيادة)
  - إزالة حساب نسبة الربح المضاعف

**الكود الجديد:**
```python
def final_price(self, order_detail):
    # استخدم final_price من النموذج إذا كان موجوداً (هو السعر المقتطع فعلياً)
    if order_detail.final_price and order_detail.final_price > 0:
        return order_detail.final_price
    # وإلا استخدم price (الذي يحتوي الآن على السعر بعد الزيادة)
    return order_detail.price

def final_price_display(self, obj):
    return f"${self.final_price(obj):.4f}"
final_price_display.short_description = "السعر المدفوع"
```

**ب. إضافة دالة `price_display` (السطور 664-667):**
- عرض السعر المحفوظ في `price` بشكل منفصل للوضوح

**ج. تعديل `list_display` (السطر 631-634):**
- تغيير `'price'` إلى `'price_display'` لعرض السعر بشكل أفضل

**د. تحديث `reject_order_view` و `reject_order_action`:**
- استخدام `self.final_price()` للحصول على السعر الصحيح عند استرداد المبلغ

---

### 2. `orders/views.py`

#### التغييرات:

**أ. إضافة استيراد ROUND_DOWN:**
```python
# السطر 530: تم تغيير
from decimal import Decimal
# إلى
from decimal import Decimal, ROUND_DOWN
```

**ب. تعديل دالة `add_to_cart` (السطور 626-695):**
- **قبل:** كان يحسب السعر الأصلي ثم يحفظه، ويتم حساب السعر بعد الزيادة لاحقاً
- **بعد:** 
  - حساب السعر بعد الزيادة مباشرة حسب مستوى المستخدم
  - للباقات المخصصة: حساب سعر الوحدة بعد الزيادة ثم الضرب في الكمية (مطابق للمودال)
  - للباقات العادية: حساب سعر الباقة بعد الزيادة مباشرة
  - حفظ السعر بعد الزيادة في `OrderDetails.price` بدلاً من السعر الأصلي
  - إصلاح استخدام `final_total` إلى `final_price` في قسم الدفع المباشر
  - إصلاح `redirect('products:package', ...)` إلى `redirect('package', ...)`

**الكود الجديد:**
```python
# حساب السعر بعد الزيادة حسب مستوى المستخدم (مطابق للمودال)
user_profile = request.user.userprofile
profit_rate = PROFIT_CHOICES.get(user_profile.level, Decimal('0.0'))

if pack.is_custom:
    # للباقات المخصصة: حساب سعر الوحدة بعد الزيادة ثم الضرب في الكمية
    base_unit_price = pack.product.coins_price or Decimal('0.0')
    unit_price_after_profit = base_unit_price * (Decimal('1') + profit_rate)
    unit_price_after_profit = unit_price_after_profit.quantize(Decimal('0.000001'), rounding=ROUND_DOWN)
    final_price = unit_price_after_profit * quantity
else:
    # للباقات العادية: حساب سعر الباقة بعد الزيادة مباشرة
    quantity = pack.quantity
    base_price = pack.price or Decimal('0.0')
    final_price = base_price * (Decimal('1') + profit_rate)

final_price = final_price.quantize(Decimal('0.0001'), rounding=ROUND_DOWN)

# حفظ السعر بعد الزيادة مباشرة
order_detail = OrderDetails.objects.create(
    Package=pack,
    order=order,
    price=final_price,  # حفظ السعر بعد الزيادة مباشرة
    ...
)
```

**ج. تعديل دالة `payment` (السطور 755-812):**
- **قبل:** كان يحسب السعر الأصلي ثم يضيف نسبة الربح لاحقاً
- **بعد:**
  - استخدام السعر المحفوظ مباشرة (الذي هو بالفعل بعد الزيادة)
  - إزالة حساب نسبة الربح من السياق
  - تبسيط الكود لاستخدام `final_total` مباشرة من السعر المحفوظ

**الكود الجديد:**
```python
order_details = order.orderdetails_set.all()
# السعر المحفوظ هو بالفعل السعر بعد الزيادة
final_total = sum(Decimal(sub.price) for sub in order_details)

# في قسم الحفظ:
detail.final_price = detail.price  # السعر المحفوظ هو نفسه السعر النهائي

# في السياق:
context = {
    'order': order,
    'order_details': order_details,
    'total': final_total,  # السعر الإجمالي (بعد الزيادة)
    'balance': request.user.userprofile.balance,
    'profit': Decimal('0.0'),  # لا نعرض نسبة الربح
    'final_total': final_total,  # نفس السعر الإجمالي
}
```

---

### 2. `templates/orders/payment.html`

#### التغييرات:

**أ. إزالة عرض "المجموع" و"نسبة الربح" (السطر 46-48):**
- **قبل:** كان يعرض "المجموع" و"المجموع النهائي" و"نسبة الربح"
- **بعد:** يعرض فقط "المجموع النهائي" و"الرصيد المتاح"

**الكود الجديد:**
```html
<div class="bg-light p-4 rounded border border-secondary mb-4">
    <p class="mb-1"><strong class="text-dark">المجموع النهائي:</strong> ${{ final_total|floatformat:4 }}</p>
    <p class="mb-0"><strong class="text-dark">الرصيد المتاح:</strong> ${{ balance|floatformat:4 }}</p>
</div>
```

**ب. تحسين عرض السعر في تفاصيل الطلب (السطر 38):**
- إضافة `|floatformat:4` لعرض السعر بدقة 4 أرقام عشرية

---

### 3. `templates/orders/cart.html`

#### التغييرات:

**تحسين عرض السعر (السطر 41):**
- إضافة `|floatformat:4` لعرض السعر بدقة 4 أرقام عشرية

**الكود الجديد:**
```html
<td class="fw-bold">${{ line.price|floatformat:4 }}</td>
```

---

### 4. `templates/orders/show_orders.html`

#### التغييرات:

**تحسين عرض السعر (السطور 87-94):**
- عرض `final_price` إذا كان متوفراً، وإلا عرض `price`
- إضافة `|floatformat:4` لعرض السعر بدقة 4 أرقام عشرية

**الكود الجديد:**
```html
<td>
  {% for detail in order.orderdetails_set.all %}
      {% if detail.final_price %}
          ${{ detail.final_price|floatformat:4 }}
      {% else %}
          ${{ detail.price|floatformat:4 }}
      {% endif %}
  {% endfor %}
</td>
```

---

## ملخص التغييرات الوظيفية

### ما تم تغييره:
1. ✅ **حساب السعر:** الآن يتم حساب السعر بعد الزيادة مباشرة عند إضافة المنتج للسلة
2. ✅ **حفظ السعر:** يتم حفظ السعر بعد الزيادة في `OrderDetails.price` بدلاً من السعر الأصلي
3. ✅ **عرض السعر:** إزالة عرض السعر الأصلي ونسبة الربح من جميع الصفحات
4. ✅ **توحيد الحساب:** توحيد طريقة حساب السعر بين المودال والـ backend
5. ✅ **إصلاح الأخطاء:** إصلاح خطأ NoReverseMatch وإصلاح استخدام المتغيرات

### ما لم يتغير:
- ✅ منطق حساب نسبة الربح (يبقى كما هو في `settings.PROFIT_CHOICES`)
- ✅ بنية قاعدة البيانات (لا توجد migrations مطلوبة)
- ✅ واجهة المستخدم الأساسية (فقط تحسينات على عرض السعر)

---

## خطوات النشر على السيرفر

### 1. نسخ الملفات المعدلة:
```bash
# نسخ الملفات التالية إلى السيرفر:
- orders/views.py
- templates/orders/payment.html
- templates/orders/cart.html
- templates/orders/show_orders.html
```

### 2. التحقق من عدم وجود أخطاء:
```bash
python manage.py check
```

### 3. لا حاجة لتشغيل migrations:
- لا توجد تغييرات على النماذج (Models)
- التغييرات فقط في المنطق (Views) والعرض (Templates)

### 4. إعادة تشغيل الخادم (إذا لزم الأمر):
```bash
# حسب نوع الخادم المستخدم
# Apache/Nginx: إعادة تحميل الخادم
# Gunicorn/uWSGI: إعادة تشغيل العملية
```

---

## ملاحظات مهمة

1. **البيانات الموجودة:** الطلبات القديمة التي تم حفظها قبل التحديث قد تحتوي على السعر الأصلي في `price`. يمكنك:
   - تركها كما هي (لن تؤثر على الطلبات الجديدة)
   - أو تحديثها يدوياً إذا أردت

2. **الاختبار:** تأكد من اختبار:
   - إضافة منتج عادي للسلة
   - إضافة منتج مخصص (custom) للسلة
   - الدفع المباشر
   - الدفع من صفحة السلة
   - عرض الطلبات السابقة

3. **النسخ الاحتياطي:** يُنصح بعمل نسخة احتياطية من قاعدة البيانات قبل النشر

---

## الملفات المتأثرة (قائمة كاملة)

```
orders/
├── views.py                    [معدل - تغييرات كبيرة]
└── admin.py                    [معدل - إصلاح عرض السعر في لوحة التحكم] ⭐ جديد

templates/orders/
├── payment.html                 [معدل - تحسينات على العرض]
├── cart.html                    [معدل - تحسينات بسيطة]
└── show_orders.html             [معدل - تحسينات بسيطة]
```

**إجمالي الملفات المعدلة: 5 ملفات**

