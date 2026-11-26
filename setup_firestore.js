const admin = require('firebase-admin');
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'talendx-12808',
});

const db = admin.firestore();

async function setupCollections() {
  try {
    console.log('🚀 بدء إعداد Firebase Collections...\n');

    // 1. إنشاء collection للمستخدمين (users)
    console.log('📝 إنشاء collection: users');
    const usersRef = db.collection('users');
    
    // إنشاء document مثال (يمكن حذفه لاحقاً)
    const exampleUser = {
      email: 'example@example.com',
      name: 'Example User',
      faculty: 'Computer Science',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // التحقق من وجود collection
    const usersSnapshot = await usersRef.limit(1).get();
    if (usersSnapshot.empty) {
      console.log('   ✓ Collection "users" جاهز');
    } else {
      console.log('   ✓ Collection "users" موجود بالفعل');
    }

    // 2. إنشاء collection للمواهب/المشاريع (talents)
    console.log('📝 إنشاء collection: talents');
    const talentsRef = db.collection('talents');
    const talentsSnapshot = await talentsRef.limit(1).get();
    if (talentsSnapshot.empty) {
      console.log('   ✓ Collection "talents" جاهز');
    } else {
      console.log('   ✓ Collection "talents" موجود بالفعل');
    }

    // 3. إنشاء collection للطلبات/التطبيقات (applications)
    console.log('📝 إنشاء collection: applications');
    const applicationsRef = db.collection('applications');
    const applicationsSnapshot = await applicationsRef.limit(1).get();
    if (applicationsSnapshot.empty) {
      console.log('   ✓ Collection "applications" جاهز');
    } else {
      console.log('   ✓ Collection "applications" موجود بالفعل');
    }

    // 4. إنشاء collection للرسائل (messages)
    console.log('📝 إنشاء collection: messages');
    const messagesRef = db.collection('messages');
    const messagesSnapshot = await messagesRef.limit(1).get();
    if (messagesSnapshot.empty) {
      console.log('   ✓ Collection "messages" جاهز');
    } else {
      console.log('   ✓ Collection "messages" موجود بالفعل');
    }

    // 5. إنشاء collection للإشعارات (notifications)
    console.log('📝 إنشاء collection: notifications');
    const notificationsRef = db.collection('notifications');
    const notificationsSnapshot = await notificationsRef.limit(1).get();
    if (notificationsSnapshot.empty) {
      console.log('   ✓ Collection "notifications" جاهز');
    } else {
      console.log('   ✓ Collection "notifications" موجود بالفعل');
    }

    // 6. إنشاء collection للكليات (faculties)
    console.log('📝 إنشاء collection: faculties');
    const facultiesRef = db.collection('faculties');
    const facultiesSnapshot = await facultiesRef.limit(1).get();
    
    // إضافة بيانات الكليات
    const facultiesData = [
      { name: 'Computer Science', icon: 'computer', order: 1 },
      { name: 'Nursing', icon: 'healing', order: 2 },
      { name: 'Physical Therapy', icon: 'fitness_center', order: 3 },
      { name: 'Fine Arts', icon: 'palette', order: 4 },
      { name: 'Commerce', icon: 'business', order: 5 },
      { name: 'Engineering', icon: 'engineering', order: 6 },
    ];

    if (facultiesSnapshot.empty) {
      console.log('   ✓ إضافة بيانات الكليات...');
      const batch = db.batch();
      facultiesData.forEach((faculty) => {
        const docRef = facultiesRef.doc();
        batch.set(docRef, {
          ...faculty,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
      console.log('   ✓ تم إضافة بيانات الكليات');
    } else {
      console.log('   ✓ Collection "faculties" موجود بالفعل');
    }

    // 7. إنشاء indexes للمجموعات
    console.log('\n📊 إنشاء Firestore Indexes...');
    console.log('   ℹ️  سيتم إنشاء indexes من خلال Firebase Console');
    console.log('   ℹ️  أو استخدام Firebase CLI: firebase deploy --only firestore:indexes');

    console.log('\n✅ تم إعداد Firebase Collections بنجاح!\n');
    
    // عرض ملخص
    console.log('📋 Collections المتاحة:');
    console.log('   - users (المستخدمين)');
    console.log('   - talents (المواهب/المشاريع)');
    console.log('   - applications (الطلبات/التطبيقات)');
    console.log('   - messages (الرسائل)');
    console.log('   - notifications (الإشعارات)');
    console.log('   - faculties (الكليات)');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ خطأ في إعداد Collections:', error);
    process.exit(1);
  }
}

// تشغيل الإعداد
setupCollections();

































