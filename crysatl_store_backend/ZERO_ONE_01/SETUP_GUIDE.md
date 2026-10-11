# دليل الإعداد الكامل - Zero One Store

## الجزء الأول: إعداد Django API

### 1. تثبيت المتطلبات

```bash
cd ZERO_ONE_01
pip install -r requirements.txt
```

### 2. إعداد قاعدة البيانات

```bash
python manage.py makemigrations
python manage.py migrate
```

### 3. إنشاء مستخدم إداري

```bash
python manage.py createsuperuser
```

### 4. تشغيل السيرفر

```bash
python manage.py runserver
```

الآن API سيكون متاحاً على: `http://localhost:8000/api/`

### 5. إعداد API Keys للمتاجر الخارجية

1. افتح `http://localhost:8000/admin/`
2. سجل الدخول بحساب الإدارة
3. اذهب إلى قسم "API Keys"
4. أنشئ API Key جديد للمتاجر الخارجية

## الجزء الثاني: إعداد تطبيق Flutter

### 1. تثبيت المتطلبات

```bash
cd "abuhussein flutter/my_app"
flutter pub get
```

### 2. تحديث إعدادات API

افتح ملف `lib/config/api_config.dart` وقم بتحديث:

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8000/api';
```

**ملاحظة:** إذا كنت تقوم بالاختبار على جهاز حقيقي:
- استبدل `localhost` بـ IP جهازك (مثل: `192.168.1.100`)
- تأكد من أن Django يعمل على `0.0.0.0:8000` وليس `127.0.0.1:8000`

### 3. تشغيل التطبيق

```bash
flutter run
```

## الربط مع المتاجر الخارجية

### للمتاجر التي تريد الربط معك:

1. أنشئ API Key لهم من لوحة الإدارة
2. أعطهم API Key الخاص بهم
3. يمكنهم استخدام الـ API باستخدام Header: `X-API-Key: {their_key}`

### للمتاجر التي تريد الربط معها:

1. اذهب إلى لوحة الإدارة > External Stores
2. أضف المتجر الخارجي:
   - اسم المتجر
   - API Key الخاص بهم (الذي أعطوك إياه)
   - Base URL للمتجر
   - Webhook URL (اختياري)

### Webhooks

عند تحديث أي طلب، سيتم إرسال إشعار تلقائي إلى Webhook URL للمتاجر الخارجية المرتبطة.

## نصائح للإنتاج

1. **الأمان:**
   - قم بتغيير `SECRET_KEY` في `settings.py`
   - عطّل `DEBUG = False`
   - قم بتحديد `ALLOWED_HOSTS`
   - استخدم HTTPS
   - قم بتعطيل `CORS_ALLOW_ALL_ORIGINS` وحدد `CORS_ALLOWED_ORIGINS`

2. **قاعدة البيانات:**
   - استخدم MySQL أو PostgreSQL بدلاً من SQLite
   - قم بعمل نسخ احتياطي منتظم

3. **الأداء:**
   - استخدم Redis للـ caching
   - استخدم CDN للصور والملفات الثابتة

## استكشاف الأخطاء

### مشكلة الاتصال بالـ API من Flutter:

1. تأكد من أن Django يعمل
2. تأكد من تحديث `baseUrl` في `api_config.dart`
3. تأكد من أن الجهاز/المحاكي يمكنه الوصول إلى السيرفر
4. تحقق من CORS settings في Django

### مشكلة المصادقة:

1. تأكد من أن Token يتم حفظه بشكل صحيح
2. تحقق من أن Header `Authorization` يتم إرساله مع كل طلب

## الدعم

للمزيد من المعلومات، راجع:
- `API_README.md` - دليل API الكامل
- `abuhussein flutter/my_app/README.md` - دليل تطبيق Flutter



