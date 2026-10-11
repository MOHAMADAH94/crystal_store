# إضافة اللوغو

## خطوات إضافة اللوغو الخاص بك:

1. **ضع صورة اللوغو هنا:**
   - اسم الملف: `logo.png`
   - الحجم الموصى به: 512x512 بكسل أو أكبر
   - التنسيق: PNG مع خلفية شفافة (يفضل)

2. **إذا كان اسم الملف مختلف:**
   - افتح `lib/screens/splash_screen.dart`
   - ابحث عن `'assets/images/logo.png'`
   - غيّر اسم الملف إلى اسم ملفك

3. **بعد إضافة الصورة:**
   ```bash
   flutter pub get
   flutter clean
   flutter run
   ```

## ملاحظات:
- إذا لم تكن الصورة موجودة، سيتم عرض أيقونة الحقيبة الافتراضية
- تأكد من أن الصورة في مجلد `assets/images/`
- تأكد من أن `pubspec.yaml` يحتوي على:
  ```yaml
  assets:
    - assets/images/
    - assets/images/logo.png
  ```
