const admin = require('firebase-admin');
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

// List of all collections to delete
const collections = [
  'users',
  'sessions',
  'messages',
  'notifications',
  'connections',
  'favorites',
  'reviews',
  'reports',
  'blockedUsers',
  'achievements',
  'payments',
  'transactions',
  'wallet',
  'referrals',
  'community',
  'resources',
  'activities',
  'leaderboard',
  'calendar',
  'learningProgress',
  'teachingDashboard'
];

// Function to delete all documents in a collection
async function deleteCollection(collectionName) {
  try {
    console.log(`\n🗑️  Deleting collection: ${collectionName}...`);
    const collectionRef = db.collection(collectionName);
    const snapshot = await collectionRef.get();
    
    if (snapshot.empty) {
      console.log(`   ✅ Collection ${collectionName} is already empty`);
      return;
    }

    const batchSize = 500;
    let deletedCount = 0;
    let batch = db.batch();
    let count = 0;

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      count++;
      deletedCount++;

      if (count === batchSize) {
        batch.commit();
        batch = db.batch();
        count = 0;
      }
    });

    if (count > 0) {
      await batch.commit();
    }

    console.log(`   ✅ Deleted ${deletedCount} documents from ${collectionName}`);
  } catch (error) {
    console.error(`   ❌ Error deleting collection ${collectionName}:`, error.message);
  }
}

// Function to delete all Firebase Auth users
async function deleteAllUsers() {
  try {
    console.log(`\n🗑️  Deleting all Firebase Auth users...`);
    let deletedCount = 0;
    let nextPageToken;

    do {
      const listUsersResult = await auth.listUsers(1000, nextPageToken);
      
      const deletePromises = listUsersResult.users.map(async (user) => {
        try {
          await auth.deleteUser(user.uid);
          deletedCount++;
          console.log(`   ✅ Deleted user: ${user.email || user.uid}`);
        } catch (error) {
          console.error(`   ❌ Error deleting user ${user.uid}:`, error.message);
        }
      });

      await Promise.all(deletePromises);
      nextPageToken = listUsersResult.pageToken;
    } while (nextPageToken);

    console.log(`\n   ✅ Total users deleted: ${deletedCount}`);
  } catch (error) {
    console.error(`   ❌ Error deleting users:`, error.message);
  }
}

// Function to get all collections dynamically
async function getAllCollections() {
  try {
    console.log(`\n📋 Discovering all collections...`);
    const collections = [];
    
    // Get all collections by trying to list them
    // Note: Firestore doesn't have a direct API to list all collections
    // So we'll use the predefined list and also try to discover others
    
    // Try to get any additional collections that might exist
    const knownCollections = new Set(collections);
    
    // For now, we'll use the predefined list
    // In production, you might want to maintain a list of all collections
    return collections;
  } catch (error) {
    console.error('Error discovering collections:', error.message);
    return collections;
  }
}

// Main function
async function deleteAllData() {
  console.log('🚀 Starting data deletion process...');
  console.log('⚠️  WARNING: This will delete ALL data from Firebase!');
  console.log('⚠️  This action cannot be undone!\n');

  try {
    // Delete all collections
    console.log('📦 Deleting Firestore collections...');
    for (const collectionName of collections) {
      await deleteCollection(collectionName);
    }

    // Delete all Firebase Auth users
    await deleteAllUsers();

    console.log('\n✅ Data deletion completed successfully!');
    console.log('🎉 All data and accounts have been deleted.');
    console.log('💡 You can now start fresh with your app.');
  } catch (error) {
    console.error('\n❌ Error during deletion process:', error);
  } finally {
    process.exit(0);
  }
}

// Run the script
deleteAllData();





















