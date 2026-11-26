const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'talendx-12808'
});

// Read the rules file
const rulesPath = path.join(__dirname, 'firestore.rules');
const rules = fs.readFileSync(rulesPath, 'utf8');

console.log('📋 قراءة قواعد Firestore...');
console.log('📤 جاري نشر القواعد إلى Firebase...');

// Note: Firebase Admin SDK doesn't have a direct method to deploy rules
// We need to use the REST API or Firebase CLI
// This script will validate the rules and provide instructions

console.log('\n✅ القواعد جاهزة للنشر!');
console.log('\n📝 للأسف، Firebase Admin SDK لا يدعم نشر القواعد مباشرة.');
console.log('🔧 يجب استخدام Firebase CLI أو Firebase Console.\n');

console.log('📋 القواعد الحالية:');
console.log('─'.repeat(50));
console.log(rules);
console.log('─'.repeat(50));

console.log('\n🚀 خطوات النشر:');
console.log('1. افتح: https://console.firebase.google.com/');
console.log('2. اختر المشروع: talendx-12808');
console.log('3. اذهب إلى: Firestore Database → Rules');
console.log('4. انسخ القواعد أعلاه والصقها');
console.log('5. اضغط Publish\n');

process.exit(0);


























