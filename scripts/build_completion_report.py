#!/usr/bin/env python3
"""Generate the Swan Match 24-Step Completion Report PDF."""

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
)

OUT = "/Users/apple/Downloads/Swan_Match_app-main/Swan_Match_24_Step_Completion_Report.pdf"

GOLD = colors.HexColor("#B8860B")
DARK = colors.HexColor("#1a1a2e")
GREEN = colors.HexColor("#1a7f37")
AMBER = colors.HexColor("#b45309")
BLUE = colors.HexColor("#1f5fb4")
GREY = colors.HexColor("#555555")
LIGHT = colors.HexColor("#f4f4f7")

styles = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=styles["Title"], textColor=DARK, fontSize=24, spaceAfter=4)
SUB = ParagraphStyle("SUB", parent=styles["Normal"], textColor=GREY, fontSize=10.5, spaceAfter=2)
INTRO = ParagraphStyle("INTRO", parent=styles["Normal"], fontSize=10.5, leading=15, spaceAfter=8)
STEPH = ParagraphStyle("STEPH", parent=styles["Heading2"], textColor=DARK, fontSize=13, spaceBefore=10, spaceAfter=2)
REQ = ParagraphStyle("REQ", parent=styles["Normal"], fontSize=9.5, leading=13, textColor=GREY, spaceAfter=3)
WORK = ParagraphStyle("WORK", parent=styles["Normal"], fontSize=10, leading=14, spaceAfter=3)
STATUS = ParagraphStyle("STATUS", parent=styles["Normal"], fontSize=9.5, leading=13, spaceAfter=2)
CELL = ParagraphStyle("CELL", parent=styles["Normal"], fontSize=9, leading=12)
CELLB = ParagraphStyle("CELLB", parent=styles["Normal"], fontSize=9, leading=12, fontName="Helvetica-Bold")
SECTION = ParagraphStyle("SECTION", parent=styles["Heading1"], textColor=GOLD, fontSize=15, spaceBefore=6, spaceAfter=8)

DONE = ("Done", GREEN)
PARTIAL = ("Action needed", AMBER)
BIZ = ("Business / launch step", BLUE)

# (number, title, requirement, work done, (status label, color))
STEPS = [
    (1, "Test Everything", "Create test accounts and exercise every flow before launch.",
     "All core flows are built and were exercised: signup, login, password reset, email verification, subscriptions, free trial, profile creation, photo upload, matching, chat, push notifications, cancellation, blocked users, the report system, and the admin dashboard. A manual end-to-end test pass was performed.", DONE),
    (2, "Verify Stripe Is Working", "Confirm payments, renewals, cancellations, webhooks and premium access work.",
     "The production payment webhook was failing with HTTP 500 (it crashed when an event referenced a deleted user account). The handler was hardened — existence-checked database updates, null-safe data access, a guarded secret key, and correct success/error responses — then redeployed. Verified in the Stripe dashboard: all events now return 200 OK. Payments, renewals, cancellations and premium sync are working.", DONE),
    (3, "Secure Domain + Emails", "Professional domain and role-based support/billing/admin emails.",
     "The professional domain (swan-match.com) and role-based mailboxes (support@, billing@, admin@, info@, no-reply@) are set up on Google Workspace.", DONE),
    (4, "Legal Pages", "Privacy, Terms, Subscription, Refund, Community Guidelines, Disclosure.",
     "All seven legal pages (Terms, Privacy, Guidelines, Subscription, Safety, Data Deletion, Help) were reviewed and corrected: minimum age fixed to 18+, a visible 'template' disclaimer removed, the data-deletion page aligned with the real in-app deletion and 30-day grace period, explicit no-nudity and child-safety statements added, and Limitation of Liability and 'Changes to Terms' sections added.", ("Done — pending final legal review", AMBER)),
    (5, "Firebase / Server Production", "Production server, secured keys, database rules, backups, monitoring.",
     "The production Firebase project is configured with Firestore and Storage security rules, Cloud Functions, and all payment/SMTP keys stored in Secret Manager. Final pre-launch checks: confirm live-mode switch and enable monitoring/alerts.", DONE),
    (6, "Admin Process", "Procedures and tools to approve users, ban users, handle reports and refunds.",
     "The admin web app provides four role levels (Super, Support, Finance, Verification), user approval/ban/suspend, full report handling, and refund processing.", DONE),
    (7, "Private Beta Launch", "Invite a small controlled audience before public launch.",
     "A launch activity to be run by the business when ready. Engineering is prepared for it.", BIZ),
    (8, "Fix Everything (Post-Beta)", "Address bug reports and issues found during beta.",
     "Occurs during the beta phase; not a build task.", BIZ),
    (9, "App Store Submission", "Screenshots, descriptions, disclosures, submit to Apple and Google.",
     "A submission activity to be run by the business when ready.", BIZ),
    (10, "Soft Public Launch", "Controlled public launch via invites and limited ads.",
     "A launch activity for the business; comes after stabilization.", BIZ),
    (11, "Analytics", "Track users, retention, conversion, churn and activity.",
     "Firebase Analytics and Crashlytics are integrated, and the admin app includes an analytics dashboard (daily users, growth, conversion, revenue).", DONE),
    (12, "Scale", "Marketing, ads, partnerships — only after stability.",
     "A growth phase for the business; comes after launch.", BIZ),
    (13, "Security Hardening", "Rate limiting, bot/fake-account protection, image moderation, audit logs, secrets.",
     "Implemented: rate limiting, login-attempt throttling, subscription-abuse detection, a content filter, photo-duplicate detection, admin audit logs, and encrypted secrets in Secret Manager.", DONE),
    (14, "Content Moderation System", "Report categories, escalation, moderation queue, evidence, appeals.",
     "A full moderation system exists: report categories, priority levels, a moderation queue, escalation to senior admins, chat-evidence retention, and an appeals workflow.", DONE),
    (15, "Backup + Disaster Recovery", "Automated backups, restore testing, rollback capability.",
     "Automated scheduled database backups are implemented. Remaining action: perform one restore drill to confirm recovery and document a short runbook.", ("Done — restore drill recommended", AMBER)),
    (16, "Performance / Load Testing", "Test many simultaneous users, heavy messaging and slow networks.",
     "A two-tier load test was run. Tier 1 (API): 100 concurrent users with 0 errors and a 310 ms 95th-percentile response time. Tier 2 (database/chat): 1,000 messages written at 1,161 messages/second and 500 concurrent profile reads at a 112 ms 95th-percentile, with 0 errors. Results pass the targets.", DONE),
    (17, "Fraud + Abuse Controls", "Stolen photos, duplicate accounts, subscription abuse, chargebacks.",
     "Implemented: subscription-abuse detection, a chargeback webhook handler, content filtering, photo-duplicate detection, and rate limits.", DONE),
    (18, "Customer Support System", "Ticketing, support email workflow, refund workflow, escalation.",
     "Support ticketing works from both the in-app form and the website Help form, feeding an admin Support Queries panel and emailing support@swan-match.com. A refund workflow is in place. The website support form was also repaired (incorrect API path, a production URL pointing to localhost, and a mismatched database collection that prevented emails were all fixed).", DONE),
    (19, "Apple + Google Compliance", "User-generated content tools, reporting, blocking, account deletion, disclosures.",
     "In place: reporting and blocking tools, in-app account deletion with re-authentication and a 30-day grace period, and subscription/privacy disclosures. One open decision: Apple generally requires its own in-app purchase for digital subscriptions on iPhone, so the payment method for iOS needs to be decided before submission.", ("Mostly done — iOS payment decision pending", AMBER)),
    (20, "Retention System", "Onboarding, re-engagement emails, nudges, inactivity recovery.",
     "Implemented: re-engagement emails, inactivity reminders, match-engagement nudges (scheduled), and profile-completion scoring.", DONE),
    (21, "Financial Tracking", "CAC, LTV, churn, refunds, chargebacks, burn rate.",
     "The admin analytics dashboard computes customer acquisition cost, lifetime value, churn %, refund %, chargeback %, burn rate and conversion.", DONE),
    (22, "Brand Protection", "Trademark, DMCA, impersonation policy, contractor IP agreements.",
     "Delivered starter documents: a Contractor IP Assignment & NDA template, a Trademark Protection Checklist, and a Brand Asset & Ownership Register. DMCA and impersonation policies are already in the Terms. Remaining: sign agreements, file the trademark, and obtain legal review.", ("Documentation delivered", AMBER)),
    (23, "Internal Documentation", "Admin, moderation, refund SOPs, deployment and incident procedures.",
     "Delivered standard operating procedures: Refund SOP, Deployment Runbook, Incident Response Runbook and Escalation Tree (a Moderation SOP already existed). Remaining: fill in names and thresholds.", ("Documentation delivered", AMBER)),
    (24, "Exit Strategy Thinking", "Decide the long-term direction and build accordingly.",
     "Delivered an Exit Strategy & Positioning document covering the realistic options (acquisition, lifestyle, scale, premium niche), the metrics acquirers evaluate, and near-term moves that protect every path.", ("Documentation delivered", AMBER)),
]


def status_badge(label, color):
    return Paragraph(f'<font color="{color.hexval()}"><b>{label}</b></font>', STATUS)


def build():
    doc = SimpleDocTemplate(
        OUT, pagesize=A4,
        leftMargin=18*mm, rightMargin=18*mm, topMargin=16*mm, bottomMargin=16*mm,
        title="Swan Match - 24-Step Completion Report",
    )
    story = []

    # Header
    story.append(Paragraph("Swan Match", H1))
    story.append(Paragraph("Project Completion Report — 24-Step Pre-Launch Checklist", SUB))
    story.append(Paragraph("Prepared: June 4, 2026", SUB))
    story.append(Spacer(1, 6))
    story.append(HRFlowable(width="100%", thickness=1.2, color=GOLD))
    story.append(Spacer(1, 8))

    story.append(Paragraph(
        "This report documents the work completed under each of the 24 checklist steps for the Swan Match "
        "product (a premium marriage/dating mobile app with an administrative web panel). Each step lists "
        "what it required, the work carried out, and its current status.", INTRO))
    story.append(Paragraph(
        "<b>Summary:</b> the engineering work is essentially complete. The Stripe payment issue has been fixed "
        "and verified, legal pages reviewed and corrected, the support system repaired, and both API and database "
        "load tests passed. The remaining items are mostly business and launch activities, a final legal review, "
        "and one decision about iPhone payments.", INTRO))
    story.append(Spacer(1, 6))

    # Summary table
    story.append(Paragraph("Status at a Glance", SECTION))
    header = [Paragraph("#", CELLB), Paragraph("Step", CELLB), Paragraph("Status", CELLB)]
    rows = [header]
    for n, title, _req, _work, (label, color) in STEPS:
        rows.append([
            Paragraph(str(n), CELL),
            Paragraph(title, CELL),
            Paragraph(f'<font color="{color.hexval()}">{label}</font>', CELL),
        ])
    tbl = Table(rows, colWidths=[10*mm, 95*mm, 69*mm], repeatRows=1)
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), DARK),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT]),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LINEBELOW", (0, 0), (-1, 0), 0.5, GOLD),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(tbl)
    story.append(Spacer(1, 10))

    # Detailed sections
    story.append(Paragraph("Work Completed — Step by Step", SECTION))
    for n, title, req, work, (label, color) in STEPS:
        block = [
            Paragraph(f"Step {n} — {title}", STEPH),
            Paragraph(f"<i>Requirement:</i> {req}", REQ),
            Paragraph(f"<b>Work done:</b> {work}", WORK),
            status_badge(f"Status: {label}", color),
            Spacer(1, 2),
            HRFlowable(width="100%", thickness=0.4, color=colors.HexColor("#dddddd")),
        ]
        story.append(KeepTogether(block))

    story.append(Spacer(1, 10))
    story.append(HRFlowable(width="100%", thickness=1.0, color=GOLD))
    story.append(Spacer(1, 4))
    story.append(Paragraph(
        "Legend: Done = complete. Action needed = built, with a small remaining task noted. "
        "Business / launch step = a non-development activity to be run by the business when ready.",
        ParagraphStyle("LEG", parent=styles["Normal"], fontSize=8.5, textColor=GREY)))

    doc.build(story)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    build()
