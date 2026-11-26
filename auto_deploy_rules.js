const https = require('https');
const fs = require('fs');
const path = require('path');

// Read service account
const serviceAccountPath = './talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json';
if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ ملف Service Account غير موجود:', serviceAccountPath);
  process.exit(1);
}

const serviceAccount = JSON.parse(
  fs.readFileSync(serviceAccountPath, 'utf8')
);

// Read rules file
const rulesPath = './firestore.rules';
if (!fs.existsSync(rulesPath)) {
  console.error('❌ ملف firestore.rules غير موجود:', rulesPath);
  process.exit(1);
}

const rules = fs.readFileSync(rulesPath, 'utf8');

const projectId = 'talendx-12808';

// Get access token using service account
async function getAccessToken() {
  return new Promise((resolve, reject) => {
    // Try to use jsonwebtoken if available, otherwise use a simpler method
    let jwt;
    try {
      jwt = require('jsonwebtoken');
    } catch (e) {
      console.error('❌ المكتبة jsonwebtoken غير مثبتة');
      console.log('💡 قم بتثبيتها: npm install jsonwebtoken');
      reject(new Error('jsonwebtoken not installed'));
      return;
    }
    
    const now = Math.floor(Date.now() / 1000);
    const token = jwt.sign(
      {
        iss: serviceAccount.client_email,
        sub: serviceAccount.client_email,
        aud: 'https://oauth2.googleapis.com/token',
        exp: now + 3600,
        iat: now,
        scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase'
      },
      serviceAccount.private_key,
      { algorithm: 'RS256' }
    );

    const postData = `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${encodeURIComponent(token)}`;

    const options = {
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          const response = JSON.parse(data);
          resolve(response.access_token);
        } else {
          reject(new Error(`Failed to get access token: ${res.statusCode} - ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

// Deploy rules
async function deployRules() {
  try {
    console.log('🔑 جاري الحصول على رمز الوصول...');
    const accessToken = await getAccessToken();
    console.log('✅ تم الحصول على رمز الوصول\n');

    console.log('📝 جاري إنشاء Ruleset...');
    const rulesetData = JSON.stringify({
      source: {
        files: [{
          name: 'firestore.rules',
          content: rules
        }]
      }
    });

    // Step 1: Create Ruleset
    const rulesetName = await new Promise((resolve, reject) => {
      const options = {
        hostname: 'firebaserules.googleapis.com',
        path: `/v1/projects/${projectId}/rulesets`,
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(rulesetData)
        }
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          if (res.statusCode === 200 || res.statusCode === 201) {
            const response = JSON.parse(data);
            console.log('✅ تم إنشاء Ruleset بنجاح!');
            console.log(`📋 Ruleset Name: ${response.name}\n`);
            resolve(response.name);
          } else {
            const errorData = JSON.parse(data);
            if (errorData.error && errorData.error.message && errorData.error.message.includes('already exists')) {
              console.log('ℹ️  Ruleset موجود بالفعل، جاري البحث عن أحدث Ruleset...');
              getLatestRuleset(accessToken).then(resolve).catch(reject);
            } else {
              reject(new Error(`فشل إنشاء Ruleset: ${res.statusCode} - ${data}`));
            }
          }
        });
      });

      req.on('error', reject);
      req.write(rulesetData);
      req.end();
    });

    // Step 2: Create Release
    console.log('🚀 جاري نشر القواعد...');
    const releaseData = JSON.stringify({
      name: `projects/${projectId}/releases/cloud.firestore`,
      rulesetName: rulesetName
    });

    await new Promise((resolve, reject) => {
      const options = {
        hostname: 'firebaserules.googleapis.com',
        path: `/v1/projects/${projectId}/releases`,
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(releaseData)
        }
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          if (res.statusCode === 200 || res.statusCode === 201) {
            console.log('🎉 تم نشر القواعد بنجاح!');
            console.log('✅ القواعد الآن نشطة في Firebase');
            console.log('\n⏱️  انتظر 10-30 ثانية ثم جرّب التطبيق مرة أخرى.\n');
            resolve();
          } else {
            const errorData = JSON.parse(data);
            console.log('\n⚠️  فشل إنشاء Release تلقائياً');
            console.log(`📋 السبب: ${errorData.error?.message || data}`);
            console.log('\n💡 Ruleset تم إنشاؤه بنجاح!');
            console.log('📋 Ruleset Name:', rulesetName);
            console.log('\n🔧 يجب إنشاء Release يدوياً من Firebase Console:');
            console.log('   1. افتح: https://console.firebase.google.com/project/talendx-12808/firestore/rules');
            console.log('   2. اختر Ruleset:', rulesetName);
            console.log('   3. اضغط Publish\n');
            reject(new Error(errorData.error?.message || data));
          }
        });
      });

      req.on('error', reject);
      req.write(releaseData);
      req.end();
    });

  } catch (error) {
    console.error('\n❌ خطأ:', error.message);
    console.log('\n💡 يرجى نشر القواعد يدوياً من Firebase Console');
    console.log('   رابط مباشر: https://console.firebase.google.com/project/talendx-12808/firestore/rules\n');
    process.exit(1);
  }
}

// Get latest ruleset
function getLatestRuleset(accessToken) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'firebaserules.googleapis.com',
      path: `/v1/projects/${projectId}/rulesets`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          const response = JSON.parse(data);
          if (response.rulesets && response.rulesets.length > 0) {
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

    req.on('error', reject);
    req.end();
  });
}

// Run deployment
if (require.main === module) {
  deployRules();
}

module.exports = { deployRules };






















