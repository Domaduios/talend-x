const admin = require('firebase-admin');
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Function to delete all sessions
async function deleteAllSessions() {
  console.log('🚀 Starting to delete all sessions...\n');

  try {
    // Get all sessions
    const sessionsSnapshot = await db.collection('sessions').get();
    
    if (sessionsSnapshot.empty) {
      console.log('ℹ️  No sessions found in the database.');
      return;
    }

    console.log(`📊 Found ${sessionsSnapshot.docs.length} sessions to delete.\n`);

    // Delete in batches (Firestore batch limit is 500)
    const batchSize = 500;
    const docs = sessionsSnapshot.docs;
    let deletedCount = 0;

    for (let i = 0; i < docs.length; i += batchSize) {
      const batch = db.batch();
      const batchDocs = docs.slice(i, i + batchSize);
      
      batchDocs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      deletedCount += batchDocs.length;
      console.log(`   ✅ Deleted batch: ${deletedCount}/${docs.length} sessions`);
    }

    console.log(`\n✅ Successfully deleted all ${deletedCount} sessions!`);
  } catch (error) {
    console.error('❌ Error deleting sessions:', error.message);
    throw error;
  }
}

// Run the script
deleteAllSessions()
  .then(() => {
    console.log('\n🎉 Process completed successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Process failed:', error);
    process.exit(1);
  });













