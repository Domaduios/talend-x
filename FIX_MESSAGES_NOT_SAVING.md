# إصلاح مشكلة عدم حفظ الرسائل في Firestore

## المشكلة
الرسائل لا تُحفظ في Firestore ولا تظهر في قائمة المحادثات.

## الحل

### 1. تأكد من نشر قواعد Firestore

**الخطوات:**

1. افتح Firebase Console:
   - https://console.firebase.google.com/
   - اختر مشروعك

2. اذهب إلى Firestore Database:
   - من القائمة الجانبية، اختر **Firestore Database**
   - اضغط على تبويب **Rules**

3. انسخ محتوى ملف `firestore.rules`:
   - افتح الملف `firestore.rules` في المشروع
   - انسخ كل المحتوى (Ctrl+A ثم Ctrl+C)

4. الصق القواعد في Firebase Console:
   - الصق المحتوى في حقل القواعد
   - اضغط **Publish** (نشر)

5. انتظر حتى تظهر رسالة "Rules published successfully"

### 2. تحقق من قواعد الرسائل

تأكد من أن القاعدة التالية موجودة في `firestore.rules`:

```javascript
// Messages collection
match /messages/{messageId} {
  // Users can read messages they sent or received
  allow read: if isAuthenticated() && (
    resource.data.senderId == request.auth.uid ||
    resource.data.receiverId == request.auth.uid
  );
  // Authenticated users can create messages
  allow create: if isAuthenticated() && request.resource.data.senderId == request.auth.uid;
  // Only sender can update their message
  allow update: if isAuthenticated() && resource.data.senderId == request.auth.uid;
  // Only sender can delete their message
  allow delete: if isAuthenticated() && resource.data.senderId == request.auth.uid;
}
```

### 3. تحقق من Console Logs

بعد إرسال رسالة، تحقق من Console Logs:

**إذا ظهرت هذه الرسائل:**
- `✅ Chat: Message sent successfully. ID: [id]`
- `✅ Chat: Message verified in Firestore`

**يعني أن الرسالة تم حفظها بنجاح.**

**إذا ظهرت هذه الرسائل:**
- `❌ Chat: Error sending message: [error]`
- `❌ Chat: PERMISSION DENIED - Firestore rules may not be published!`

**يعني أن هناك مشكلة في الصلاحيات.**

### 4. تحقق من Firestore Console

1. افتح Firebase Console
2. اذهب إلى **Firestore Database** → **Data**
3. ابحث عن collection اسمه `messages`
4. تحقق من وجود الرسائل

### 5. إذا لم تظهر الرسائل

**تحقق من:**
- ✅ هل تم نشر قواعد Firestore؟
- ✅ هل المستخدم مسجل دخول؟
- ✅ هل `senderId` يطابق `request.auth.uid`؟
- ✅ هل هناك أخطاء في Console Logs؟

### 6. اختبار سريع

1. شغّل التطبيق
2. افتح محادثة
3. أرسل رسالة
4. تحقق من Console Logs
5. تحقق من Firestore Console

---

## ملاحظات مهمة

- **يجب نشر قواعد Firestore بعد كل تعديل**
- **الرسائل تُحفظ في collection اسمه `messages`**
- **كل رسالة تحتوي على:**
  - `senderId`: معرف المرسل
  - `receiverId`: معرف المستقبل
  - `content`: محتوى الرسالة
  - `read`: حالة القراءة (true/false)
  - `createdAt`: وقت الإنشاء

---

## إذا استمرت المشكلة

1. أرسل رسالة خطأ من Console Logs
2. تحقق من أن قواعد Firestore منشورة
3. تأكد من أن المستخدم مسجل دخول























