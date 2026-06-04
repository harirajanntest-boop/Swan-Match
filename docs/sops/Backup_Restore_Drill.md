# SOP: Backup Restore Drill (Step 15)

> Confirms the automated Firestore backups can actually be restored. Run this once now, then every
> ~3 months. Audience: developer. Project: `swan-match`.

## How backups work here
`scheduledFirestoreBackup` exports ALL Firestore collections daily at 02:00 UTC to
`gs://swan-match-backups/firestore-exports/<timestamp>` and logs each run to the `_system_backups`
collection.

## ⚠️ Golden rule
**Never import into the live `(default)` database** — an import overwrites/merges production data.
Restore into a **separate test database**, verify, then delete it.

## Step 1 — Confirm a backup exists
```bash
# List recent export folders in the backup bucket:
gcloud storage ls gs://swan-match-backups/firestore-exports/

# (Optional) check the backup log in Firestore: collection `_system_backups`, newest doc = status 'initiated'.
```
You should see dated folders. Pick the most recent one — note its full path, e.g.
`gs://swan-match-backups/firestore-exports/2026-06-04T02-00-00-000Z`.

If the bucket is empty or missing, the backup isn't working — fix that first (check the function logs:
`firebase functions:log --only scheduledFirestoreBackup --project swan-match`, and confirm the
function's service account has the "Cloud Datastore Import Export Admin" + Storage roles, and that the
`swan-match-backups` bucket exists).

## Step 2 — Create a throwaway test database
```bash
# Firestore supports multiple databases per project. Create one just for the drill
# (use the SAME location as your production database, e.g. nam5 or us-central1):
gcloud firestore databases create --database=restore-test --location=nam5 --project=swan-match
```

## Step 3 — Import the backup into the test database
```bash
gcloud firestore import "gs://swan-match-backups/firestore-exports/<TIMESTAMP>" \
  --database=restore-test --project=swan-match
```
Wait for it to finish (it prints an operation; large datasets take a few minutes).

## Step 4 — Verify the restored data
In the Firebase console, switch to the `restore-test` database and spot-check:
- `users` collection has roughly the expected number of documents.
- Open a few user docs — profile fields, photos, subscription status look correct.
- A couple of other collections exist (`chats`, `reports`, `support_queries`).

Pass = the data is present and looks complete (matching production at backup time).

## Step 5 — Clean up
```bash
# Delete the test database so it doesn't incur cost or confusion:
gcloud firestore databases delete --database=restore-test --project=swan-match
```

## Step 6 — Record the result
Log the drill in `_system_backups` or a simple note: date, which backup was tested, pass/fail, who ran it.
A passing drill checks off Step 15 (Backup + Disaster Recovery).

## Real disaster recovery (for reference only — do NOT run as a drill)
If you ever truly need to restore production after data loss:
```bash
gcloud firestore import "gs://swan-match-backups/firestore-exports/<TIMESTAMP>" --project=swan-match
```
This imports into the live `(default)` database. Only do this during a real incident, ideally after
putting the app in maintenance mode. See `docs/sops/Incident_Response_Runbook.md`.
