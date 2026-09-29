/**
 * Swan Match — One-time private-data cleanup for EXISTING users.
 *
 * Every signed-in user can read users/{uid}, so it must not hold:
 *   1. Public download links to selfie / government-ID photos
 *      (verificationPhotoUrl, idVerificationUrl, selfieUrl, idProofUrl).
 *      → converted to storage PATHS (verificationPhotoPath, idVerificationPath)
 *        that only the owner/admins can open (storage.rules), and the old
 *        link's download token is REVOKED so leaked links stop working.
 *   2. Login IP / device fields (lastLoginIp, lastLoginDeviceId,
 *      lastLoginDeviceModel).
 *      → device → account mapping copied to the server-only deviceIndex
 *        collection (used by logSessionActivity's banned-device check),
 *        then the fields are deleted. Full history stays in securityLogs.
 *
 * New app builds and the updated logSessionActivity function already write
 * the new format; this script fixes accounts created before them.
 *
 * DRY RUN by default (prints what would change, writes nothing):
 *   cd functions && node ../scripts/migrate_private_data.js
 * Apply the changes:
 *   cd functions && node ../scripts/migrate_private_data.js --apply
 *
 * Needs admin credentials, e.g. `gcloud auth application-default login`
 * or GOOGLE_APPLICATION_CREDENTIALS=<service-account.json>.
 * Safe to run more than once — already-migrated users are skipped.
 */

// Resolve firebase-admin from functions/node_modules: Node looks up packages
// relative to THIS file (scripts/), where none are installed.
const path = require('path');
const requireFromFunctions = require('module').createRequire(
  path.join(__dirname, '..', 'functions', 'package.json'),
);
const admin = requireFromFunctions('firebase-admin');
const { FieldValue } = requireFromFunctions('firebase-admin/firestore');

const APPLY = process.argv.includes('--apply');
const PROJECT_ID = process.env.PROJECT_ID || 'swan-match';
const BUCKET = process.env.STORAGE_BUCKET || 'swan-match.firebasestorage.app';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
}
const db = admin.firestore();
const bucket = admin.storage().bucket(BUCKET);

// Legacy public-link field → new private path field.
const LINK_FIELDS = [
  ['verificationPhotoUrl', 'verificationPhotoPath'],
  ['selfieUrl', 'verificationPhotoPath'],
  ['idVerificationUrl', 'idVerificationPath'],
  ['idProofUrl', 'idVerificationPath'],
];
const DEVICE_FIELDS = ['lastLoginIp', 'lastLoginDeviceId', 'lastLoginDeviceModel'];

/** Returns the object path if [url] points at a file in our bucket, else null. */
function storagePathFromUrl(url) {
  if (typeof url !== 'string' || !url.startsWith('http')) return null;
  try {
    const u = new URL(url);
    // https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded path>?alt=media&token=…
    // (the storage emulator serves the same /v0/b/… shape on its own host)
    const m = u.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
    if (m && m[1] === BUCKET) return decodeURIComponent(m[2]);
    // https://storage.googleapis.com/<bucket>/<path>
    if (u.hostname === 'storage.googleapis.com') {
      const [, b, ...rest] = u.pathname.split('/');
      if (b === BUCKET && rest.length) return decodeURIComponent(rest.join('/'));
    }
  } catch (_) { /* not a URL */ }
  return null;
}

async function revokeDownloadTokens(path) {
  const file = bucket.file(path);
  const [exists] = await file.exists();
  if (!exists) return 'missing';
  // Replacing the token makes every previously issued download link for this
  // file stop working; admins get the new one via getDownloadURL(path), which
  // storage.rules only allow for the owner or an admin.
  await file.setMetadata({
    metadata: { firebaseStorageDownloadTokens: require('crypto').randomUUID() },
  });
  return 'revoked';
}

async function migrateUser(snap, stats) {
  const d = snap.data();
  const uid = snap.id;
  const update = {};
  const notes = [];

  for (const [linkField, pathField] of LINK_FIELDS) {
    const url = d[linkField];
    if (!url) continue;
    const path = storagePathFromUrl(url);
    if (!path) {
      // External image (e.g. seeded test accounts) — not a private upload.
      stats.externalLinksLeft++;
      continue;
    }
    const result = APPLY ? await revokeDownloadTokens(path) : 'would revoke';
    if (!d[pathField] && !update[pathField] && result !== 'missing') update[pathField] = path;
    update[linkField] = FieldValue.delete();
    notes.push(`${linkField} → ${pathField} (${result})`);
    stats.linksConverted++;
  }

  if (DEVICE_FIELDS.some((f) => f in d)) {
    const deviceId = d.lastLoginDeviceId;
    if (deviceId) {
      const deviceDocId = String(deviceId).replace(/\//g, '_').slice(0, 700);
      if (APPLY) {
        await db.collection('deviceIndex').doc(deviceDocId).set({
          uids: FieldValue.arrayUnion(uid),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      stats.devicesIndexed++;
    }
    for (const f of DEVICE_FIELDS) if (f in d) update[f] = FieldValue.delete();
    notes.push('IP/device fields removed');
    stats.deviceFieldsRemoved++;
  }

  if (Object.keys(update).length === 0) return;
  stats.usersChanged++;
  console.log(`${APPLY ? 'UPDATED' : 'WOULD UPDATE'} ${uid}: ${notes.join('; ')}`);
  if (APPLY) await snap.ref.update(update);
}

async function main() {
  console.log(`Project ${PROJECT_ID}, bucket ${BUCKET} — ${APPLY ? 'APPLYING CHANGES' : 'DRY RUN (no writes)'}\n`);
  const stats = {
    usersScanned: 0, usersChanged: 0, linksConverted: 0, externalLinksLeft: 0,
    deviceFieldsRemoved: 0, devicesIndexed: 0, errors: 0,
  };
  let last = null;
  for (;;) {
    let q = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(300);
    if (last) q = q.startAfter(last);
    const page = await q.get();
    if (page.empty) break;
    for (const snap of page.docs) {
      stats.usersScanned++;
      try {
        await migrateUser(snap, stats);
      } catch (err) {
        stats.errors++;
        console.error(`ERROR ${snap.id}: ${err.message}`);
      }
    }
    last = page.docs[page.docs.length - 1];
  }
  console.log('\nSummary:', stats);
  if (!APPLY && stats.usersChanged > 0) {
    console.log('\nNothing was written. Re-run with --apply to make these changes.');
  }
  process.exit(stats.errors ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
