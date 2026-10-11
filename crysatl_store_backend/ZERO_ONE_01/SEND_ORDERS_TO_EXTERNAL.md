# دليل إرسال الطلبات إلى المتاجر الخارجية

## 📋 السيناريو

لديك رابط من صديقك أحمد:
```
POST https://www.xp-card.com/api/create-order
```

تريد أن **الطلبات التي يتم طلبها في موقعك** تذهب تلقائياً إلى موقع أحمد.

---

## 🎯 الحل

### الخطوة 1: إضافة متجر خارجي في لوحة التحكم

1. اذهب إلى `/admin/api/externalstore/`
2. اضغط "Add External Store"
3. أدخل:
   - **اسم المتجر**: "موقع أحمد"
   - **المستخدم**: اختر حسابك (الحساب الذي لديك في موقع أحمد)
   - **API Key الخاص بهم**: API Key الذي أعطاك إياه أحمد
   - **Base URL**: `https://www.xp-card.com`
   - **Webhook URL** (اختياري): إذا كان أحمد يريد إشعارات

### الخطوة 2: فهم كيفية إرسال الطلبات

هناك **طريقتان** لإرسال الطلبات:

#### الطريقة 1: إرسال يدوي (عند إنشاء طلب في موقعك)

عندما ينشئ مستخدم طل    ب في موقعك، يمكنك إرساله تلقائياً إلى موقع أحمد.

#### الطريقة 2: إرسال تلقائي (عند تحديث الطلب)

عند تحديث حالة الطلب في موقعك، يتم إرسال إشعار إلى موقع أحمد.

---

## 🔧 التنفيذ

### مثال: إرسال طلب إلى موقع أحمد

```python
import requests

# بيانات المتجر الخارجي
EXTERNAL_STORE_URL = "https://www.xp-card.com"
EXTERNAL_API_KEY = "ahmed_api_key_12345"  # API Key الذي أعطاك إياه أحمد

# بيانات الطلب من موقعك
order_data = {
    "package_id": 1,
    "quantity": 5,
    "gamer_id": "player123"
}

# إرسال الطلب إلى موقع أحمد
response = requests.post(
    f"{EXTERNAL_STORE_URL}/api/create-order",
    headers={
        'X-API-Key': EXTERNAL_API_KEY,
        'Content-Type': 'application/json'
    },
    json=order_data
)

result = response.json()
print(result)
```

---

## 🔄 دمج مع نظامك الحالي

### الخيار 1: إرسال تلقائي عند إنشاء طلب

يمكنك تعديل `create_order` في `api/views.py` لإرسال الطلب تلقائياً إلى المتاجر الخارجية:

```python
# في create_order function
# بعد إنشاء الطلب بنجاح

# إرسال الطلب إلى المتاجر الخارجية
for external_store in ExternalStore.objects.filter(is_active=True):
    try:
        # إرسال الطلب إلى المتجر الخارجي
        send_order_to_external_store(order, external_store)
    except Exception as e:
        print(f"Error sending order to {external_store.name}: {e}")
```

### الخيار 2: إرسال يدوي من لوحة التحكم

يمكنك إضافة زر في لوحة التحكم لإرسال الطلب إلى المتاجر الخارجية.

---

## 📝 مثال كامل

### 1. إضافة متجر خارجي

في لوحة التحكم (`/admin/api/externalstore/`):
- **اسم المتجر**: "موقع أحمد"
- **المستخدم**: حسابك في موقع أحمد
- **API Key**: `ahmed_api_key_12345`
- **Base URL**: `https://www.xp-card.com`

### 2. إرسال طلب

```python
import requests
from api.models import ExternalStore

# الحصول على المتجر الخارجي
external_store = ExternalStore.objects.get(name="موقع أحمد")

# بيانات الطلب
order_data = {
    "package_id": 1,
    "quantity": 5,
    "gamer_id": "player123"
}

# إرسال الطلب
response = requests.post(
    f"{external_store.base_url}/api/create-order",
    headers={
        'X-API-Key': external_store.api_key,
        'Content-Type': 'application/json'
    },
    json=order_data
)

if response.status_code == 200:
    print("✅ تم إرسال الطلب بنجاح")
    print(response.json())
else:
    print("❌ فشل إرسال الطلب")
    print(response.text)
```

---

## 🔧 إضافة وظيفة تلقائية

يمكنك إضافة وظيفة في `api/views.py`:

```python
def send_order_to_external_store(order, external_store):
    """إرسال طلب إلى متجر خارجي"""
    import requests
    
    # تحضير بيانات الطلب
    order_data = {
        "package_id": order.orderdetails_set.first().Package.id,
        "quantity": order.orderdetails_set.first().quantity,
        "gamer_id": order.orderdetails_set.first().gamer_id,
        # يمكنك إضافة المزيد من البيانات
    }
    
    try:
        response = requests.post(
            f"{external_store.base_url}/api/create-order",
            headers={
                'X-API-Key': external_store.api_key,
                'Content-Type': 'application/json'
            },
            json=order_data,
            timeout=10  # timeout 10 ثواني
        )
        
        if response.status_code == 200:
            print(f"✅ تم إرسال الطلب {order.id} إلى {external_store.name}")
            return True
        else:
            print(f"❌ فشل إرسال الطلب {order.id} إلى {external_store.name}: {response.text}")
            return False
    except Exception as e:
        print(f"❌ خطأ في إرسال الطلب {order.id} إلى {external_store.name}: {str(e)}")
        return False
```

ثم استدعها في `create_order`:

```python
# بعد إنشاء الطلب بنجاح
for external_store in ExternalStore.objects.filter(is_active=True):
    send_order_to_external_store(order, external_store)
```

---

## 📊 المخطط

```
┌─────────────────┐
│  مستخدم في      │
│  موقعك          │
└────────┬────────┘
         │
         │ 1. ينشئ طلب
         ▼
┌─────────────────┐
│   موقعك         │
│                 │
│ 2. يتم إنشاء    │
│    الطلب        │
└────────┬────────┘
         │
         │ 3. إرسال تلقائي
         │    إلى المتاجر
         │    الخارجية
         ▼
┌─────────────────┐
│  موقع أحمد      │
│  (xp-card.com)  │
│                 │
│ 4. يتم إنشاء    │
│    الطلب        │
└─────────────────┘
```

---

## ⚠️ ملاحظات مهمة

### 1. API Key
- يجب أن يعطيك أحمد **API Key** من موقعه
- هذا API Key يسمح لك بإرسال طلبات إلى موقعه

### 2. تنسيق البيانات
- تأكد من أن **تنسيق البيانات** يطابق ما يتوقعه موقع أحمد
- قد تحتاج إلى تعديل `order_data` حسب متطلبات موقع أحمد

### 3. الأمان
- استخدم **HTTPS** دائماً
- لا تشارك API Keys مع أي شخص

### 4. معالجة الأخطاء
- تأكد من معالجة الأخطاء بشكل صحيح
- لا توقف عملية إنشاء الطلب في موقعك إذا فشل الإرسال

---

## 🎯 الخلاصة

1. **أضف متجر خارجي** في `/admin/api/externalstore/`
2. **أدخل API Key** الذي أعطاك إياه أحمد
3. **أدخل Base URL**: `https://www.xp-card.com`
4. **أضف وظيفة** لإرسال الطلبات تلقائياً (اختياري)
5. **اختبر الإرسال** للتأكد من أن كل شيء يعمل

---

## 📞 الدعم

للمزيد من المعلومات:
- راجع `API_CLEAR_GUIDE.md` للدليل الشامل
- راجع `EXTERNAL_STORE_SETUP.md` لإعداد المتاجر الخارجية
