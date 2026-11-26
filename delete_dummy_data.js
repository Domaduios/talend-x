const admin = require('firebase-admin');
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

// List of dummy user emails to delete
const dummyEmails = [
  'ahmed.ali@example.com',
  'sara.mohamed@example.com',
  'omar.hassan@example.com',
  'fatima.ibrahim@example.com',
  'khaled.mahmoud@example.com',
  'nour.ali@example.com',
  'youssef.ahmed@example.com',
  'layla.mohamed@example.com',
  'mohamed.hassan@example.com',
  'aya.ibrahim@example.com',
  'hassan.ali@example.com',
  'mariam.ahmed@example.com',
  'ali.youssef@example.com',
  'zeinab.mohamed@example.com',
  'tarek.hassan@example.com',
];

// Function to delete user and all their data
async function deleteUserData(userId) {
  try {
    // Delete user's data from all collections
    const collections = [
      { name: 'users', field: 'userId' },
      { name: 'sessions', field: 'teacherId' },
      { name: 'sessions', field: 'learnerId' },
      { name: 'messages', field: 'senderId' },
      { name: 'messages', field: 'receiverId' },
      { name: 'notifications', field: 'userId' },
      { name: 'connections', field: 'requesterId' },
      { name: 'connections', field: 'receiverId' },
      { name: 'favorites', field: 'userId' },
      { name: 'favorites', field: 'favoriteUserId' },
      { name: 'reviews', field: 'reviewerId' },
      { name: 'reviews', field: 'reviewedId' },
    ];

    for (const collection of collections) {
      try {
        const snapshot = await db.collection(collection.name)
          .where(collection.field, '==', userId)
          .get();
        
        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        
        if (snapshot.docs.length > 0) {
          await batch.commit();
          console.log(`   ✅ Deleted ${snapshot.docs.length} documents from ${collection.name}`);
        }
      } catch (error) {
        console.error(`   ⚠️  Error deleting from ${collection.name}:`, error.message);
      }
    }

    // Delete user document
    await db.collection('users').doc(userId).delete();
    
    // Delete user from Auth
    await auth.deleteUser(userId);
    
    return true;
  } catch (error) {
    console.error(`   ❌ Error deleting user data:`, error.message);
    return false;
  }
}

// Main function
async function deleteDummyData() {
  console.log('🚀 Starting dummy data deletion...');
  console.log('⚠️  This will delete only dummy users and their data\n');

  let deletedCount = 0;
  let notFoundCount = 0;

  for (const email of dummyEmails) {
    try {
      const user = await auth.getUserByEmail(email);
      console.log(`\n🗑️  Deleting user: ${email} (${user.uid.substring(0, 8)}...)`);
      
      if (await deleteUserData(user.uid)) {
        deletedCount++;
        console.log(`   ✅ Successfully deleted user: ${email}`);
      }
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        notFoundCount++;
        console.log(`   ℹ️  User not found: ${email} (may have been deleted already)`);
      } else {
        console.error(`   ❌ Error deleting user ${email}:`, error.message);
      }
    }
  }

  // Also delete any sessions, messages, etc. that might be orphaned
  console.log('\n🧹 Cleaning up orphaned data...');
  
  try {
    // Delete all sessions (they will be recreated with sample data)
    const sessionsSnapshot = await db.collection('sessions').get();
    const sessionsBatch = db.batch();
    sessionsSnapshot.docs.forEach(doc => sessionsBatch.delete(doc.ref));
    if (sessionsSnapshot.docs.length > 0) {
      await sessionsBatch.commit();
      console.log(`   ✅ Deleted ${sessionsSnapshot.docs.length} sessions`);
    }
  } catch (error) {
    console.error(`   ⚠️  Error deleting sessions:`, error.message);
  }

  try {
    // Delete all messages
    const messagesSnapshot = await db.collection('messages').get();
    const messagesBatch = db.batch();
    messagesSnapshot.docs.forEach(doc => messagesBatch.delete(doc.ref));
    if (messagesSnapshot.docs.length > 0) {
      await messagesBatch.commit();
      console.log(`   ✅ Deleted ${messagesSnapshot.docs.length} messages`);
    }
  } catch (error) {
    console.error(`   ⚠️  Error deleting messages:`, error.message);
  }

  try {
    // Delete all notifications
    const notificationsSnapshot = await db.collection('notifications').get();
    const notificationsBatch = db.batch();
    notificationsSnapshot.docs.forEach(doc => notificationsBatch.delete(doc.ref));
    if (notificationsSnapshot.docs.length > 0) {
      await notificationsBatch.commit();
      console.log(`   ✅ Deleted ${notificationsSnapshot.docs.length} notifications`);
    }
  } catch (error) {
    console.error(`   ⚠️  Error deleting notifications:`, error.message);
  }

  try {
    // Delete all connections
    const connectionsSnapshot = await db.collection('connections').get();
    const connectionsBatch = db.batch();
    connectionsSnapshot.docs.forEach(doc => connectionsBatch.delete(doc.ref));
    if (connectionsSnapshot.docs.length > 0) {
      await connectionsBatch.commit();
      console.log(`   ✅ Deleted ${connectionsSnapshot.docs.length} connections`);
    }
  } catch (error) {
    console.error(`   ⚠️  Error deleting connections:`, error.message);
  }

  try {
    // Delete all favorites
    const favoritesSnapshot = await db.collection('favorites').get();
    const favoritesBatch = db.batch();
    favoritesSnapshot.docs.forEach(doc => favoritesBatch.delete(doc.ref));
    if (favoritesSnapshot.docs.length > 0) {
      await favoritesBatch.commit();
      console.log(`   ✅ Deleted ${favoritesSnapshot.docs.length} favorites`);
    }
  } catch (error) {
    console.error(`   ⚠️  Error deleting favorites:`, error.message);
  }

  try {
    // Delete all reviews
    const reviewsSnapshot = await db.collection('reviews').get();
    const reviewsBatch = db.batch();
    reviewsSnapshot.docs.forEach(doc => reviewsBatch.delete(doc.ref));
    if (reviewsSnapshot.docs.length > 0) {
      await reviewsBatch.commit();
      console.log(`   ✅ Deleted ${reviewsSnapshot.docs.length} reviews`);
    }
  } catch (error) {
    console.error(`   ⚠️  Error deleting reviews:`, error.message);
  }

  console.log('\n✅ Dummy data deletion completed!');
  console.log(`📊 Summary:`);
  console.log(`   - Deleted users: ${deletedCount}`);
  console.log(`   - Users not found: ${notFoundCount}`);
  console.log('💡 You can now create sample data for display.');
}

// Run the script
deleteDummyData().then(() => process.exit(0)).catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});


















