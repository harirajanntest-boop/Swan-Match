# Swan Match — Moderation Standard Operating Procedures (SOP)

**Version:** 1.0
**Last Updated:** May 2025
**Audience:** Support Admins, Verification Admins, Super Admins

---

## 1. Role Permissions Overview

| Role | Reports | Verification Queue | Appeals | Suspend/Warn | Escalate | Process Refunds |
|------|---------|-------------------|---------|-------------|----------|----------------|
| **Super Admin** | ✅ | ✅ | ✅ | ✅ | N/A (final authority) | ✅ |
| **Support Admin** | ✅ | ✅ | ✅ | ✅ | ✅ (to Super Admin) | ❌ |
| **Verification Admin** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Finance Admin** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 2. Priority Matrix (P1 / P2 / P3)

When a user files a report, the system auto-assigns a priority based on the report category. Here is what each means and the expected response time:

### P1 — Critical (Red, Pulsing Badge)
**Response Target:** Within 15 minutes during business hours

| Category | Examples |
|----------|---------|
| Harassment / Threats | Death threats, blackmail, extortion, stalking |
| Underage User | User appears or claims to be under 18 |

**Action:** Immediately suspend the reported account. Do NOT dismiss without Super Admin review.

### P2 — High (Orange Badge)
**Response Target:** Within 2 hours

| Category | Examples |
|----------|---------|
| Fake Profile / Catfish | Stolen photos, AI-generated images, impersonation |
| Scam / Fraud | Asking for money, crypto scams, phishing links |
| Inappropriate Content | Explicit photos, offensive bio content |

**Action:** Review evidence, then Warn or Suspend depending on severity.

### P3 — General (Blue Badge)
**Response Target:** Within 24 hours

| Category | Examples |
|----------|---------|
| Spam / Solicitation | Promoting products, escort services, repetitive messages |
| Other | Minor annoyances, profile disagreements |

**Action:** Review and Warn. Dismiss if no violation found.

---

## 3. Report Handling Workflow

### Step-by-Step Process

```
1. Open the Reports & Safety page
2. Reports are sorted: P1 first, then P2, then P3, then by date
3. Click the user's name to view their full profile
4. If a 💬 message icon appears, click it to review chat evidence
5. Choose an action:
   → ⚠️ Warn     — Sends warning notification to the user
   → 🚫 Suspend  — Suspends account + notifies reporter
   → ⬆️ Escalate — Sends to Super Admin (Support Admins only)
   → ✅ Dismiss   — Clears report + notifies reporter
```

### When to Use Each Action

| Action | When to Use | What Happens |
|--------|------------|-------------|
| **Warn** | First offense, minor violation, no safety risk | User gets in-app warning. Reporter notified that action was taken. Report auto-closed. |
| **Suspend** | Serious violation, repeat offender, safety risk | Account locked. User notified. Reporter notified. Report auto-closed. Profile hidden from all feeds. |
| **Escalate** | You're unsure, legal implications, or P1 category | Report status changes to "Escalated". Only Super Admin can act on it. |
| **Dismiss** | No violation found after review | Reporter notified with explanation. `isReported` flag cleared from user profile. |

---

## 4. Chat Evidence Review Guidelines

When the 💬 icon appears on a report, the system has archived the **last 50 messages** from the conversation between reporter and reported user.

### What to Look For

| Red Flag | Action |
|----------|--------|
| Direct threats of violence or harm | **P1 → Immediate Suspend** |
| Sexual harassment or explicit messages | **Suspend** |
| Requests for money, gift cards, crypto | **Suspend** (Scam) |
| Sharing personal info (address, workplace) of others | **Warn** first offense, **Suspend** if repeated |
| Rude but not threatening language | **Warn** |
| Normal conversation, reporter is oversensitive | **Dismiss** |

### Important Notes
- Chat evidence is **permanently archived** in the report document — it persists even if the chat is deleted
- The left side (darker bubbles) = reporter's messages
- The right side (gold-tinted bubbles) = reported user's messages
- Timestamps are shown below each message

---

## 5. Verification Queue SOP

### Profile Approval Process

```
1. Open Verification Queue page
2. Review the user's:
   → Profile photos (are they real, appropriate?)
   → Selfie verification (does it match the profile photos?)
   → ID document (is it a valid government ID?)
   → Bio and name (any prohibited content?)
3. Approve or Reject:
   → Approve: Profile becomes visible in swipe feeds
   → Reject: User notified to re-upload. Profile stays hidden.
```

### Rejection Reasons
- Photos are blurry, group photos, or clearly stolen
- Selfie doesn't match profile photos
- ID document is unreadable, expired, or doesn't match
- Bio contains prohibited content (escort, spam, explicit)
- User appears underage (escalate to Super Admin as P1)

### Auto-Moderation Rules (System-Enforced)
- Profiles with `profileApprovalStatus != 'approved'` are **hidden from all feeds**
- Profiles below **60% completion** are hidden from feeds
- Users with **3+ reports** are **auto-suspended** by the system
- Suspended accounts are hidden from all feeds

---

## 6. Appeals Handling

When a suspended user submits an appeal:

```
1. Open the Appeals page
2. Review the original suspension reason
3. Check the user's report history and chat evidence
4. Decision:
   → Approve: Account reactivated, status set to Active
   → Reject: Suspension upheld, no change
```

### Guidelines
- **Approve** if: First offense, minor violation, user shows understanding
- **Reject** if: Repeat offender, serious violation, evidence is clear
- **Always document** the reason for your decision
- Appeals for **P1 categories** (threats, underage) should only be handled by **Super Admin**

---

## 7. Escalation Procedures

### When to Escalate

| Situation | Escalate To |
|-----------|------------|
| P1 report (threats, underage) and you're Support Admin | Super Admin |
| Legal implications (real threats, law enforcement needed) | Super Admin → External legal |
| Chargeback dispute (auto-flagged by system) | Super Admin / Finance Admin |
| You're unsure about the right action | Super Admin |
| User is a high-profile or verified account | Super Admin |

### How to Escalate
1. Click the ⬆️ Escalate button on the report
2. Report status changes to "Escalated" (gold pulsing badge)
3. The report will show "Awaiting Super Admin" for non-Super Admin users
4. **Do NOT take any other action** after escalating — wait for Super Admin

---

## 8. Subscription Abuse & Chargeback Flags

### Warning Banners in User Profile Review

| Banner | Color | Meaning |
|--------|-------|---------|
| **⚠️ Subscription Abuse Detected** | Orange | System flagged this user for subscription manipulation (e.g., repeated free trial abuse) |
| **⚠️ Suspicious Account Activity** | Yellow | System detected unusual behavior (shared device ID, rapid profile changes) |
| **Chargeback Flag** | Red (in user data) | User filed a Stripe chargeback — account was auto-suspended by system |

### Actions for Flagged Users
- **Subscription Abuse:** Review payment history. If confirmed, keep suspended. If false positive, clear the flag.
- **Suspicious Account:** Check if it's a duplicate account (shared device ID). If confirmed duplicate, suspend the newer account.
- **Chargeback:** These are auto-suspended. Do NOT unsuspend without Super Admin + Finance Admin approval.

---

## 9. Refund Processing (Super Admin Only)

When a support ticket mentions "refund":

```
1. Open Support Queries page
2. Click on the ticket
3. The 💳 Process Refund button appears at the bottom
4. Click it → Confirmation dialog appears
5. Confirm → System calls processRefund Cloud Function
6. User's Stripe subscription is refunded
```

### Refund Guidelines
- Only process refunds for **billing errors** or **service issues**
- Do NOT refund users who were **suspended for violations**
- Do NOT refund **chargeback** cases (Stripe handles those)
- All refunds are logged in the **Audit Logs** page

---

## 10. Audit Logs

Every admin action is logged in the **Audit Logs** page (Super Admin only):

| What's Logged | Example |
|--------------|---------|
| User suspensions | "Suspended user X for harassment" |
| Chargeback auto-suspensions | "System auto-suspended user X due to chargeback" |
| Refund processing | "Processed refund for user X" |
| Appeal decisions | "Approved appeal for user X" |
| Report actions | "Warned user X, dismissed report" |

Use audit logs to:
- Track who did what and when
- Review moderator performance
- Investigate disputes about admin actions
- Provide evidence for legal requests

---

## 11. Do's and Don'ts

### ✅ Do
- Always review chat evidence before taking action
- Respond to P1 reports immediately
- Document your reasoning when taking action
- Escalate when in doubt
- Notify reporters about the outcome
- Check user's report history before deciding

### ❌ Don't
- Don't dismiss P1 reports without Super Admin review
- Don't suspend without reviewing evidence first
- Don't share user data outside the admin panel
- Don't unsuspend chargeback cases without Finance Admin approval
- Don't take action on escalated reports (wait for Super Admin)
- Don't process refunds for suspended violators

---

## 12. Quick Reference Card

```
┌─────────────────────────────────────────────────┐
│           MODERATION QUICK REFERENCE            │
├─────────────────────────────────────────────────┤
│                                                 │
│  P1 (Critical) → Suspend immediately            │
│  P2 (High)     → Review evidence → Warn/Suspend │
│  P3 (General)  → Review → Warn/Dismiss          │
│                                                 │
│  💬 = Chat evidence available (click to view)    │
│  ⚠️  = Warn user                                │
│  🚫 = Suspend account                           │
│  ⬆️  = Escalate to Super Admin                  │
│  ✅ = Dismiss (no violation)                     │
│  💳 = Process refund (support tickets)           │
│                                                 │
│  3 reports = auto-suspend (system)              │
│  Chargeback = auto-suspend (system)             │
│                                                 │
│  NEVER dismiss P1 without Super Admin review    │
│  ALWAYS check chat evidence if available        │
│  ALWAYS escalate if unsure                      │
│                                                 │
└─────────────────────────────────────────────────┘
```
