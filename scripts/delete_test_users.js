/**
 * Swan Match — Bulk Delete Test Users
 *
 * Run from the functions/ directory:
 *   cd functions && node ../scripts/delete_test_users.js
 *
 * Deletes users with doc IDs starting with:
 *  - "test_male_"
 *  - "test_female_"
 *  - "heavy_male_"
 *  - "heavy_female_"
 * Or users that have the "isTestUser: true" field set in Firestore.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'swan-match' });
}
const db = admin.firestore();

async function run() {
  console.log('🦢 Querying test users from Firestore...');
  const snapshot = await db.collection('users').get();
  console.log(`Found ${snapshot.size} total user documents in Firestore.`);

  let deletedCount = 0;
  // Firestore batch limit is 500. We will write batch commits in chunks of 400.
  let batch = db.batch();
  let batchSize = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const id = doc.id;

    const isPrefixed = 
      id.startsWith('test_male_') || 
      id.startsWith('test_female_') ||
      id.startsWith('heavy_male_') ||
      id.startsWith('heavy_female_');

    const isTestFlagged = data.isTestUser === true;

    if (isPrefixed || isTestFlagged) {
      console.log(`Scheduling deletion for user doc: ${id} (${data.name || 'Unnamed'})`);
      batch.delete(doc.ref);
      deletedCount++;
      batchSize++;

      if (batchSize >= 400) {
        console.log(`Committing batch of ${batchSize} deletions...`);
        await batch.commit();
        batch = db.batch();
        batchSize = 0;
      }
    }
  }

  if (batchSize > 0) {
    console.log(`Committing final batch of ${batchSize} deletions...`);
    await batch.commit();
  }

  console.log(`\n🎉 Success! Deleted ${deletedCount} test user documents from Firestore.`);
  process.exit(0);
}

run().catch(err => {
  console.error('❌ Error running deletion:', err);
  process.exit(1);
});
