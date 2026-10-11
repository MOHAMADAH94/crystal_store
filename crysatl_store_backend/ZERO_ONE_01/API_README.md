# دليل API - Zero One Store

## التثبيت والإعداد

### 1. تثبيت المتطلبات

```bash
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

## API Endpoints

### المصادقة

#### تسجيل مستخدم جديد
```
POST /api/auth/register/
Body: {
  "username": "string",
  "email": "string",
  "password": "string"
}
```

#### تسجيل الدخول
```
POST /api/auth/login/
Body: {
  "username": "string",
  "password": "string"
}
Response: {
  "token": "string",
  "user": {...}
}
```

### الفئات والمنتجات

#### الحصول على الفئات
```
GET /api/categories/
```

#### الحصول على المنتجات
```
GET /api/products/?category={category_id}
```

#### الحصول على الباقات
```
GET /api/packages/?product={product_id}
```

### الطلبات

#### الحصول على الطلبات
```
GET /api/orders/
Headers: Authorization: Token {token}
```

#### إنشاء طلب جديد
```
POST /api/orders/create_order/
Headers: Authorization: Token {token}
Body: {
  "package_id": int,
  "quantity": int,
  "gamer_id": "string",
  "custom_quantity": int (optional)
}
```

### الملف الشخصي

#### الحصول على الملف الشخصي
```
GET /api/profile/me/
Headers: Authorization: Token {token}
```

#### سجل الرصيد
```
GET /api/profile/balance_history/
Headers: Authorization: Token {token}
```

### الإشعارات

#### الحصول على الإشعارات
```
GET /api/notifications/
Headers: Authorization: Token {token}
```

#### تحديد الإشعار كمقروء
```
POST /api/notifications/{id}/mark_read/
Headers: Authorization: Token {token}
```

## نظام API Keys للمتاجر الخارجية

### إنشاء API Key

1. سجل الدخول إلى لوحة الإدارة
2. اذهب إلى قسم API Keys
3. أنشئ API Key جديد

### استخدام API Key

```
Headers: X-API-Key: {your_api_key}
```

### Webhooks

يمكنك إعداد Webhook URL في إعدادات API Key. سيتم إرسال إشعارات عند تحديث الطلبات.

## الربط مع المتاجر الخارجية

### إضافة متجر خارجي

1. سجل الدخول إلى لوحة الإدارة
2. اذهب إلى قسم External Stores
3. أضف المتجر الخارجي مع:
   - اسم المتجر
   - API Key الخاص بهم
   - Base URL
   - Webhook URL (اختياري)

### استقبال طلبات من متاجر خارجية

```
POST /api/external/order/
Headers: X-API-Key: {store_api_key}
Body: {
  "order_data": {...}
}
```

## ملاحظات الأمان

- استخدم HTTPS في الإنتاج
- قم بتعطيل CORS_ALLOW_ALL_ORIGINS في الإنتاج
- قم بتغيير SECRET_KEY في الإنتاج
- قم بتعطيل DEBUG في الإنتاج



