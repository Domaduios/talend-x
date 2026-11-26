const { GoogleAuth } = require('google-auth-library');
const fs = require('fs');
const https = require('https');

// Read service account
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

// Read rules file
const rules = fs.readFileSync('./firestore.rules', 'utf8');

const projectId = 'talendx-12808';

async function deployRules() {
  try {
    console.log('📋 قراءة قواعد Firestore...');
    console.log('📤 جاري نشر القواعد إلى Firebase...\n');

    // Get access token
    const auth = new GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase']
    });

    const client = await auth.getClient();
    const accessTokenResponse = await client.getAccessToken();
    
    if (!accessTokenResponse.token) {
      throw new Error('فشل الحصول على رمز الوصول');
    }
    
    const accessToken = accessTokenResponse.token;
    console.log('🔑 تم الحصول على رمز الوصول\n');

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
deployRules();






















