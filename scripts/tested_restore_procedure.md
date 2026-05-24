# SWAN MATCH — TESTED DATABASE RESTORATION PROCEDURE
*An emergency playbook outlining the exact sequence of commands and steps to recover 100% of user data and server configurations in the event of a catastrophic disaster or system outage.*

---

## 1. Prerequisites & Required Tools
Before executing any recovery procedures, ensure you have the following installed and authenticated:
- **Firebase CLI:** Installed and logged in with your project owner credentials:
  ```bash
  npm install -g firebase-tools
  firebase login
  ```
- **Google Cloud SDK (gcloud):** Installed and authenticated:
  ```bash
  # Check if installed
  gcloud --version
  
  # Log in
  gcloud auth login
  ```

---

## 2. Phase 1 — Restoring User Accounts (Firebase Authentication)
Firebase Authentication handles all user logins (emails, passwords, salt). These are backed up daily using the CLI.

1. **Locate the latest backup file:**
   Navigate to the `backups/auth` directory in your workspace and find the most recent snapshot (e.g., `users_20260524_230917.json`).
2. **Execute the Import Command:**
   Run the following command, specifying the SCRYPT hashing algorithm parameters (which match Firebase's native encryption format):
   ```bash
   firebase auth:import backups/auth/users_YYYYMMDD_HHMMSS.json \
     --hash-algo=SCRYPT \
     --rounds=8 \
     --mem-cost=14 \
     --project=YOUR_RESTORE_PROJECT_ID
   ```
3. **Verify Import:**
   Log into the Firebase Console, navigate to **Authentication > Users**, and confirm that the user records have successfully imported.

---

## 3. Phase 2 — Restoring Cloud Firestore (Database Snapshots)
Firestore database exports are stored in our secure, multi-region Google Cloud Storage bucket (`gs://swan-match-backups`).

1. **Identify the Backup Folder:**
   List the contents of the backup bucket to find the latest timestamped export folder:
   ```bash
   gsutil ls gs://swan-match-backups/
   # Output e.g.: gs://swan-match-backups/2026-05-24T120000/
   ```
2. **Set the Target Project:**
   Ensure the gcloud CLI is pointed to your active restore project:
   ```bash
   gcloud config set project YOUR_RESTORE_PROJECT_ID
   ```
3. **Trigger the Import Operation:**
   Run the gcloud import command, pointing to the specific metadata file in the export folder:
   ```bash
   gcloud firestore import gs://swan-match-backups/YYYY-MM-DD-T-timestamp/
   ```
   *Note: This command runs asynchronously in the cloud. You can monitor the operation status using:*
   ```bash
   gcloud firestore operations list
   ```

---

## 4. Phase 3 — Restoring Storage Assets (Profile Photos & Verification Media)
In a disaster where the primary Storage bucket is corrupted, we recover files from our cold-storage redundancy backup.

1. **Sync Bucket Contents:**
   If you need to sync media from our secondary bucket back to the primary bucket, execute a high-speed GCP sync operation:
   ```bash
   gsutil -m rsync -r gs://swan-match-backups-redundant/users gs://swan-match.appspot.com/users
   ```

---

## 5. Phase 4 — Applying Security Shields (Rules & Functions Deployment)
Once database structures are restored, we must instantly apply security rules to prevent public exposure.

1. **Deploy Rules:**
   ```bash
   firebase deploy --only firestore:rules,storage:rules --project=YOUR_RESTORE_PROJECT_ID
   ```
2. **Deploy Cloud Functions:**
   ```bash
   cd functions
   npm run deploy
   ```

---

## 6. How to Perform a Safe Dry-Run Restore (Testing Procedure)
To guarantee that our backups are always ready and non-corrupt, developers must perform a Staging Restore Verification Test every quarter:

1. **Create an Isolated Sandbox Project:**
   Create a fresh, empty Firebase project (e.g., `swan-match-restore-test`).
2. **Execute the automated test script:**
   Run the local verification tool to check JSON formatting:
   ```bash
   ./scripts/restore_test.sh
   ```
3. **Perform a mock CLI import:**
   Import `backups/auth/mock_test_users.json` to the sandbox project to verify SCRYPT compatibility.
4. **Clean up:**
   Once testing completes, delete the sandbox project in the GCP console to avoid orphan storage costs.
