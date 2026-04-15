const admin = require('firebase-admin');
var serviceAccount = require("./serviceAccountKey.json");

if (admin.apps.length === 0) {
  admin.initializeApp();
}

async function run() {
  try {
    const user = await admin.auth().createUser({
      email: 'test_fake_google@example.com',
      password: 'password123'
    });
    console.log("Created user", user.uid);
    
    await admin.auth().importUsers([{
      uid: user.uid,
      email: 'test_fake_google@example.com',
      passwordHash: Buffer.from('password123'),
      providerData: [
        {
          uid: 'test_fake_google@example.com',
          email: 'test_fake_google@example.com',
          providerId: 'google.com'
        }
      ]
    }], {
      hash: {
        algorithm: 'HMAC_SHA256',
        key: Buffer.from('secret')
      }
    });
    console.log("Imported user!");
    const updated = await admin.auth().getUser(user.uid);
    console.log("Updated providers:", updated.providerData.map(p => p.providerId));
    
    // Cleanup
    await admin.auth().deleteUser(user.uid);
  } catch (e) {
    console.error(e);
  }
}
run();
