# إعداد Firebase Firestore Collections

## الخطوات المطلوبة:

### 1. تثبيت Node.js و npm
تأكد من تثبيت Node.js على جهازك.

### 2. تثبيت Dependencies
```bash
npm install
```

### 3. تشغيل Script الإعداد
```bash
npm run setup
```

أو مباشرة:
```bash
node setup_firestore.js
```

### 4. نشر Firestore Rules و Indexes

#### باستخدام Firebase CLI:
```bash
# تثبيت Firebase CLI
npm install -g firebase-tools

# تسجيل الدخول
firebase login

# تهيئة المشروع
firebase init firestore

# نشر Rules
firebase deploy --only firestore:rules

# نشر Indexes
firebase deploy --only firestore:indexes
```

#### أو من Firebase Console:
1. اذهب إلى Firebase Console → Firestore Database
2. افتح تبويب "Rules" والصق محتوى `firestore.rules`
3. افتح تبويب "Indexes" واستورد `firestore.indexes.json`

## Collections المتاحة:

### 1. `users` - المستخدمين
```javascript
{
  email: string,
  name: string,
  faculty: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### 2. `talents` - المواهب/المشاريع
```javascript
{
  userId: string,
  title: string,
  description: string,
  category: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### 3. `applications` - الطلبات/التطبيقات
```javascript
{
  userId: string,
  talentId: string,
  talentOwnerId: string,
  status: string, // 'pending', 'accepted', 'rejected'
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### 4. `messages` - الرسائل
```javascript
{
  senderId: string,
  receiverId: string,
  content: string,
  read: boolean,
  createdAt: timestamp
}
```

### 5. `notifications` - الإشعارات
```javascript
{
  userId: string,
  title: string,
  body: string,
  read: boolean,
  type: string,
  createdAt: timestamp
}
```

### 6. `faculties` - الكليات
```javascript
{
  name: string,
  icon: string,
  order: number,
  createdAt: timestamp
}
```

## Security Rules

تم إعداد Security Rules في `firestore.rules` لحماية البيانات:
- المستخدمون يمكنهم قراءة/تعديل بياناتهم فقط
- المواهب يمكن للجميع قراءتها، لكن فقط المالك يمكنه التعديل
- الطلبات محمية بحيث يمكن للمتقدم ومالك الموهبة فقط الوصول إليها
- الرسائل والإشعارات محمية بحيث يمكن للمستخدمين الوصول إلى رسائلهم فقط

## ملاحظات مهمة:

1. **ملف Service Account**: تأكد من أن ملف `talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json` موجود في المجلد الرئيسي
2. **Security**: لا ترفع ملف service account إلى Git! أضفه إلى `.gitignore`
3. **Indexes**: بعض الاستعلامات المعقدة قد تحتاج إلى indexes إضافية

































