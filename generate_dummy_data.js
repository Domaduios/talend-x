const admin = require('firebase-admin');
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

// Dummy data arrays
const faculties = [
  'Computer Science',
  'Engineering',
  'Business Administration',
  'Medicine',
  'Arts & Design',
  'Law',
  'Education',
  'Science',
  'Pharmacy',
  'Architecture'
];

const skills = [
  'Programming',
  'Web Development',
  'Mobile Apps',
  'AI/ML',
  'Data Science',
  'UI/UX Design',
  'Graphic Design',
  'Photography',
  'Video Editing',
  'Marketing',
  'Business Strategy',
  'Public Speaking'
];

const names = [
  { name: 'Ahmed Ali', email: 'ahmed.ali@example.com' },
  { name: 'Sara Mohamed', email: 'sara.mohamed@example.com' },
  { name: 'Omar Hassan', email: 'omar.hassan@example.com' },
  { name: 'Fatima Ibrahim', email: 'fatima.ibrahim@example.com' },
  { name: 'Khaled Mahmoud', email: 'khaled.mahmoud@example.com' },
  { name: 'Nour Ali', email: 'nour.ali@example.com' },
  { name: 'Youssef Ahmed', email: 'youssef.ahmed@example.com' },
  { name: 'Layla Mohamed', email: 'layla.mohamed@example.com' },
  { name: 'Mohamed Hassan', email: 'mohamed.hassan@example.com' },
  { name: 'Aya Ibrahim', email: 'aya.ibrahim@example.com' },
  { name: 'Hassan Ali', email: 'hassan.ali@example.com' },
  { name: 'Mariam Ahmed', email: 'mariam.ahmed@example.com' },
  { name: 'Ali Youssef', email: 'ali.youssef@example.com' },
  { name: 'Zeinab Mohamed', email: 'zeinab.mohamed@example.com' },
  { name: 'Tarek Hassan', email: 'tarek.hassan@example.com' },
];

const bios = [
  'Passionate about technology and always eager to learn new things.',
  'Love sharing knowledge and helping others grow.',
  'Experienced professional looking to mentor and be mentored.',
  'Student passionate about continuous learning and development.',
  'Tech enthusiast with years of experience in software development.',
  'Creative designer with a passion for UI/UX and digital art.',
  'Business strategist helping startups grow and scale.',
  'Data scientist exploring the world of AI and machine learning.',
  'Full-stack developer building amazing web applications.',
  'Marketing expert specializing in digital marketing strategies.',
];

const locations = ['Online', 'Library', 'Cafe', 'Campus'];
const sessionTitles = [
  'Introduction to Python Programming',
  'Web Development Fundamentals',
  'UI/UX Design Principles',
  'Data Science Basics',
  'Mobile App Development',
  'Machine Learning Introduction',
  'Graphic Design Workshop',
  'Marketing Strategies',
  'Business Planning',
  'Public Speaking Tips',
];

// Helper function to get random item from array
function getRandomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

// Helper function to get random items from array
function getRandomItems(array, count) {
  const shuffled = [...array].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, Math.min(count, array.length));
}

// Helper function to get random date in future
function getRandomFutureDate(daysFromNow = 30) {
  const now = new Date();
  const future = new Date(now.getTime() + Math.random() * daysFromNow * 24 * 60 * 60 * 1000);
  return admin.firestore.Timestamp.fromDate(future);
}

// Helper function to get random date in past
function getRandomPastDate(daysAgo = 30) {
  const now = new Date();
  const past = new Date(now.getTime() - Math.random() * daysAgo * 24 * 60 * 60 * 1000);
  return admin.firestore.Timestamp.fromDate(past);
}

// Create dummy users
async function createDummyUsers() {
  console.log('\n👥 Creating dummy users...');
  const userIds = [];
  
  for (let i = 0; i < names.length; i++) {
    const userData = names[i];
    const faculty = getRandomItem(faculties);
    const teachSkills = getRandomItems(skills, Math.floor(Math.random() * 4) + 2);
    const learnSkills = getRandomItems(skills.filter(s => !teachSkills.includes(s)), Math.floor(Math.random() * 3) + 1);
    const bio = getRandomItem(bios);
    const availability = getRandomItem(['Flexible', 'Weekdays', 'Weekends', 'Evenings']);
    const preference = getRandomItem(['Flexible', 'Online', 'In-Person']);
    
    try {
      // Check if user exists in Auth
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
        faculty: faculty,
        bio: bio,
        teachSkills: teachSkills,
        learnSkills: learnSkills,
        availability: availability,
        preference: preference,
        profileCompleted: true,
        isAdmin: false,
        role: 'user',
        emailVerified: true,
        createdAt: getRandomPastDate(60),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      
      userIds.push(user.uid);
      console.log(`   ✅ Created user: ${userData.name} (${user.uid.substring(0, 8)}...)`);
    } catch (error) {
      console.error(`   ❌ Error creating user ${userData.name}:`, error.message);
    }
  }
  
  console.log(`\n✅ Created ${userIds.length} users`);
  return userIds;
}

// Create dummy sessions
async function createDummySessions(userIds) {
  console.log('\n📅 Creating dummy sessions...');
  const sessionIds = [];
  const statuses = ['pending', 'confirmed', 'completed'];
  
  for (let i = 0; i < 30; i++) {
    const teacherId = getRandomItem(userIds);
    let learnerId = getRandomItem(userIds);
    // Make sure teacher and learner are different
    while (learnerId === teacherId) {
      learnerId = getRandomItem(userIds);
    }
    
    const status = getRandomItem(statuses);
    const title = getRandomItem(sessionTitles);
    const location = getRandomItem(locations);
    const duration = getRandomItem([30, 60, 90, 120]);
    const sessionSkills = getRandomItems(skills, Math.floor(Math.random() * 3) + 1);
    
    // Get partner name
    const teacherDoc = await db.collection('users').doc(teacherId).get();
    const learnerDoc = await db.collection('users').doc(learnerId).get();
    const teacherName = teacherDoc.exists ? teacherDoc.data().name : 'Unknown';
    const learnerName = learnerDoc.exists ? learnerDoc.data().name : 'Unknown';
    
    const scheduledAt = status === 'completed' 
      ? getRandomPastDate(30) 
      : getRandomFutureDate(30);
    
    const sessionData = {
      title: title,
      type: Math.random() > 0.5 ? 'learning' : 'teaching',
      teacherId: teacherId,
      teacherName: teacherName,
      learnerId: learnerId,
      learnerName: learnerName,
      creatorId: Math.random() > 0.5 ? teacherId : learnerId,
      partnerId: Math.random() > 0.5 ? learnerId : teacherId,
      partnerName: Math.random() > 0.5 ? learnerName : teacherName,
      scheduledAt: scheduledAt,
      date: scheduledAt,
      time: scheduledAt,
      duration: duration,
      location: location,
      meetingLink: location === 'Online' ? `https://meet.google.com/${Math.random().toString(36).substring(7)}` : null,
      notes: Math.random() > 0.5 ? 'Looking forward to this session!' : null,
      skills: sessionSkills,
      status: status,
      createdAt: status === 'completed' ? getRandomPastDate(60) : getRandomPastDate(30),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    if (status === 'completed') {
      sessionData.completedAt = getRandomPastDate(20);
    }
    
    try {
      const sessionRef = await db.collection('sessions').add(sessionData);
      sessionIds.push(sessionRef.id);
      console.log(`   ✅ Created session: ${title} (${status})`);
    } catch (error) {
      console.error(`   ❌ Error creating session:`, error.message);
    }
  }
  
  console.log(`\n✅ Created ${sessionIds.length} sessions`);
  return sessionIds;
}

// Create dummy messages
async function createDummyMessages(userIds) {
  console.log('\n💬 Creating dummy messages...');
  let messageCount = 0;
  
  // Create conversations between random pairs
  const conversations = [];
  for (let i = 0; i < 20; i++) {
    const user1 = getRandomItem(userIds);
    let user2 = getRandomItem(userIds);
    while (user2 === user1) {
      user2 = getRandomItem(userIds);
    }
    conversations.push([user1, user2]);
  }
  
  const messageTemplates = [
    'Hello! How are you?',
    'I\'m interested in learning more about this.',
    'That sounds great!',
    'Can we schedule a session?',
    'I\'m available this week.',
    'Thank you for your help!',
    'Looking forward to our session.',
    'See you soon!',
    'That\'s very helpful.',
    'I have a question about...',
  ];
  
  for (const [user1, user2] of conversations) {
    const messageCountInConversation = Math.floor(Math.random() * 5) + 3;
    let lastTimestamp = getRandomPastDate(10);
    
    for (let i = 0; i < messageCountInConversation; i++) {
      const senderId = i % 2 === 0 ? user1 : user2;
      const receiverId = i % 2 === 0 ? user2 : user1;
      const content = getRandomItem(messageTemplates);
      
      // Increment timestamp by random minutes
      const minutesAgo = Math.random() * 60 * 24 * 10; // Within last 10 days
      const messageTime = new Date(Date.now() - minutesAgo * 60 * 1000);
      
      try {
        await db.collection('messages').add({
          senderId: senderId,
          receiverId: receiverId,
          content: content,
          read: Math.random() > 0.3,
          createdAt: admin.firestore.Timestamp.fromDate(messageTime),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        messageCount++;
      } catch (error) {
        console.error(`   ❌ Error creating message:`, error.message);
      }
    }
  }
  
  console.log(`\n✅ Created ${messageCount} messages`);
}

// Create dummy notifications
async function createDummyNotifications(userIds) {
  console.log('\n🔔 Creating dummy notifications...');
  let notificationCount = 0;
  
  const notificationTypes = [
    { type: 'session_request', title: 'New Session Request', body: 'You have a new session request' },
    { type: 'session_confirmed', title: 'Session Confirmed', body: 'Your session has been confirmed' },
    { type: 'message', title: 'New Message', body: 'You have a new message' },
    { type: 'connection', title: 'New Connection', body: 'Someone wants to connect with you' },
  ];
  
  for (const userId of userIds) {
    const notificationCountForUser = Math.floor(Math.random() * 5) + 2;
    
    for (let i = 0; i < notificationCountForUser; i++) {
      const notification = getRandomItem(notificationTypes);
      const minutesAgo = Math.random() * 60 * 24 * 7; // Within last 7 days
      const notificationTime = new Date(Date.now() - minutesAgo * 60 * 1000);
      
      try {
        await db.collection('notifications').add({
          userId: userId,
          type: notification.type,
          title: notification.title,
          body: notification.body,
          read: Math.random() > 0.4,
          createdAt: admin.firestore.Timestamp.fromDate(notificationTime),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        notificationCount++;
      } catch (error) {
        console.error(`   ❌ Error creating notification:`, error.message);
      }
    }
  }
  
  console.log(`\n✅ Created ${notificationCount} notifications`);
}

// Create dummy connections
async function createDummyConnections(userIds) {
  console.log('\n🤝 Creating dummy connections...');
  let connectionCount = 0;
  
  const statuses = ['pending', 'accepted', 'rejected'];
  
  for (let i = 0; i < 25; i++) {
    const user1 = getRandomItem(userIds);
    let user2 = getRandomItem(userIds);
    while (user2 === user1) {
      user2 = getRandomItem(userIds);
    }
    
    const status = getRandomItem(statuses);
    
    try {
      await db.collection('connections').add({
        requesterId: user1,
        receiverId: user2,
        status: status,
        createdAt: getRandomPastDate(20),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      connectionCount++;
    } catch (error) {
      console.error(`   ❌ Error creating connection:`, error.message);
    }
  }
  
  console.log(`\n✅ Created ${connectionCount} connections`);
}

// Create dummy favorites
async function createDummyFavorites(userIds) {
  console.log('\n⭐ Creating dummy favorites...');
  let favoriteCount = 0;
  
  for (const userId of userIds) {
    const favoriteCountForUser = Math.floor(Math.random() * 5) + 1;
    const otherUsers = userIds.filter(id => id !== userId);
    const favorites = getRandomItems(otherUsers, favoriteCountForUser);
    
    for (const favoriteId of favorites) {
      try {
        await db.collection('favorites').add({
          userId: userId,
          favoriteUserId: favoriteId,
          createdAt: getRandomPastDate(15),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        favoriteCount++;
      } catch (error) {
        console.error(`   ❌ Error creating favorite:`, error.message);
      }
    }
  }
  
  console.log(`\n✅ Created ${favoriteCount} favorites`);
}

// Create dummy reviews
async function createDummyReviews(userIds) {
  console.log('\n⭐ Creating dummy reviews...');
  let reviewCount = 0;
  
  // Get completed sessions
  const sessionsSnapshot = await db.collection('sessions')
    .where('status', '==', 'completed')
    .limit(20)
    .get();
  
  for (const sessionDoc of sessionsSnapshot.docs) {
    const sessionData = sessionDoc.data();
    const teacherId = sessionData.teacherId;
    const learnerId = sessionData.learnerId;
    
    if (!teacherId || !learnerId) continue;
    
    // Create review from learner to teacher
    if (Math.random() > 0.3) {
      try {
        await db.collection('reviews').add({
          sessionId: sessionDoc.id,
          reviewerId: learnerId,
          reviewedId: teacherId,
          rating: Math.floor(Math.random() * 2) + 4, // 4 or 5
          comment: getRandomItem([
            'Great session! Very helpful.',
            'Excellent teacher, learned a lot.',
            'Very knowledgeable and patient.',
            'Amazing experience!',
            'Highly recommended!',
          ]),
          createdAt: getRandomPastDate(15),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        reviewCount++;
      } catch (error) {
        console.error(`   ❌ Error creating review:`, error.message);
      }
    }
  }
  
  console.log(`\n✅ Created ${reviewCount} reviews`);
}

// Main function
async function generateDummyData() {
  console.log('🚀 Starting dummy data generation...');
  console.log('⚠️  This will create users, sessions, messages, and more!\n');
  
  try {
    // Create users first
    const userIds = await createDummyUsers();
    
    if (userIds.length === 0) {
      console.log('❌ No users created. Exiting...');
      process.exit(1);
    }
    
    // Create other data
    await createDummySessions(userIds);
    await createDummyMessages(userIds);
    await createDummyNotifications(userIds);
    await createDummyConnections(userIds);
    await createDummyFavorites(userIds);
    await createDummyReviews(userIds);
    
    console.log('\n🎉 Dummy data generation completed successfully!');
    console.log('💡 You can now view the data in your app.');
  } catch (error) {
    console.error('\n❌ Error during data generation:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Run the script
generateDummyData();


















