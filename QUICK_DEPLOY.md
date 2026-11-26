# نشر سريع لقواعد Firestore

## ⚡ الطريقة الأسرع (يدوياً):

1. افتح: https://console.firebase.google.com/project/talendx-12808/firestore/rules
2. انسخ محتوى `firestore.rules`
3. الصق في Firebase Console
4. اضغط **Publish**

## 🤖 النشر التلقائي:

### إذا كان Node.js مثبت:

```bash
# تثبيت المكتبات
npm install google-auth-library

# نشر القواعد
node publish_rules_final.js
```

### إذا كان Firebase CLI مثبت:

```bash
firebase deploy --only firestore:rules
```

---

⏱️ **انتظر 10-30 ثانية بعد النشر**






















