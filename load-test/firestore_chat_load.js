/**
 * Tier 2 load test — Firestore chat + profile reads, against the Firebase EMULATOR.
 *
 * Simulates the client's "1,000 messages" + "100 simultaneous users / image-heavy
 * profile reads" targets at the database level, where real apps actually bottleneck.
 *
 * SAFETY: this script refuses to run unless it is pointed at the emulator
 * (FIRESTORE_EMULATOR_HOST set), so it can never touch production data.
 *
 * Usage (see load-test/README.md):
 *   1. Terminal A:  cd Swan_Match_app-main && firebase emulators:start --only firestore,functions,auth
 *   2. Terminal B:  cd Swan_Match_app-main/functions
 *                   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=swan-match \
 *                   node ../load-test/firestore_chat_load.js
 *
 * Tunables (env): MESSAGES (default 1000), CONCURRENCY (50), PROFILES (200), PROFILE_READS (500)
 */

const admin = require('firebase-admin');

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('\n❌ Refusing to run: FIRESTORE_EMULATOR_HOST is not set.');
  console.error('   This test must run against the Firebase Emulator, never production.');
  console.error('   Start the emulator, then set FIRESTORE_EMULATOR_HOST=localhost:8080\n');
  process.exit(1);
}

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'swan-match' });
const db = admin.firestore();

const MESSAGES = Number(process.env.MESSAGES || 1000);
const CONCURRENCY = Number(process.env.CONCURRENCY || 50);
const PROFILES = Number(process.env.PROFILES || 200);
const PROFILE_READS = Number(process.env.PROFILE_READS || 500);

const CHAT_ID = 'loadtest_chat';

function pct(sortedMs, p) {
  if (!sortedMs.length) return 0;
  const idx = Math.min(sortedMs.length - 1, Math.floor((p / 100) * sortedMs.length));
  return sortedMs[idx];
}

// Run `tasks` (array of () => Promise) with a fixed concurrency pool. Returns per-task durations (ms).
async function runPool(tasks, concurrency) {
  const durations = [];
  let next = 0;
  async function worker() {
    while (next < tasks.length) {
      const i = next++;
      const start = Date.now();
      await tasks[i]();
      durations.push(Date.now() - start);
    }
  }
  await Promise.all(Array.from({ length: concurrency }, worker));
  return durations;
}

async function seedProfiles() {
  const tasks = Array.from({ length: PROFILES }, (_, i) => () =>
    db.collection('users').doc(`loadtest_user_${i}`).set({
      name: `Load Test User ${i}`,
      age: 25 + (i % 15),
      gender: i % 2 === 0 ? 'male' : 'female',
      photos: [`https://example.com/p/${i}_1.jpg`, `https://example.com/p/${i}_2.jpg`],
      subscriptionPlan: i % 3 === 0 ? 'premium' : 'free',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    })
  );
  await runPool(tasks, CONCURRENCY);
}

async function loadChatMessages() {
  const msgCol = db.collection('chats').doc(CHAT_ID).collection('messages');
  const tasks = Array.from({ length: MESSAGES }, (_, i) => () =>
    msgCol.add({
      senderId: `loadtest_user_${i % PROFILES}`,
      text: `Load test message ${i} — the quick brown fox jumps over the lazy dog.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    })
  );
  const start = Date.now();
  const durations = await runPool(tasks, CONCURRENCY).then((d) => { d.totalMs = Date.now() - start; return d; });
  return durations;
}

async function concurrentProfileReads() {
  const tasks = Array.from({ length: PROFILE_READS }, (_, i) => () =>
    db.collection('users').doc(`loadtest_user_${i % PROFILES}`).get()
  );
  const start = Date.now();
  const durations = await runPool(tasks, CONCURRENCY);
  durations.totalMs = Date.now() - start;
  return durations;
}

function report(label, durations, count) {
  const sorted = [...durations].sort((a, b) => a - b);
  const total = durations.totalMs;
  const avg = durations.reduce((a, b) => a + b, 0) / durations.length;
  console.log(`\n${label}`);
  console.log(`  total: ${count} ops in ${total} ms  (${Math.round((count / total) * 1000)} ops/sec)`);
  console.log(`  latency  avg ${avg.toFixed(1)}ms  p50 ${pct(sorted, 50)}ms  p95 ${pct(sorted, 95)}ms  max ${sorted[sorted.length - 1]}ms`);
}

async function cleanup() {
  // Emulator data is wiped on restart, but tidy up the chat anyway.
  const snap = await db.collection('chats').doc(CHAT_ID).collection('messages').get();
  const batchSize = 400;
  for (let i = 0; i < snap.docs.length; i += batchSize) {
    const batch = db.batch();
    snap.docs.slice(i, i + batchSize).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

(async () => {
  console.log(`\n🏋️  Firestore load test (EMULATOR @ ${process.env.FIRESTORE_EMULATOR_HOST})`);
  console.log(`   messages=${MESSAGES}  profiles=${PROFILES}  profileReads=${PROFILE_READS}  concurrency=${CONCURRENCY}`);

  console.log('\nSeeding profiles...');
  await seedProfiles();

  const writeDurations = await loadChatMessages();
  report(`💬 Chat write load (${MESSAGES} messages)`, writeDurations, MESSAGES);

  const readDurations = await concurrentProfileReads();
  report(`👤 Concurrent profile reads (${PROFILE_READS} reads)`, readDurations, PROFILE_READS);

  console.log('\nCleaning up chat messages...');
  await cleanup();

  console.log('\n✅ Done. Pass criteria: writes sustain >100 msgs/sec, read p95 < 200ms, no errors.\n');
  process.exit(0);
})().catch((err) => {
  console.error('\n❌ Load test failed:', err.message);
  process.exit(1);
});
