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
console.log('📤 جاري نشر القواعد إلى Firebase...\n');

// Use Google Auth Library to get access token
const { GoogleAuth } = require('google-auth-library');
const auth = new GoogleAuth({
  credentials: serviceAccount,
  scopes: ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase']
});

async function deployRules() {
  try {
    // Get access token
    const client = await auth.getClient();
    const accessToken = await client.getAccessToken();
    
    if (!accessToken.token) {
      throw new Error('فشل الحصول على رمز الوصول');
    }
    
    console.log('🔑 تم الحصول على رمز الوصول');
    
    const projectId = 'talendx-12808';
    
    // Step 1: Create Ruleset
    console.log('📝 جاري إنشاء Ruleset...');
    const rulesetData = JSON.stringify({
      source: {
        files: [{
          name: 'firestore.rules',
          content: rules
        }]
      }
    });
    
    const createRuleset = () => {
      return new Promise((resolve, reject) => {
        const options = {
          hostname: 'firebaserules.googleapis.com',
          path: `/v1/projects/${projectId}/rulesets`,
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken.token}`,
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(rulesetData)
          }
        };
        
        const req = https.request(options, (res) => {
          let data = '';
          
          res.on('data', (chunk) => {
            data += chunk;
          });
          
          res.on('end', () => {
            if (res.statusCode === 200 || res.statusCode === 201) {
              const response = JSON.parse(data);
              console.log('✅ تم إنشاء Ruleset بنجاح!');
              console.log(`📋 Ruleset Name: ${response.name}\n`);
              resolve(response.name);
            } else {
              const errorData = JSON.parse(data);
              if (errorData.error && errorData.error.message && errorData.error.message.includes('already exists')) {
                // Ruleset already exists, try to get the latest one
                console.log('ℹ️  Ruleset موجود بالفعل، جاري البحث عن أحدث Ruleset...');
                getLatestRuleset().then(resolve).catch(reject);
              } else {
                reject(new Error(`فشل إنشاء Ruleset: ${res.statusCode} - ${data}`));
              }
            }
          });
        });
        
        req.on('error', (error) => {
          reject(error);
        });
        
        req.write(rulesetData);
        req.end();
      });
    };
    
    // Get latest ruleset
    const getLatestRuleset = () => {
      return new Promise((resolve, reject) => {
        const options = {
          hostname: 'firebaserules.googleapis.com',
          path: `/v1/projects/${projectId}/rulesets`,
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${accessToken.token}`
          }
        };
        
        const req = https.request(options, (res) => {
          let data = '';
          
          res.on('data', (chunk) => {
            data += chunk;
          });
          
          res.on('end', () => {
            if (res.statusCode === 200) {
              const response = JSON.parse(data);
              if (response.rulesets && response.rulesets.length > 0) {
                // Get the most recent one
                const latest = response.rulesets.sort((a, b) => {
                  return new Date(b.createTime) - new Date(a.createTime);
                })[0];
                console.log(`✅ تم العثور على Ruleset: ${latest.name}\n`);
                resolve(latest.name);
              } else {
                reject(new Error('لا توجد Rulesets موجودة'));
              }
            } else {
              reject(new Error(`فشل الحصول على Rulesets: ${res.statusCode} - ${data}`));
            }
          });
        });
        
        req.on('error', (error) => {
          reject(error);
        });
        
        req.end();
      });
    };
    
    // Step 2: Create Release
    const createRelease = (rulesetName) => {
      return new Promise((resolve, reject) => {
        console.log('🚀 جاري إنشاء Release...');
        const releaseData = JSON.stringify({
          name: `projects/${projectId}/releases/cloud.firestore`,
          rulesetName: rulesetName
        });
        
        const options = {
          hostname: 'firebaserules.googleapis.com',
          path: `/v1/projects/${projectId}/releases`,
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken.token}`,
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(releaseData)
          }
        };
        
        const req = https.request(options, (res) => {
          let data = '';
          
          res.on('data', (chunk) => {
            data += chunk;
          });
          
          res.on('end', () => {
            if (res.statusCode === 200 || res.statusCode === 201) {
              console.log('🎉 تم نشر القواعد بنجاح!');
              console.log('✅ القواعد الآن نشطة في Firebase Console');
              console.log('\n⏱️  انتظر 10-30 ثانية ثم جرّب تسجيل الدخول مرة أخرى.\n');
              resolve();
            } else {
              const errorData = JSON.parse(data);
              if (errorData.error && errorData.error.message) {
                console.log('\n⚠️  فشل إنشاء Release تلقائياً');
                console.log(`📋 السبب: ${errorData.error.message}`);
                console.log('\n💡 Ruleset تم إنشاؤه بنجاح!');
                console.log('📋 Ruleset Name:', rulesetName);
                console.log('\n🔧 يجب إنشاء Release يدوياً من Firebase Console:');
                console.log('   1. افتح: https://console.firebase.google.com/project/talendx-12808/firestore/rules');
                console.log('   2. اختر Ruleset:', rulesetName);
                console.log('   3. اضغط Publish\n');
                reject(new Error(errorData.error.message));
              } else {
                reject(new Error(`فشل إنشاء Release: ${res.statusCode} - ${data}`));
              }
            }
          });
        });
        
        req.on('error', (error) => {
          reject(error);
        });
        
        req.write(releaseData);
        req.end();
      });
    };
    
    // Execute deployment
    const rulesetName = await createRuleset();
    await createRelease(rulesetName);
    
  } catch (error) {
    console.error('\n❌ خطأ:', error.message);
    console.log('\n💡 يرجى نشر القواعد يدوياً من Firebase Console');
    console.log('   رابط مباشر: https://console.firebase.google.com/project/talendx-12808/firestore/rules\n');
    process.exit(1);
  }
}

deployRules();


























