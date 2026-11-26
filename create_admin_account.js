const admin = require('firebase-admin');
const serviceAccount = require('./talendx-12808-firebase-adminsdk-fbsvc-22dcafb5e4.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

// Admin email
const adminEmail = 'domaduios@gmail.com';

async function createAdminAccount() {
  try {
    console.log('🚀 Creating admin account for:', adminEmail);
    console.log('');

    // Check if user exists in Firebase Auth
    let user;
    try {
      user = await auth.getUserByEmail(adminEmail);
      console.log('✅ User already exists in Firebase Auth');
      console.log('   User ID:', user.uid);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log('⚠️  User does not exist in Firebase Auth');
        console.log('📝 Creating new user in Firebase Auth...');
        
      // Create user in Firebase Auth
      // Note: We can't set password directly, user will need to use password reset
      try {
        user = await auth.createUser({
          email: adminEmail,
          emailVerified: false,
          displayName: 'Admin',
          disabled: false,
        });
        console.log('✅ User created in Firebase Auth');
        console.log('   User ID:', user.uid);
        
        // Generate password reset link
        try {
          const resetLink = await auth.generatePasswordResetLink(adminEmail);
          console.log('');
          console.log('📧 Password Reset Link Generated:');
          console.log('   ' + resetLink);
          console.log('');
          console.log('💡 Send this link to the admin to set their password');
        } catch (linkError) {
          console.log('⚠️  Could not generate password reset link:', linkError.message);
          console.log('   Admin can use "Forgot Password" in the app instead');
        }
      } catch (createError) {
        console.error('❌ Error creating user:', createError.message);
        throw createError;
      }
      } else {
        throw error;
      }
    }

    // Check if user document exists in Firestore
    const userDocRef = db.collection('users').doc(user.uid);
    const userDoc = await userDocRef.get();

    if (userDoc.exists) {
      const userData = userDoc.data();
      console.log('✅ User document exists in Firestore');
      
      // Check if already admin
      if (userData.isAdmin === true || userData.role === 'admin' || userData.role === 'Admin') {
        console.log('✅ User is already an admin!');
        console.log('   isAdmin:', userData.isAdmin);
        console.log('   role:', userData.role);
        return;
      }

      // Update existing user to admin
      console.log('🔄 Updating user to admin...');
      await userDocRef.update({
        isAdmin: true,
        role: 'admin',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ User updated to admin successfully!');
      
      // Generate password reset link if needed
      if (!user.emailVerified) {
        try {
          const resetLink = await auth.generatePasswordResetLink(adminEmail);
          console.log('');
          console.log('📧 Password Reset Link (if needed):');
          console.log('   ' + resetLink);
        } catch (linkError) {
          // Ignore if link generation fails
        }
      }
    } else {
      // Create new user document with admin privileges
      console.log('📝 Creating new user document with admin privileges...');
      await userDocRef.set({
        email: adminEmail,
        name: user.displayName || 'Admin',
        isAdmin: true,
        role: 'admin',
        profileCompleted: false,
        emailVerified: user.emailVerified || false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ User document created with admin privileges!');
    }

    // Verify the update
    const updatedDoc = await userDocRef.get();
    const updatedData = updatedDoc.data();
    console.log('');
    console.log('📋 Final User Data:');
    console.log('   Email:', updatedData.email);
    console.log('   Name:', updatedData.name);
    console.log('   isAdmin:', updatedData.isAdmin);
    console.log('   role:', updatedData.role);
    console.log('');
    console.log('🎉 Admin account setup completed successfully!');
    console.log('💡 The user can now access the admin dashboard.');

  } catch (error) {
    console.error('❌ Error creating admin account:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Run the script
createAdminAccount();

