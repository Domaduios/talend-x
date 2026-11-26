# نشر Firestore Rules - خطوات سريعة

## ⚠️ مهم جداً: يجب نشر القواعد في Firebase Console

الخطأ `permission-denied` يحدث لأن قواعد Firestore لم يتم نشرها بعد في Firebase Console.

## الطريقة السريعة (من Firebase Console):

### 1. اذهب إلى Firebase Console:
- افتح: https://console.firebase.google.com/
- اختر مشروعك: **talendx-12808**

### 2. نشر Rules:
1. من القائمة الجانبية، اختر **Firestore Database**
2. افتح تبويب **Rules** (في الأعلى)
3. **انسخ** محتوى ملف `firestore.rules` من المشروع
4. **الصق** المحتوى في محرر Rules في Firebase Console
5. اضغط **Publish** (أو **نشر**) لحفظ التغييرات

### 3. التحقق:
- بعد النشر، انتظر بضع ثوانٍ
- جرّب تسجيل الدخول مرة أخرى

---

## الطريقة البديلة (باستخدام Firebase CLI):

إذا كان لديك Firebase CLI مثبت:

```bash
# 1. تأكد من تسجيل الدخول
firebase login

# 2. تأكد من أنك في المجلد الصحيح
cd E:\pro\taland

# 3. نشر Rules
firebase deploy --only firestore:rules
```

---

## ملاحظات:
- القواعد الجديدة تحتاج بضع ثوانٍ لتصبح فعالة
- تأكد من أن المستخدم مسجل دخول في Firebase Authentication قبل محاولة الوصول إلى Firestore
- إذا استمر الخطأ، تحقق من أن `request.auth.uid == userId` في القواعد




























