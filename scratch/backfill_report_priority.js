// One-time script: Backfill priority for existing reports that don't have it
// Run: node scratch/backfill_report_priority.js

const admin = require('firebase-admin');
const serviceAccount = require('../functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const P1_KEYWORDS = ['threat', 'kill', 'harm', 'suicide', 'underage', 'minor', 'child', 'blackmail', 'extort'];
const P2_KEYWORDS = ['scam', 'fraud', 'fake', 'impersonat', 'catfish', 'money', 'escort', 'spam', 'harass', 'stalk'];

async function backfill() {
  const snapshot = await db.collection('reports').get();
  console.log(`Found ${snapshot.size} reports to check.`);

  let updated = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    
    // Skip if already has priority
    if (data.priority) {
      console.log(`  [skip] ${doc.id} — already has priority: ${data.priority}`);
      continue;
    }

    const reason = (data.reason || '').toLowerCase();
    let priority = 'P3';
    if (P1_KEYWORDS.some(k => reason.includes(k))) priority = 'P1';
    else if (P2_KEYWORDS.some(k => reason.includes(k))) priority = 'P2';

    await doc.ref.update({ priority });
    console.log(`  [updated] ${doc.id} — reason: "${data.reason}" → priority: ${priority}`);
    updated++;
  }

  console.log(`\nDone! Updated ${updated} report(s).`);
  process.exit(0);
}

backfill().catch(err => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
