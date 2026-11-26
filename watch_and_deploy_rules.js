const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

console.log('👀 بدء مراقبة ملف firestore.rules...');
console.log('📋 سيتم نشر القواعد تلقائياً عند أي تعديل\n');

let isDeploying = false;
let deployTimeout = null;

// Watch for changes in firestore.rules
fs.watchFile('firestore.rules', { interval: 1000 }, (curr, prev) => {
  // Check if file was actually modified (not just accessed)
  if (curr.mtime.getTime() !== prev.mtime.getTime()) {
    console.log('📝 تم اكتشاف تغيير في firestore.rules');
    
    // Debounce: wait 2 seconds before deploying (in case of multiple rapid changes)
    if (deployTimeout) {
      clearTimeout(deployTimeout);
    }
    
    deployTimeout = setTimeout(() => {
      if (!isDeploying) {
        deployRules();
      }
    }, 2000);
  }
});

function deployRules() {
  if (isDeploying) {
    console.log('⏳ جاري النشر بالفعل، انتظر...');
    return;
  }
  
  isDeploying = true;
  console.log('\n🚀 بدء نشر القواعد إلى Firebase...\n');
  
  // Use the auto deploy script
  const deployScript = spawn('node', ['auto_deploy_rules.js'], {
    stdio: 'inherit',
    shell: true
  });
  
  deployScript.on('close', (code) => {
    isDeploying = false;
    if (code === 0) {
      console.log('\n✅ تم نشر القواعد بنجاح!');
      console.log('👀 استمرار المراقبة...\n');
    } else {
      console.log('\n❌ فشل نشر القواعد');
      console.log('👀 استمرار المراقبة...\n');
    }
  });
  
  deployScript.on('error', (error) => {
    isDeploying = false;
    console.error('\n❌ خطأ في تشغيل سكريبت النشر:', error.message);
    console.log('💡 تأكد من تثبيت المكتبات المطلوبة: npm install google-auth-library');
    console.log('👀 استمرار المراقبة...\n');
  });
}

// Handle process termination
process.on('SIGINT', () => {
  console.log('\n\n👋 إيقاف المراقبة...');
  fs.unwatchFile('firestore.rules');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n\n👋 إيقاف المراقبة...');
  fs.unwatchFile('firestore.rules');
  process.exit(0);
});

console.log('💡 اضغط Ctrl+C لإيقاف المراقبة\n');

