const admin = require('firebase-admin');
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

// Sample data - فقط للعرض
const sampleUsers = [
  {
    name: 'أحمد محمد',
    email: 'ahmed.sample@taland.com',
    faculty: 'Computer Science',
    teachSkills: ['Programming', 'Web Development'],
    learnSkills: ['AI/ML', 'Data Science'],
    bio: 'مطور تطبيقات متحمس للتعلم والتعليم',
  },
  {
    name: 'سارة علي',
    email: 'sara.sample@taland.com',
    faculty: 'Engineering',
    teachSkills: ['UI/UX Design', 'Graphic Design'],
    learnSkills: ['Mobile Apps', 'Web Development'],
    bio: 'مصممة واجهات مستخدم، أحب مشاركة المعرفة',
  },
];

// Helper function to get random date in future
function getFutureDate(daysFromNow = 7) {
  const now = new Date();
  const future = new Date(now.getTime() + daysFromNow * 24 * 60 * 60 * 1000);
  return admin.firestore.Timestamp.fromDate(future);
}

// Helper function to get random date in past
function getPastDate(daysAgo = 7) {
  const now = new Date();
  const past = new Date(now.getTime() - daysAgo * 24 * 60 * 60 * 1000);
  return admin.firestore.Timestamp.fromDate(past);
}

// Create sample users
async function createSampleUsers() {
  console.log('\n👥 Creating sample users...');
  const userIds = [];
  
  for (const userData of sampleUsers) {
    try {
      // Check if user exists
      let user;
      try {
        user = await auth.getUserByEmail(userData.email);
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          // Create user in Auth
          user = await auth.createUser({
            email: userData.email,
            displayName: userData.name,
            emailVerified: true,
            disabled: false,
          });
        } else {
          throw error;
        }
      }
      
      // Create/Update user document in Firestore
      await db.collection('users').doc(user.uid).set({
        email: userData.email,
        name: userData.name,
        faculty: userData.faculty,
        bio: userData.bio,
        teachSkills: userData.teachSkills,
        learnSkills: userData.learnSkills,
        availability: 'Flexible',
        preference: 'Flexible',
        profileCompleted: true,
        isAdmin: false,
        role: 'user',
        emailVerified: true,
        createdAt: getPastDate(30),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      
      userIds.push(user.uid);
      console.log(`   ✅ Created user: ${userData.name}`);
    } catch (error) {
      console.error(`   ❌ Error creating user ${userData.name}:`, error.message);
    }
  }
  
  console.log(`\n✅ Created ${userIds.length} sample users`);
  return userIds;
}

// Create sample session (only if we have 2 users)
async function createSampleSession(userIds) {
  if (userIds.length < 2) {
    console.log('\n⚠️  Need at least 2 users to create a session');
    return;
  }

  console.log('\n📅 Creating sample session...');
  
  try {
    const teacherId = userIds[0];
    const learnerId = userIds[1];
    
    // Get user names
    const teacherDoc = await db.collection('users').doc(teacherId).get();
    const learnerDoc = await db.collection('users').doc(learnerId).get();
    const teacherName = teacherDoc.exists ? teacherDoc.data().name : 'Unknown';
    const learnerName = learnerDoc.exists ? learnerDoc.data().name : 'Unknown';
    
    const sessionData = {
      title: 'جلسة تعليمية - برمجة الويب',
      type: 'learning',
      teacherId: teacherId,
      teacherName: teacherName,
      learnerId: learnerId,
      learnerName: learnerName,
      creatorId: learnerId,
      partnerId: teacherId,
      partnerName: teacherName,
      scheduledAt: getFutureDate(3),
      date: getFutureDate(3),
      time: getFutureDate(3),
      duration: 60,
      location: 'Online',
      meetingLink: 'https://meet.google.com/sample-session',
      notes: 'جلسة تعليمية حول أساسيات برمجة الويب',
      skills: ['Web Development', 'Programming'],
      status: 'confirmed',
      createdAt: getPastDate(2),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    const sessionRef = await db.collection('sessions').add(sessionData);
    console.log(`   ✅ Created sample session: ${sessionData.title}`);
  } catch (error) {
    console.error(`   ❌ Error creating session:`, error.message);
  }
}

// Create sample message
async function createSampleMessage(userIds) {
  if (userIds.length < 2) {
    return;
  }

  console.log('\n💬 Creating sample message...');
  
  try {
    await db.collection('messages').add({
      senderId: userIds[0],
      receiverId: userIds[1],
      content: 'مرحباً! هل يمكننا تحديد موعد للجلسة؟',
      read: false,
      createdAt: getPastDate(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`   ✅ Created sample message`);
  } catch (error) {
    console.error(`   ❌ Error creating message:`, error.message);
  }
}

// Create sample connection
async function createSampleConnection(userIds) {
  if (userIds.length < 2) {
    return;
  }

  console.log('\n🤝 Creating sample connection...');
  
  try {
    await db.collection('connections').add({
      userId: userIds[0],
      connectedUserId: userIds[1],
      requesterId: userIds[0],
      receiverId: userIds[1],
      status: 'accepted',
      createdAt: getPastDate(5),
      acceptedAt: getPastDate(4),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`   ✅ Created sample connection`);
  } catch (error) {
    console.error(`   ❌ Error creating connection:`, error.message);
  }
}

// Main function
async function createSampleData() {
  console.log('🚀 Creating sample data for display...');
  console.log('💡 This will create only 2 sample users with minimal data\n');
  
  try {
    // Create users first
    const userIds = await createSampleUsers();
    
    if (userIds.length < 2) {
      console.log('❌ Need at least 2 users. Exiting...');
      process.exit(1);
    }
    
    // Create minimal sample data
    await createSampleSession(userIds);
    await createSampleMessage(userIds);
    await createSampleConnection(userIds);
    
    console.log('\n🎉 Sample data creation completed!');
    console.log('💡 You now have 2 sample users with minimal data for display.');
  } catch (error) {
    console.error('\n❌ Error during data creation:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Run the script
createSampleData();


















