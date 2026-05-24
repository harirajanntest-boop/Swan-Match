# Swan Match — Storage Redundancy Guide

## 1. Overview

Swan Match stores data across three Firebase services:
- **Firestore** — User profiles, matches, chats, reports, support tickets
- **Firebase Storage** — Profile photos, verification documents
- **Firebase Auth** — User authentication credentials

This guide covers backup strategies and redundancy for each.

---

## 2. Firestore Automated Backups

### Current Setup
The `scheduledFirestoreBackup` Cloud Function runs **daily at 2:00 AM UTC** and exports the entire Firestore database to Cloud Storage.

**Backup destination:**
```
gs://swan-match.firebasestorage.app/firestore-backups/YYYY-MM-DD
```

### Backup Retention
- Daily backups retained for **30 days** (auto-cleanup in the function)
- Consider extending to **90 days** once you have paying users

### Verify Backups
```bash
# List recent backups
gsutil ls gs://swan-match.firebasestorage.app/firestore-backups/

# Check backup size
gsutil du -sh gs://swan-match.firebasestorage.app/firestore-backups/2026-01-15

# Check export operations
gcloud firestore operations list --project swan-match
```

### Restore from Backup
```bash
# Full restore (replaces all data)
gcloud firestore import gs://swan-match.firebasestorage.app/firestore-backups/2026-01-15 \
  --project swan-match

# Restore specific collections only
gcloud firestore import gs://swan-match.firebasestorage.app/firestore-backups/2026-01-15 \
  --collection-ids=users,reports \
  --project swan-match
```

> ⚠️ **CAUTION**: Full imports overwrite existing data. Test on a staging project first.

---

## 3. Firebase Storage (Images & Documents)

### Current Architecture
- All user photos stored in `gs://swan-match.firebasestorage.app`
- Verification documents stored in `/verifications/` prefix
- Firebase Storage uses **Google Cloud Storage** (GCS) under the hood

### Redundancy Strategy

#### Option A: Multi-Region Bucket (Recommended)
Firebase Storage defaults to `us-central1`. For redundancy:
1. Go to Google Cloud Console → Storage
2. Change bucket location class to **multi-region** (`us`) or **dual-region**
3. This provides automatic geographic redundancy

#### Option B: Cross-Bucket Replication
```bash
# Create a backup bucket
gsutil mb -l us-east1 gs://swan-match-backup

# Set up daily sync (add to cron or Cloud Scheduler)
gsutil -m rsync -r gs://swan-match.firebasestorage.app gs://swan-match-backup
```

#### Option C: Object Versioning
Enable versioning to recover from accidental deletes:
```bash
gsutil versioning set on gs://swan-match.firebasestorage.app
```

### Image Recovery
If images are accidentally deleted:
1. Check if versioning is enabled
2. Restore from backup bucket (if Option B is configured)
3. Users can re-upload via the app

---

## 4. Firebase Auth Backup

Firebase Auth doesn't support automated exports, but you can:
```bash
# Export all users
npx firebase-tools@latest auth:export users.json --project swan-match

# Import users (for disaster recovery)
npx firebase-tools@latest auth:import users.json --project swan-match
```

**Recommendation**: Run `auth:export` weekly as a scheduled task.

---

## 5. Monitoring Recommendations

### Firebase Console Alerts
1. Go to Firebase Console → Settings → Alerts
2. Enable alerts for:
   - Functions execution errors > threshold
   - Firestore usage approaching limits
   - Storage quota warnings

### Cloud Monitoring
1. Go to Google Cloud Console → Monitoring
2. Set up uptime checks for webhook URLs:
   - `https://handlestripewebhook-tdyhtgrwaq-uc.a.run.app`
   - `https://handlechargebackwebhook-tdyhtgrwaq-uc.a.run.app`
3. Set up alert policies for:
   - Cloud Function error rate > 5%
   - Cloud Function latency P95 > 5s
   - Firestore read/write quota > 80%

### Daily Health Check Script
```bash
#!/bin/bash
# Run daily to verify backups exist
LATEST_BACKUP=$(gsutil ls gs://swan-match.firebasestorage.app/firestore-backups/ | tail -1)
if [ -z "$LATEST_BACKUP" ]; then
  echo "⚠️ WARNING: No backups found!"
  exit 1
fi
echo "✅ Latest backup: $LATEST_BACKUP"
```

---

## 6. Disaster Recovery Summary

| Data | Backup Method | Frequency | Recovery Time |
|------|--------------|-----------|---------------|
| Firestore | Automated export | Daily | ~30 min |
| Storage (images) | GCS redundancy | Real-time | Automatic |
| Auth users | Manual export | Weekly | ~15 min |
| Stripe data | Stripe Dashboard | Real-time | N/A (Stripe manages) |

### Recovery Priority Order
1. **Firebase Auth** — Users need to log in
2. **Firestore** — All app data
3. **Storage** — Photos (app works without them)
4. **Stripe** — Managed by Stripe (self-recovering)
