# 🚨 مهم جداً: نشر Firestore Rules الآن

## المشكلة:
```
PERMISSION_DENIED: Missing or insufficient permissions
```

**السبب**: القواعد موجودة في ملف `firestore.rules` لكنها **لم يتم نشرها** في Firebase Console.

---

## ✅ الحل (5 دقائق):

### الخطوة 1: افتح Firebase Console
1. اذهب إلى: **https://console.firebase.google.com/**
2. سجل الدخول بحساب Google الخاص بك
3. اختر المشروع: **talendx-12808**

### الخطوة 2: افتح Firestore Rules
1. من القائمة الجانبية (اليسار)، اضغط على **Firestore Database**
2. في الأعلى، اضغط على تبويب **Rules** (بجانب Data, Indexes, Usage)

### الخطوة 3: انسخ القواعد
1. افتح ملف `firestore.rules` من المشروع
2. **انسخ كل المحتوى** (Ctrl+A ثم Ctrl+C)

### الخطوة 4: الصق القواعد
1. في Firebase Console، في محرر Rules
2. **احذف كل المحتوى القديم** (Ctrl+A ثم Delete)
3. **الصق** القواعد الجديدة (Ctrl+V)

### الخطوة 5: انشر القواعد
1. اضغط على زر **Publish** (أو **نشر**) في الأسفل
2. انتظر حتى تظهر رسالة "Rules published successfully"

---

## 📋 القواعد المطلوبة (انسخها من ملف firestore.rules):

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      // Users can read their own data
      allow read: if isAuthenticated() && request.auth.uid == userId;
      // Users can create their own document (when signing up)
      allow create: if isAuthenticated() && request.auth.uid == userId;
      // Users can update their own data
      allow update: if isAuthenticated() && request.auth.uid == userId;
      // Users cannot delete their own account (admin only)
      allow delete: if false;
    }
    
    // Talents collection
    match /talents/{talentId} {
      // Anyone can read talents
      allow read: if true;
      // Only authenticated users can create talents
      allow create: if isAuthenticated();
      // Only the owner can update their talent
      allow update: if isAuthenticated() && resource.data.userId == request.auth.uid;
      // Only the owner can delete their talent
      allow delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
    
    // Applications collection
    match /applications/{applicationId} {
      // Users can read their own applications
      allow read: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        resource.data.talentOwnerId == request.auth.uid
      );
      // Authenticated users can create applications
      allow create: if isAuthenticated();
      // Only the applicant or talent owner can update
      allow update: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        resource.data.talentOwnerId == request.auth.uid
      );
      // Only the applicant can delete their application
      allow delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
    
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
    
    // Notifications collection
    match /notifications/{notificationId} {
      // Users can only read their own notifications
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      // System can create notifications (using service account)
      allow create: if true;
      // Users can update their own notifications (e.g., mark as read)
      allow update: if isAuthenticated() && resource.data.userId == request.auth.uid;
      // Users can delete their own notifications
      allow delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
    
    // Faculties collection (read-only for users)
    match /faculties/{facultyId} {
      // Anyone can read faculties
      allow read: if true;
      // Only admins can modify (using service account)
      allow write: if false;
    }
  }
}
```

---

## ⏱️ بعد النشر:

1. **انتظر 10-30 ثانية** حتى تصبح القواعد فعالة
2. **أعد تشغيل التطبيق** (Hot Restart - اضغط R في Terminal)
3. **جرّب تسجيل الدخول بـ Google مرة أخرى**

---

## ✅ التحقق من النجاح:

بعد النشر، يجب أن ترى:
- ✅ رسالة "Rules published successfully" في Firebase Console
- ✅ لا توجد أخطاء `PERMISSION_DENIED` في التطبيق
- ✅ تسجيل الدخول يعمل بنجاح

---

## 🔍 إذا استمر الخطأ:

### تحقق من:
1. ✅ أن القواعد تم نشرها بنجاح (تحقق من رسالة النجاح)
2. ✅ أن المستخدم مسجل دخول في Firebase Authentication
3. ✅ أن `userId` في Firestore يطابق `request.auth.uid`

### للتحقق من المستخدم:
- في Firebase Console → Authentication → Users
- تأكد من وجود المستخدم بعد تسجيل الدخول

---

## 📝 ملاحظة أمنية:

القواعد الحالية تسمح للمستخدمين بالوصول **فقط** إلى بياناتهم الخاصة. هذا آمن ومطلوب لعمل التطبيق.

**المشكلة الأساسية**: القواعد موجودة في المشروع لكنها **لم يتم نشرها** في Firebase Console. يجب نشرها يدوياً.


























