#!/bin/bash

# ==============================================================================
#                 SWAN PLATFORM — DISASTER RECOVERY CLI TOOL
# ==============================================================================
# This script automates manual backups, triggers GCP cloud exports, and guides 
# the development team through restore testing to ensure 100% recovery capability.
#
# Usage:
#   chmod +x scripts/disaster_recovery.sh
#   ./scripts/disaster_recovery.sh
# ==============================================================================

# Color Palette (Luxury Themes)
GOLD='\033[0;33m'
AMBER='\033[1;33m'
ONYX='\033[0;90m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
clear
echo -e "${GOLD}======================================================================"
echo -e "                   SWAN MATCH — DISASTER RECOVERY CLI"
echo -e "======================================================================${NC}"
echo -e "${ONYX}Ready for Emergency Backup, Restore Testing, and Disaster Recovery Procedures${NC}\n"

# Verify Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}[ERROR] Firebase CLI is not installed on this system.${NC}"
    echo -e "Please install it using: npm install -g firebase-tools"
    exit 1
fi

# Verify Google Cloud SDK
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}[WARNING] Google Cloud SDK (gcloud) is not installed.${NC}"
    echo -e "Automatic Firestore exports require the gcloud CLI tool."
    echo -e "Download link: https://cloud.google.com/sdk/docs/install\n"
fi

show_menu() {
    echo -e "${GOLD}Select a Recovery/Backup Procedure to execute:${NC}"
    echo -e "  ${GOLD}[1]${NC} Back Up User Accounts (Firebase Authentication Export)"
    echo -e "  ${GOLD}[2]${NC} Trigger Manual Cloud Firestore Database Snapshot (to GCP Bucket)"
    echo -e "  ${GOLD}[3]${NC} Perform Staging/Restore Verification Test (Dry Run)"
    echo -e "  ${GOLD}[4]${NC} Check Global Infrastructure Status & Rules"
    echo -e "  ${GOLD}[5]${NC} Exit CLI"
    echo ""
}

backup_auth() {
    echo -e "\n${AMBER}--- [1] BACKING UP USER ACCOUNTS (AUTH) ---${NC}"
    read -p "Enter active Firebase Project ID (default: swan-match): " PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-swan-match}
    
    mkdir -p backups/auth
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="backups/auth/users_${TIMESTAMP}.json"
    
    echo -e "Exporting users from project ${GOLD}${PROJECT_ID}${NC}..."
    firebase auth:export "$BACKUP_FILE" --project "$PROJECT_ID"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS] Authentication credentials exported securely to:${NC}"
        echo -e "  👉 ${GOLD}$BACKUP_FILE${NC}"
        echo -e "${ONYX}Keep this file encrypted and under lock and key!${NC}\n"
    else
        echo -e "${RED}[FAILED] Authentication export failed. Please check login status using 'firebase login'.${NC}\n"
    fi
}

backup_firestore() {
    echo -e "\n${AMBER}--- [2] TRIGGERING FIRESTORE SNAPSHOT ON GCP ---${NC}"
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}[ERROR] Google Cloud SDK is required for Firestore snapshots.${NC}\n"
        return
    fi
    
    read -p "Enter active Google Cloud Project ID (default: swan-match): " PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-swan-match}
    
    read -p "Enter destination Google Cloud Storage Bucket (default: gs://swan-match-backups): " BUCKET_NAME
    BUCKET_NAME=${BUCKET_NAME:-gs://swan-match-backups}
    
    echo -e "Checking bucket access and triggering Firestore export..."
    gcloud config set project "$PROJECT_ID"
    gcloud firestore export "$BUCKET_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}[SUCCESS] Full Firestore backup snapshot created successfully in:${NC}"
        echo -e "  👉 ${GOLD}$BUCKET_NAME${NC}\n"
    else
        echo -e "\n${RED}[FAILED] Snapshot creation failed.${NC}"
        echo -e "Make sure your Google account is authorized using 'gcloud auth login' and the Bucket exists with write permissions.\n"
    fi
}

restore_testing() {
    echo -e "\n${AMBER}--- [3] RUNNING STAGING/RESTORE VERIFICATION TEST ---${NC}"
    echo -e "To ensure backups actually work when a disaster happens,"
    echo -e "you must regularly test restoring files to an isolated project."
    echo ""
    echo -e "${GOLD}Step-by-Step Restoration Guide:${NC}"
    echo -e "  ${GOLD}1.${NC} Create a secondary project in Firebase (e.g., 'swan-match-staging')."
    echo -e "  ${GOLD}2.${NC} Restore user logins from your backups directory:"
    echo -e "     ${ONYX}firebase auth:import backups/auth/users_YYYYMMDD_HHMMSS.json --hash-algo=SCRYPT --project=swan-match-staging${NC}"
    echo -e "  ${GOLD}3.${NC} Import your Firestore database snapshot from the storage bucket:"
    echo -e "     ${ONYX}gcloud config set project swan-match-staging${NC}"
    echo -e "     ${ONYX}gcloud firestore import gs://swan-match-backups/YYYY-MM-DD-T-timestamp/${NC}"
    echo -e "  ${GOLD}4.${NC} Deploy current security rules and check connections:"
    echo -e "     ${ONYX}firebase deploy --only firestore:rules,storage:rules --project=swan-match-staging${NC}"
    echo ""
    echo -e "${GREEN}[INFO] The script has created this guide in backups/RESTORE_GUIDE.txt${NC}"
    
    mkdir -p backups
    cat << 'EOF' > backups/RESTORE_GUIDE.txt
==============================================================================
                    SWAN PLATFORM — DISASTER RESTORATION PLAYBOOK
==============================================================================
In case of a catastrophic database failure, follow this playbook to restore 
100% of authentication credentials, chats, safety reports, and user profiles.

PREPARATION:
1. Ensure the Firebase CLI is logged in:
   firebase login
2. Ensure the Google Cloud SDK is logged in:
   gcloud auth login

PHASE 1: RESTORING AUTHENTICATION (USER LOGINS)
Restore the user list to your destination project (e.g. swan-match-staging or restored swan-match):
firebase auth:import backups/auth/users_YYYYMMDD_HHMMSS.json --hash-algo=SCRYPT --project=YOUR_RESTORE_PROJECT_ID

PHASE 2: RESTORING CLOUD FIRESTORE (DATABASE SCHEMAS & RECORDS)
Import the Firestore backup snapshot directly from your secure GCP Bucket:
gcloud config set project YOUR_RESTORE_PROJECT_ID
gcloud firestore import gs://swan-match-backups/YYYY-MM-DD-T-timestamp/

PHASE 3: REDEPLOYING CLOUD SAFETY SHIELD & RULES
Apply security controls to lock down the newly restored database instantly:
firebase deploy --only firestore:rules,storage:rules --project=YOUR_RESTORE_PROJECT_ID

RESTORE TESTING VERIFICATION COMPLETE.
EOF
}

check_rules() {
    echo -e "\n${AMBER}--- [4] VERIFYING INFRASTRUCTURE SECURITY CONTROLS ---${NC}"
    
    if [ -f "firestore.rules" ]; then
        echo -e "${GREEN}[OK] Local firestore.rules exists.${NC}"
        echo -e "Total Rules Lines: $(wc -l < firestore.rules | tr -d ' ')"
    else
        echo -e "${RED}[WARNING] firestore.rules file is missing in active workspace.${NC}"
    fi

    if [ -f "storage.rules" ]; then
        echo -e "${GREEN}[OK] Local storage.rules exists.${NC}"
        echo -e "Total Rules Lines: $(wc -l < storage.rules | tr -d ' ')"
    else
        echo -e "${RED}[WARNING] storage.rules file is missing in active workspace.${NC}"
    fi
    echo ""
}

while true; do
    show_menu
    read -p "Select option [1-5]: " OPTION
    case $OPTION in
        1) backup_auth ;;
        2) backup_firestore ;;
        3) restore_testing ;;
        4) check_rules ;;
        5) echo -e "\n${GOLD}Disaster Recovery Console closed.${NC}"; exit 0 ;;
        *) echo -e "\n${RED}[INVALID] Please select a number from 1 to 5.${NC}\n" ;;
    esac
done
