/**
 * App Store / Google Play subscription entitlements.
 *
 * Two problems this module fixes:
 *  1. Ownership — a store purchase used to grant Premium to whichever account
 *     sent its transaction id (and the id is on the publicly readable profile),
 *     and auto-restore granted it to every account opened on the same phone.
 *     Each purchase is now CLAIMED once, in the server-only `iapClaims`
 *     collection, by the account that first verified it.
 *  2. Expiry — nothing ever downgraded a cancelled, lapsed or refunded store
 *     subscription. refreshDueIapSubscriptions() re-checks subscriptions near
 *     or past the end of their paid period with Apple / Google and either
 *     extends them (renewed) or downgrades them to free.
 *
 * Store API calls are injected (`verify`) so the logic is testable without
 * real Apple / Google credentials.
 */
const crypto = require('crypto');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');

const CLAIMS = 'iapClaims';
// How long after the paid period ends access is kept while the store is
// retrying a payment / the periodic check hasn't run yet.
const EXPIRY_GRACE_MS = 3 * 24 * 60 * 60 * 1000;
// Re-check subscriptions whose paid period ends within this window, so
// renewals are recorded before the app's own expiry check kicks in.
const REFRESH_AHEAD_MS = 36 * 60 * 60 * 1000;

/** Apple subscription status codes that still grant access. */
function appleStatusEntitled(status) {
  // 1 = active, 4 = billing grace period. 2 expired, 3 billing retry, 5 revoked.
  return status === 1 || status === 4;
}

/** Stable key for a purchase (never changes across renewals). */
function claimKeyFor(source, { originalTransactionId, transactionId, purchaseToken }) {
  if (source === 'app_store') {
    const id = originalTransactionId || transactionId;
    return id ? `apple_${id}` : null;
  }
  if (source === 'google_play') {
    return purchaseToken
      ? `google_${crypto.createHash('sha256').update(purchaseToken).digest('hex')}`
      : null;
  }
  return null;
}

class PurchaseOwnedByAnotherAccount extends Error {}

/**
 * Claims [key] for [uid] (transactional). Throws PurchaseOwnedByAnotherAccount
 * if another account already owns it — either via an existing claim or, for
 * purchases granted before claims existed, via its iapTransactionId on
 * another user's profile.
 */
async function claimPurchase(db, {
  uid, key, source, productId, transactionId = null, originalTransactionId = null,
  purchaseToken = null, expiresMs = null,
}) {
  const ref = db.collection(CLAIMS).doc(key);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists && snap.get('uid') !== uid) {
      throw new PurchaseOwnedByAnotherAccount();
    }
    if (!snap.exists && transactionId) {
      // Legacy grant (before claims): whoever already holds this transaction
      // on their profile owns it.
      const holders = await tx.get(
        db.collection('users').where('iapTransactionId', '==', transactionId).limit(5),
      );
      if (holders.docs.some((d) => d.id !== uid)) {
        throw new PurchaseOwnedByAnotherAccount();
      }
    }
    const data = {
      uid,
      source,
      productId: productId || null,
      status: 'active',
      lastVerifiedAt: FieldValue.serverTimestamp(),
    };
    if (originalTransactionId) data.originalTransactionId = originalTransactionId;
    if (transactionId) data.lastTransactionId = transactionId;
    if (purchaseToken) data.purchaseToken = purchaseToken;
    if (expiresMs && Number.isFinite(expiresMs)) data.expiresAt = Timestamp.fromMillis(expiresMs);
    if (!snap.exists) data.createdAt = FieldValue.serverTimestamp();
    tx.set(ref, data, { merge: true });
  });
}

/** Whether the profile still points at the purchase behind [claimKey]. */
function userUsesClaim(user, claimKey, claim) {
  if (!user) return false;
  if (user.iapClaimKey) return user.iapClaimKey === claimKey;
  // Legacy profile (granted before claims): match on the transaction id.
  return !!claim.lastTransactionId && user.iapTransactionId === claim.lastTransactionId;
}

function hasActiveStripe(user) {
  const status = String(user.subscriptionStatus || '').toLowerCase();
  return !!user.stripeSubscriptionId && (status === 'active' || status === 'trialing');
}

/**
 * Applies a fresh store check to one claim + its user.
 * verdict: { checked, entitled, expiresMs, productId?, planName?, planPeriod? }
 * Returns 'renewed' | 'expired' | 'skipped'.
 */
async function applyVerdict(db, claimRef, claim, verdict, nowMs) {
  if (!verdict || !verdict.checked) return 'skipped'; // store unreachable — try later
  const userRef = db.collection('users').doc(claim.uid);
  const userSnap = await userRef.get();
  const user = userSnap.exists ? userSnap.data() : null;
  const linked = userUsesClaim(user, claimRef.id, claim);

  if (verdict.entitled && verdict.expiresMs && verdict.expiresMs > nowMs) {
    await claimRef.set({
      status: 'active',
      expiresAt: Timestamp.fromMillis(verdict.expiresMs),
      lastVerifiedAt: FieldValue.serverTimestamp(),
      ...(verdict.productId ? { productId: verdict.productId } : {}),
    }, { merge: true });
    if (linked) {
      await userRef.update({
        subscriptionPlan: 'premium',
        subscriptionStatus: 'active',
        billingPeriodEnd: Timestamp.fromMillis(verdict.expiresMs),
        iapClaimKey: claimRef.id,
        updatedAt: FieldValue.serverTimestamp(),
        ...(verdict.planName ? { subscriptionName: verdict.planName } : {}),
        ...(verdict.planPeriod ? { subscriptionPeriod: verdict.planPeriod } : {}),
      });
    }
    return 'renewed';
  }

  await claimRef.set({
    status: 'expired',
    lastVerifiedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  if (linked && !hasActiveStripe(user)) {
    await userRef.update({
      subscriptionPlan: 'free',
      subscriptionStatus: 'expired',
      cancelAtPeriodEnd: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  return 'expired';
}

/**
 * Periodic job body. `verify(source, ids)` → verdict (see applyVerdict).
 *  A) claims whose paid period ends soon or has ended;
 *  B) legacy App Store grants (before claims) near/after their end — these are
 *     claimed for the account that holds them, then handled like A.
 */
async function refreshDueIapSubscriptions(db, verify, nowMs = Date.now(), limit = 300) {
  const cutoff = Timestamp.fromMillis(nowMs + REFRESH_AHEAD_MS);
  const stats = { renewed: 0, expired: 0, skipped: 0, legacyClaimed: 0 };

  const due = await db.collection(CLAIMS)
    .where('expiresAt', '<=', cutoff)
    .orderBy('expiresAt')
    .limit(limit)
    .get();
  for (const doc of due.docs) {
    const claim = doc.data();
    if (claim.status !== 'active') continue;
    const verdict = await verify(claim.source, {
      originalTransactionId: claim.originalTransactionId,
      transactionId: claim.lastTransactionId,
      purchaseToken: claim.purchaseToken,
    });
    stats[await applyVerdict(db, doc.ref, claim, verdict, nowMs)]++;
  }

  const legacy = await db.collection('users')
    .where('billingPeriodEnd', '<=', cutoff)
    .orderBy('billingPeriodEnd')
    .limit(limit)
    .get();
  for (const doc of legacy.docs) {
    const u = doc.data();
    if (u.iapClaimKey || u.iapSource !== 'app_store' || !u.iapTransactionId) continue;
    if (String(u.subscriptionStatus || '').toLowerCase() !== 'active' || hasActiveStripe(u)) continue;
    const verdict = await verify('app_store', { transactionId: u.iapTransactionId });
    if (!verdict || !verdict.checked) { stats.skipped++; continue; }
    const key = claimKeyFor('app_store', {
      originalTransactionId: verdict.originalTransactionId,
      transactionId: u.iapTransactionId,
    });
    const claimRef = db.collection(CLAIMS).doc(key);
    const existing = await claimRef.get();
    if (existing.exists && existing.get('uid') !== doc.id) continue; // owned elsewhere
    const claim = {
      uid: doc.id,
      source: 'app_store',
      productId: u.iapProductId || null,
      lastTransactionId: u.iapTransactionId,
      status: 'active',
      ...(verdict.originalTransactionId ? { originalTransactionId: verdict.originalTransactionId } : {}),
    };
    await claimRef.set({ ...claim, createdAt: FieldValue.serverTimestamp() }, { merge: true });
    await doc.ref.update({ iapClaimKey: key });
    stats.legacyClaimed++;
    stats[await applyVerdict(db, claimRef, claim, verdict, nowMs)]++;
  }
  return stats;
}

/**
 * Server-side counterpart of the app's expiry rule: a store (non-Stripe)
 * subscription whose paid period ended more than EXPIRY_GRACE_MS ago no
 * longer counts as Premium, even before the periodic job has run.
 */
function storeSubscriptionLapsed(userData, nowMs = Date.now()) {
  if (!userData) return false;
  if (userData.stripeSubscriptionId) return false;
  if (!userData.iapSource && !userData.iapProductId) return false;
  const end = userData.billingPeriodEnd;
  if (!end || typeof end.toMillis !== 'function') return false;
  return end.toMillis() + EXPIRY_GRACE_MS < nowMs;
}

module.exports = {
  CLAIMS,
  EXPIRY_GRACE_MS,
  REFRESH_AHEAD_MS,
  appleStatusEntitled,
  claimKeyFor,
  claimPurchase,
  PurchaseOwnedByAnotherAccount,
  applyVerdict,
  refreshDueIapSubscriptions,
  storeSubscriptionLapsed,
};
