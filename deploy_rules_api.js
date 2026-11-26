const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');

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

// Get access token using Google Auth Library
const { GoogleAuth } = require('google-auth-library');
const auth = new GoogleAuth({
  credentials: serviceAccount,
  scopes: ['https://www.googleapis.com/auth/cloud-platform']
});

auth.getAccessToken()
  .then((token) => {
    console.log('🔑 الحصول على رمز الوصول...');
    
    // Use Firebase Management REST API to deploy rules
    const projectId = 'talendx-12808';
    const url = `https://firebaserules.googleapis.com/v1/projects/${projectId}/releases`;
    
    // First, we need to create a ruleset
    const rulesetUrl = `https://firebaserules.googleapis.com/v1/projects/${projectId}/rulesets`;
    
    const rulesetData = JSON.stringify({
      source: {
        files: [{
          name: 'firestore.rules',
          content: rules
        }]
      }
    });
    
    const options = {
      hostname: 'firebaserules.googleapis.com',
      path: `/v1/projects/${projectId}/rulesets`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(rulesetData)
      }
    };
    
    console.log('📤 جاري نشر القواعد إلى Firebase...');
    
    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200 || res.statusCode === 201) {
          const response = JSON.parse(data);
          console.log('✅ تم إنشاء Ruleset بنجاح!');
          console.log('📋 Ruleset Name:', response.name);
          
          // Now create a release
          const releaseData = JSON.stringify({
            name: `projects/${projectId}/releases/cloud.firestore`,
            rulesetName: response.name
          });
          
          const releaseOptions = {
            hostname: 'firebaserules.googleapis.com',
            path: `/v1/projects/${projectId}/releases`,
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${token}`,
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(releaseData)
            }
          };
          
          const releaseReq = https.request(releaseOptions, (releaseRes) => {
            let releaseData = '';
            
            releaseRes.on('data', (chunk) => {
              releaseData += chunk;
            });
            
            releaseRes.on('end', () => {
              if (releaseRes.statusCode === 200 || releaseRes.statusCode === 201) {
                console.log('\n🎉 تم نشر القواعد بنجاح!');
                console.log('✅ القواعد الآن نشطة في Firebase Console');
                console.log('\n⏱️  انتظر 10-30 ثانية ثم جرّب تسجيل الدخول مرة أخرى.\n');
              } else {
                console.log('\n⚠️  تم إنشاء Ruleset لكن فشل إنشاء Release');
                console.log('📋 Response:', releaseData);
                console.log('\n💡 يمكنك إنشاء Release يدوياً من Firebase Console\n');
              }
            });
          });
          
          releaseReq.on('error', (error) => {
            console.error('❌ خطأ في إنشاء Release:', error);
          });
          
          releaseReq.write(releaseData);
          releaseReq.end();
          
        } else {
          console.error('❌ خطأ في نشر القواعد:', res.statusCode);
          console.error('📋 Response:', data);
          console.log('\n💡 يرجى نشر القواعد يدوياً من Firebase Console\n');
        }
      });
    });
    
    req.on('error', (error) => {
      console.error('❌ خطأ في الاتصال:', error);
      console.log('\n💡 يرجى نشر القواعد يدوياً من Firebase Console\n');
    });
    
    req.write(rulesetData);
    req.end();
    
  })
  .catch((error) => {
    console.error('❌ خطأ في الحصول على رمز الوصول:', error);
    console.log('\n💡 يرجى نشر القواعد يدوياً من Firebase Console\n');
  });

  