# Swan Match — Outage Runbook

## 1. Incident Response Checklist

### Immediate Actions (First 5 Minutes)
- [ ] **Identify** — Confirm the issue (check Firebase Console, Cloud Functions logs, Stripe dashboard)
- [ ] **Assess severity** — P1 (app down), P2 (degraded), P3 (minor feature broken)
- [ ] **Communicate** — Notify the team in Slack/WhatsApp
- [ ] **Start timer** — Note the incident start time for SLA tracking

### Investigation (5-30 Minutes)
- [ ] Check Firebase Console → Functions → Logs for errors
- [ ] Check Firebase Console → Firestore → Usage for quota issues
- [ ] Check Firebase Console → Authentication for auth failures
- [ ] Check Stripe Dashboard for payment processing issues
- [ ] Check Google Cloud Console for infrastructure issues

### Resolution
- [ ] Apply fix (redeploy, rollback, config change)
- [ ] Verify fix works in production
- [ ] Monitor for 15 minutes after fix

### Post-Incident
- [ ] Write incident summary
- [ ] Update this runbook with new learnings
- [ ] Schedule post-mortem within 48 hours

---

## 2. Firebase-Specific Troubleshooting

### Cloud Functions Not Responding
```bash
# Check function logs
npx firebase-tools@latest functions:log --project swan-match

# Check specific function
npx firebase-tools@latest functions:log --only submitReport --project swan-match

# Redeploy all functions
npx firebase-tools@latest deploy --only functions --project swan-match

# Redeploy single function (use codebase prefix)
npx firebase-tools@latest deploy --only functions --project swan-match
```

### Firestore Issues
- **Quota exceeded**: Check Firebase Console → Firestore → Usage
- **Slow queries**: Check Firestore → Indexes for missing indexes
- **Permission denied**: Check `firestore.rules` and redeploy:
  ```bash
  npx firebase-tools@latest deploy --only firestore:rules --project swan-match
  ```

### Authentication Issues
- Check Firebase Console → Authentication → Users
- Check if auth providers (Phone, Google) are still enabled
- Check quota limits for SMS (phone auth)

### Storage Issues
- Check Firebase Console → Storage → Usage
- Verify storage rules:
  ```bash
  npx firebase-tools@latest deploy --only storage --project swan-match
  ```

---

## 3. Stripe Payment Issues

### Payments Not Processing
1. Check Stripe Dashboard → Events for failed webhooks
2. Verify webhook endpoint URL is correct:
   - Production: `https://handlestripewebhook-tdyhtgrwaq-uc.a.run.app`
3. Check webhook signing secret matches the one in Firebase secrets
4. Review Stripe Dashboard → Payments for declined transactions

### Subscription Issues
1. Check `verifySubscription` function logs
2. Verify Stripe product/price IDs match
3. Check customer portal access via `createPortalSession`

---

## 4. Database Recovery from Backups

Swan Match has automated daily backups via the `scheduledFirestoreBackup` Cloud Function.

### Backup Location
```
gs://swan-match.firebasestorage.app/firestore-backups/
```

### Check Latest Backup
```bash
gsutil ls -la gs://swan-match.firebasestorage.app/firestore-backups/ | tail -5
```

### Restore from Backup
```bash
# List available backups
gcloud firestore operations list --project swan-match

# Import a specific backup
gcloud firestore import gs://swan-match.firebasestorage.app/firestore-backups/YYYY-MM-DD \
  --project swan-match
```

> ⚠️ **WARNING**: Importing replaces ALL data in the target collections. Consider importing to a separate database first for verification.

---

## 5. Communication Templates

### User-Facing (In-App or Social Media)
```
🔧 We're currently experiencing a temporary issue with [feature].
Our team is actively working on a fix. We apologize for the inconvenience
and expect to have this resolved within [timeframe].
```

### Team Notification
```
🚨 INCIDENT: [Brief description]
Severity: P[1/2/3]
Started: [time]
Impact: [what's affected]
Status: Investigating / Identified / Fixing / Monitoring / Resolved
Assignee: [name]
```

---

## 6. Contact Escalation Matrix

| Level | Who | When |
|-------|-----|------|
| L1 | On-call developer | Immediately |
| L2 | Project lead (Hari) | If not resolved in 15 min |
| L3 | Firebase Support | If infrastructure issue |
| L4 | Stripe Support | If payment system issue |

### Useful Links
- Firebase Console: https://console.firebase.google.com/project/swan-match
- Stripe Dashboard: https://dashboard.stripe.com
- Google Cloud Console: https://console.cloud.google.com/project/swan-match

---

## 7. Post-Incident Review Template

```markdown
## Incident Report — [Date]

### Summary
[One paragraph describing what happened]

### Timeline
- HH:MM — Issue detected
- HH:MM — Investigation started
- HH:MM — Root cause identified
- HH:MM — Fix applied
- HH:MM — Issue resolved

### Root Cause
[Technical explanation]

### Impact
- Duration: X hours
- Users affected: ~N
- Revenue impact: $X (if applicable)

### Action Items
- [ ] [Preventive measure 1]
- [ ] [Preventive measure 2]
- [ ] [Monitoring improvement]

### Lessons Learned
[What we'll do differently next time]
```
