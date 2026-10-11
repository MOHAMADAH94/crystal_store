# تطبيق Zero One Store - Flutter

## التثبيت والإعداد

### 1. تثبيت المتطلبات

```bash
flutter pub get
```

### 2. تحديث إعدادات API

افتح ملف `lib/config/api_config.dart` وقم بتحديث `baseUrl` إلى رابط السيرفر الخاص بك:

```dart
static const String baseUrl = 'http://your-server.com/api';
```

### 3. تشغيل التطبيق

```bash
flutter run
```

## الميزات

- ✅ تسجيل الدخول والتسجيل
- ✅ عرض الفئات والمنتجات
- ✅ عرض تفاصيل المنتج والباقات
- ✅ إنشاء طلبات جديدة
- ✅ عرض الطلبات وحالتها
- ✅ الملف الشخصي وإدارة الرصيد
- ✅ سجل تغييرات الرصيد
- ✅ تصميم حديث واحترافي

## البنية

```
lib/
├── config/
│   └── api_config.dart      # إعدادات API
├── models/
│   ├── user_model.dart       # نماذج المستخدم
│   ├── product_model.dart    # نماذج المنتجات
│   └── order_model.dart      # نماذج الطلبات
├── providers/
│   ├── auth_provider.dart    # إدارة المصادقة
│   ├── product_provider.dart # إدارة المنتجات
│   └── order_provider.dart   # إدارة الطلبات
├── screens/
│   ├── auth/                 # شاشات المصادقة
│   ├── home/                 # الشاشة الرئيسية
│   ├── products/             # شاشات المنتجات
│   ├── orders/               # شاشات الطلبات
│   └── profile/              # شاشات الملف الشخصي
├── services/
│   └── api_service.dart      # خدمة API
└── main.dart                 # نقطة البداية
```

## الحزم المستخدمة

- `dio`: للاتصال بالـ API
- `provider`: لإدارة الحالة
- `shared_preferences`: لحفظ البيانات المحلية
- `cached_network_image`: لعرض الصور
- `intl`: لتنسيق التواريخ

## ملاحظات

- تأكد من تحديث رابط API في `api_config.dart`
- التطبيق يدعم اللغة العربية
- التصميم متجاوب ويعمل على جميع الأجهزة
