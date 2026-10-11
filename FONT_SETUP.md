# إعداد الخط الافتراضي للتطبيق

## الخط المستخدم
- **اسم الخط**: AlinmaSans
- **اسم الملف**: `alfont_com_The-Sans-Plain-alinma.ttf`
- **المسار**: `assets/fonts/alfont_com_The-Sans-Plain-alinma.ttf`

## الإعدادات المطبقة

### 1. إضافة الخط في `pubspec.yaml`
تم إضافة الخط في قسم `fonts`:
```yaml
fonts:
  - family: AlinmaSans
    fonts:
      - asset: assets/fonts/alfont_com_The-Sans-Plain-alinma.ttf
```

### 2. تعيين الخط كخط افتراضي في `main.dart`
تم تعيين الخط كخط افتراضي في `ThemeData`:
- `fontFamily: 'AlinmaSans'` - الخط الافتراضي
- `textTheme` - جميع أنواع النصوص تستخدم الخط

## الاستخدام

الخط الآن هو الخط الافتراضي لجميع النصوص في التطبيق. لا حاجة لتحديده يدوياً في كل `Text` widget.

### إذا أردت استخدام خط آخر في مكان معين:
```dart
Text(
  'نص بخط مختلف',
  style: TextStyle(fontFamily: 'Roboto'), // أو أي خط آخر
)
```

### إذا أردت التأكد من استخدام الخط الافتراضي:
```dart
Text(
  'نص بالخط الافتراضي',
  style: TextStyle(fontFamily: 'AlinmaSans'),
)
```

## الخطوات التالية

1. **إعادة بناء التطبيق:**
   ```bash
   cd "abuhussein flutter/my_app"
   flutter pub get
   flutter clean
   flutter run
   ```

2. **التحقق من الخط:**
   - افتح التطبيق وتحقق من أن جميع النصوص تستخدم الخط الجديد
   - الخط يجب أن يظهر في جميع الشاشات تلقائياً

## ملاحظات

- الخط يعمل تلقائياً في جميع أنحاء التطبيق
- لا حاجة لتحديد الخط في كل `Text` widget
- إذا كان هناك أي نص لا يظهر بالخط الجديد، تأكد من أن `pubspec.yaml` تم تحديثه بشكل صحيح
