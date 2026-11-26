# 📦 تثبيت الحزم - تعليمات

## ⚠️ المشكلة:

الأخطاء موجودة لأن الحزم غير مثبتة. يجب تشغيل `flutter pub get` أولاً.

## ✅ الحل:

### من VS Code / IDE:

1. **افتح Terminal في VS Code** (Ctrl + `)
2. **تأكد أنك في مجلد المشروع:** `E:\pro\taland`
3. **شغّل:**
   ```bash
   flutter pub get
   ```

---

### من Command Prompt:

1. **افتح Command Prompt**
2. **انتقل إلى مجلد المشروع:**
   ```bash
   cd E:\pro\taland
   ```
3. **شغّل:**
   ```bash
   flutter pub get
   ```

---

### أو شغّل الملف:

انقر نقراً مزدوجاً على: **`تثبيت_الحزم.bat`**

---

## ✅ بعد التثبيت:

ستختفي جميع الأخطاء تلقائياً:
- ✅ `lib/main.dart` - 7 أخطاء → 0
- ✅ `lib/language_screen.dart` - 3 أخطاء → 0

---

## 📋 الحزم التي سيتم تثبيتها:

- ✅ `flutter_localizations` (من Flutter SDK)
- ✅ `intl: ^0.19.0` (مع override إلى `^0.20.2`)
- ✅ `provider: ^6.1.1`

---

**ملاحظة:** بعد تشغيل `flutter pub get` بنجاح، ستختفي جميع الأخطاء تلقائياً!






















