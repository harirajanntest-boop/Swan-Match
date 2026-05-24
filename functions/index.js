const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();

/** Collect FCM tokens from fcmTokens array and legacy fcmToken field. */
function collectFcmTokens(userData) {
  if (!userData) return [];
  const tokens = new Set();
  if (Array.isArray(userData.fcmTokens)) {
    for (const t of userData.fcmTokens) {
      if (t && typeof t === 'string' && t.trim()) tokens.add(t.trim());
    }
  }
  const legacy = userData.fcmToken;
  if (legacy && typeof legacy === 'string' && legacy.trim()) {
    tokens.add(legacy.trim());
  }
  return [...tokens];
}

exports.onNotificationCreated = onDocumentCreated('notifications/{docId}', async (event) => {
  const notificationDetails = event.data?.data();
  if (!notificationDetails) {
    console.log('[onNotificationCreated] No data in event');
    return;
  }

  const toUserId = notificationDetails.toUserId;
  const fromUserId = notificationDetails.fromUserId;
  const title = notificationDetails.title || 'New Notification';
  const message = notificationDetails.message || '';

  console.log(`[onNotificationCreated] to=${toUserId}, from=${fromUserId}, title=${title}`);

  // Prevent sending notification to the sender
  if (!toUserId || toUserId === fromUserId) {
    console.log('[onNotificationCreated] Skipping: same sender/receiver or no toUserId');
    return;
  }

  try {
    // 1. Fetch user data to get FCM tokens
    const userSnapshot = await admin.firestore().collection('users').doc(toUserId).get();

    if (!userSnapshot.exists) {
      console.log(`[onNotificationCreated] User ${toUserId} does not exist`);
      return;
    }

    const userData = userSnapshot.data();
    const fcmTokens = collectFcmTokens(userData);
    console.log(`[onNotificationCreated] Found ${fcmTokens.length} FCM tokens for ${toUserId}`);

    if (fcmTokens.length === 0) {
      console.log(`[onNotificationCreated] User ${toUserId} has no FCM tokens`);
      return;
    }

    // 2. Send one notification per token (v9 Admin SDK pattern)
    const sendPromises = fcmTokens.map(token =>
      admin.messaging().send({
        token,
        notification: { title, body: message },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          title,
          body: message,
          fromUserId: fromUserId || '',
          type: notificationDetails.type || 'general',
        },
        android: {
          priority: 'high',
          notification: { channelId: 'high_importance_channel', sound: 'default' },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      }).catch(err => {
        console.error(`[onNotificationCreated] Failed for token ${token.substring(0, 20)}...: ${err.message}`);
        return null;
      })
    );

    const results = await Promise.all(sendPromises);
    const successCount = results.filter(r => r !== null).length;
    console.log(`[onNotificationCreated] Sent ${successCount}/${fcmTokens.length} notifications`);

    // 3. Clean up invalid tokens
    const invalidTokens = fcmTokens.filter((_, i) => results[i] === null);
    if (invalidTokens.length > 0) {
      console.log(`[onNotificationCreated] Removing ${invalidTokens.length} invalid tokens`);
      await admin.firestore().collection('users').doc(toUserId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)
      });
    }
  } catch (error) {
    console.error('[onNotificationCreated] Fatal error:', error.message, error.code);
  }
});

exports.onMessageCreated = onDocumentCreated('chats/{chatId}/messages/{messageId}', async (event) => {
  const messageDetails = event.data?.data();
  if (!messageDetails) {
    console.log('[onMessageCreated] No message data');
    return;
  }

  const receiverId = messageDetails.receiverId || messageDetails.toUserId;
  const senderId = messageDetails.senderId;
  let senderName = messageDetails.senderName || '';
  const messageText = messageDetails.text || messageDetails.message || '';
  const chatId = event.params.chatId;

  if (!senderName && senderId) {
    try {
      const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
      if (senderDoc.exists) {
        senderName = (senderDoc.data()?.name || senderDoc.data()?.firstName || '').toString().trim();
      }
    } catch (_) {
      /* use fallback below */
    }
  }
  if (!senderName) senderName = 'New message';

  console.log(`[onMessageCreated] chatId=${chatId}, from=${senderId}, to=${receiverId}, text=${messageText.substring(0, 30)}`);

  // Prevent sending notification to the sender
  if (!receiverId || receiverId === senderId) {
    console.log('[onMessageCreated] Skipping: self-message or no receiver');
    return;
  }

  try {
    const userSnapshot = await admin.firestore().collection('users').doc(receiverId).get();

    if (!userSnapshot.exists) {
      console.log(`[onMessageCreated] Receiver ${receiverId} not found in Firestore`);
      return;
    }

    const userData = userSnapshot.data();
    const fcmTokens = collectFcmTokens(userData);
    console.log(`[onMessageCreated] Found ${fcmTokens.length} tokens for receiver ${receiverId}`);

    if (fcmTokens.length === 0) {
      console.log(`[onMessageCreated] No FCM tokens for ${receiverId}`);
      return;
    }

    // Send one message per token for best compatibility
    const sendPromises = fcmTokens.map(token =>
      admin.messaging().send({
        token,
        notification: { title: senderName, body: messageText || '📩 New message' },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          type: 'chat',
          chatId: chatId || '',
          senderId: senderId || '',
          title: senderName,
          body: messageText || 'New message',
        },
        android: {
          priority: 'high',
          notification: { channelId: 'high_importance_channel', sound: 'default' },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } },
          headers: { 'apns-priority': '10' },
        },
      }).catch(err => {
        console.error(`[onMessageCreated] Failed for token ${token.substring(0, 20)}...: ${err.code} ${err.message}`);
        return null;
      })
    );

    const results = await Promise.all(sendPromises);
    const successCount = results.filter(r => r !== null).length;
    console.log(`[onMessageCreated] Sent ${successCount}/${fcmTokens.length} notifications successfully`);

    // Clean up invalid tokens
    const invalidTokens = fcmTokens.filter((_, i) => results[i] === null);
    if (invalidTokens.length > 0) {
      console.log(`[onMessageCreated] Removing ${invalidTokens.length} invalid tokens`);
      await admin.firestore().collection('users').doc(receiverId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)
      });
    }
  } catch (error) {
    console.error('[onMessageCreated] Fatal error:', error.message, error.code);
  }
});

const { onCall, HttpsError, onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

// 1. SECRETS
const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');
/** Monthly plan ($19.99) — set via: firebase functions:secrets:set STRIPE_PRICE_MONTHLY */
const stripePriceMonthly = defineSecret('STRIPE_PRICE_MONTHLY');
/** SMTP credentials for Nodemailer email sending — set via:
 *  firebase functions:secrets:set SMTP_USER
 *  firebase functions:secrets:set SMTP_PASS
 *  NOTE: These are optional. If not set, email functions will log a warning and skip.
 */

async function enforceRateLimit(uid, action, maxRequests, windowMs, key) {
  const rateKey = key || uid;
  if (!rateKey) return;
  const db = admin.firestore();
  const docRef = db.collection('_rateLimits').doc(`${rateKey}_${action}`);
  const now = Date.now();
  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);
    let data = doc.exists ? doc.data() : { timestamps: [] };
    let validTimestamps = (data.timestamps || []).filter(t => now - t < windowMs);
    if (validTimestamps.length >= maxRequests) {
      throw new HttpsError('resource-exhausted', 'Rate limit exceeded. Please try again later.');
    }
    validTimestamps.push(now);
    transaction.set(docRef, { timestamps: validTimestamps }, { merge: true });
  });
}

// 6-month / yearly IDs (Stripe Dashboard). Monthly is only in STRIPE_PRICE_MONTHLY secret.
const PREMIUM_PRICE_IDS_FIXED = {
  sixMonth: 'price_1TQBjHE3Rb5ApPY7CSk2jPPy',
  yearly: 'price_1TQBknE3Rb5ApPY7oldut4en',
};

/** Previous $19.00 monthly price — keep mapping for existing subscribers. */
const LEGACY_MONTHLY_PRICE_ID = 'price_1TKOrRE3Rb5ApPY7fOuscBJK';

function readPremiumPriceIds() {
  return {
    monthly: (stripePriceMonthly.value() || '').trim(),
    sixMonth: PREMIUM_PRICE_IDS_FIXED.sixMonth,
    yearly: PREMIUM_PRICE_IDS_FIXED.yearly,
  };
}

function isAllowedPremiumPriceId(priceId) {
  const ids = readPremiumPriceIds();
  if (!ids.monthly) return false;
  return priceId === ids.monthly || priceId === ids.sixMonth || priceId === ids.yearly;
}

/** Human-readable plan label for admin dashboard (subscriptionPlan stays premium/free/trial). */
function subscriptionNameFromPriceId(priceId) {
  if (!priceId || typeof priceId !== 'string') return null;
  const ids = readPremiumPriceIds();
  if (priceId === ids.monthly || priceId === LEGACY_MONTHLY_PRICE_ID) return 'Monthly';
  if (priceId === ids.sixMonth) return 'Six Month';
  if (priceId === ids.yearly) return 'Yearly';
  return null;
}

function attachSubscriptionName(updateData, priceId, isPremiumActive) {
  if (isPremiumActive && priceId) {
    const name = subscriptionNameFromPriceId(priceId);
    if (name) {
      updateData.subscriptionName = name;
      if (updateData.subscription && typeof updateData.subscription === 'object') {
        updateData.subscription.name = name;
      }
    }
  } else if (!isPremiumActive) {
    updateData.subscriptionName = admin.firestore.FieldValue.delete();
  }
  return updateData;
}

exports.checkPhoneExists = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  await enforceRateLimit(request.auth.uid, 'checkPhoneExists', 5, 60 * 1000); // 5 requests per minute

  const phoneNumber = request.data.phoneNumber;
  if (!phoneNumber) {
    throw new HttpsError('invalid-argument', 'The function must be called with one argument "phoneNumber" containing the phone number to check.');
  }

  try {
    const snapshot = await admin.firestore().collection('users').where('phoneNumber', '==', phoneNumber).limit(1).get();
    return { exists: !snapshot.empty };
  } catch (error) {
    console.error('Error checking phone existence:', error);
    throw new HttpsError('internal', 'Unable to verify phone number.');
  }
});

/**
 * Stripe - Create Checkout Session
 * Expected data: { priceId: string, successUrl: string, cancelUrl: string }
 */
exports.createCheckoutSession = onCall(
  { secrets: [stripeSecretKey, stripePriceMonthly] },
  async (request) => {
  // AUTH GUARD
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  await enforceRateLimit(request.auth.uid, 'createCheckout', 5, 60 * 1000); // 5 requests per minute

  const { priceId, successUrl, cancelUrl } = request.data;
  if (!priceId) {
    throw new HttpsError('invalid-argument', 'The function must be called with "priceId".');
  }

  if (!isAllowedPremiumPriceId(priceId)) {
    throw new HttpsError('invalid-argument', 'Invalid or unsupported subscription price.');
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email;

  console.log(`[createCheckoutSession] uid=${uid}, email=${email}, priceId=${priceId}`);
  console.log(`[createCheckoutSession] successUrl=${successUrl}, cancelUrl=${cancelUrl}`);

  // Validate secret exists
  const rawSecret = stripeSecretKey.value();
  if (!rawSecret) {
    console.error('[createCheckoutSession] STRIPE_SECRET_KEY secret is empty!');
    throw new HttpsError('internal', 'Payment service is not configured.');
  }

  const stripe = require('stripe')(rawSecret.trim());

  try {
    // Get or create Stripe customer
    const userRef = admin.firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();
    let stripeCustomerId = userDoc.exists ? userDoc.data()?.stripeCustomerId : null;

    if (!stripeCustomerId) {
      console.log(`[createCheckoutSession] Creating new Stripe customer for uid=${uid}`);
      const customer = await stripe.customers.create({
        email: email || `${uid}@swanmatch.app`,
        metadata: { firebaseUid: uid },
      });
      stripeCustomerId = customer.id;
      await userRef.set({ stripeCustomerId }, { merge: true });
      console.log(`[createCheckoutSession] Created Stripe customer: ${stripeCustomerId}`);
    } else {
      console.log(`[createCheckoutSession] Reusing Stripe customer: ${stripeCustomerId}`);
    }

    // Create Stripe Checkout Session
    console.log('[createCheckoutSession] Creating checkout session...');
    const session = await stripe.checkout.sessions.create({
      customer: stripeCustomerId,
      payment_method_types: ['card'],
      line_items: [{ price: priceId, quantity: 1 }],
      mode: 'subscription',
      success_url: successUrl,
      cancel_url: cancelUrl,
      client_reference_id: uid,
      metadata: { userId: uid },
    });

    console.log(`[createCheckoutSession] Session created: id=${session.id}, url=${session.url}`);
    return { sessionId: session.id, url: session.url };
  } catch (error) {
    console.error('[createCheckoutSession] Stripe error:', error.type, error.message, error.raw);
    throw new HttpsError('internal', `Stripe error: ${error.message}`);
  }
});

/**
 * Returns configured Stripe price IDs for the client (monthly from Firebase secret).
 */
exports.getSubscriptionPriceIds = onCall(
  { secrets: [stripePriceMonthly] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const ids = readPremiumPriceIds();
    if (!ids.monthly) {
      throw new HttpsError(
        'failed-precondition',
        'Monthly subscription price is not configured. Set STRIPE_PRICE_MONTHLY secret.'
      );
    }
    return ids;
  }
);

/**
 * Stripe - Webhook Handler
 */
exports.handleStripeWebhook = onRequest(
  {
    secrets: [stripeSecretKey, stripeWebhookSecret, stripePriceMonthly],
    rawBody: true, // Required for Stripe signature verification
  },
  async (req, res) => {
    // Debug logging
    console.log('=== WEBHOOK HIT ===');
    console.log('Method:', req.method);
    console.log('Has stripe-signature:', !!req.headers['stripe-signature']);
    console.log('Has rawBody:', !!req.rawBody);
    console.log('rawBody type:', typeof req.rawBody);
    console.log('Has webhookSecret:', !!stripeWebhookSecret.value());

    const sig = req.headers['stripe-signature'];
    const webhookSecretValue = stripeWebhookSecret.value();

    // 2. WEBHOOK SIGNATURE — Mandatory verification
    if (!webhookSecretValue) {
      console.error('STRIPE_WEBHOOK_SECRET is not configured.');
      return res.status(500).send('Webhook configuration missing.');
    }

    if (!sig) {
      console.error('Missing stripe-signature header.');
      return res.status(400).send('Missing stripe-signature header.');
    }

    const stripe = require('stripe')(stripeSecretKey.value().trim());
    let event;

    try {
      // 2. Use constructEvent with rawBody
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecretValue);
    } catch (err) {
      console.error('Webhook Signature Verify Failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    const db = admin.firestore();

    try {
      switch (event.type) {
        case 'checkout.session.completed': {
          const session = event.data.object;
          const uid = session.metadata.userId || session.client_reference_id;

          if (!uid) {
            console.error('No UID found in session metadata or client_reference_id');
            break;
          }

          // 3. IDEMPOTENCY
          const existingSession = await db.collection('users').where('lastCheckoutSessionId', '==', session.id).limit(1).get();
          if (!existingSession.empty) {
            console.log(`Checkout session ${session.id} already processed.`);
            return res.status(200).send('Session already processed.');
          }

          const updateData = {
            stripeCustomerId: session.customer,
            lastCheckoutSessionId: session.id,
            customerEmail: session.customer_details?.email,
            customerName: session.customer_details?.name,
            paymentStatus: session.payment_status,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          if (session.subscription) {
            updateData.stripeSubscriptionId = session.subscription;
          }

          await db.collection('users').doc(uid).update(updateData);
          break;
        }

        case 'customer.subscription.created':
        case 'customer.subscription.updated':
        case 'customer.subscription.deleted': {
          const subscription = event.data.object;
          const periodStart = subscription.current_period_start;
          const periodEnd = subscription.current_period_end;

          const priceId =
            subscription.items?.data?.[0]?.price?.id ??
            subscription.plan?.id ??
            null;

          const isPremiumActive =
            subscription.status === 'active' || subscription.status === 'trialing';

          const updateData = {
            subscriptionStatus: subscription.status,
            stripeSubscriptionId: subscription.id,
            subscriptionPlan: isPremiumActive ? 'premium' : 'free',
            cancelAtPeriodEnd: subscription.cancel_at_period_end ?? false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          if (priceId) {
            updateData.subscriptionPriceId = priceId;
            updateData.subscription = {
              status: subscription.status,
              priceId,
            };
          }
          attachSubscriptionName(updateData, priceId, isPremiumActive);

          if (subscription.status === 'active' || subscription.status === 'trialing') {
            updateData.freeTrialEndsAt = admin.firestore.FieldValue.delete();
            updateData.freeTrialStartedAt = admin.firestore.FieldValue.delete();
            updateData.trialEndedAt = admin.firestore.FieldValue.serverTimestamp();
            updateData.trialEndedReason = 'upgraded_to_premium';
          }

          // Only add timestamps if values exist and are valid integers
          if (periodStart && Number.isInteger(Number(periodStart))) {
            updateData.billingPeriodStart = admin.firestore.Timestamp.fromMillis(
              Number(periodStart) * 1000
            );
          }

          if (periodEnd && Number.isInteger(Number(periodEnd))) {
            updateData.billingPeriodEnd = admin.firestore.Timestamp.fromMillis(
              Number(periodEnd) * 1000
            );
          }

          const customer = await stripe.customers.retrieve(subscription.customer);
          const uid = customer.metadata?.userId || customer.metadata?.firebaseUid;

          if (uid) {
            await db.collection('users').doc(uid).update(updateData);
            console.log(`Subscription updated for uid=${uid} status=${subscription.status}`);
          } else {
            console.log('No uid found in customer metadata — skipping Firestore update');
          }
          break;
        }

        case 'invoice.paid': {
          const invoice = event.data.object;
          const customer = await stripe.customers.retrieve(invoice.customer);
          const uid = customer.metadata?.userId || customer.metadata?.firebaseUid;

          if (uid) {
            // 3. IDEMPOTENCY check for invoice
            const userDoc = await db.collection('users').doc(uid).get();
            if (userDoc.exists && userDoc.data().lastInvoiceId === invoice.id) {
              console.log(`Invoice ${invoice.id} already processed.`);
              return res.status(200).send('Invoice already processed.');
            }

            const invoicePriceId =
              invoice.lines?.data?.[0]?.price?.id ??
              invoice.lines?.data?.[0]?.plan?.id ??
              null;

            const invoiceUpdate = {
              paymentStatus: 'paid',
              subscriptionStatus: 'active',
              subscriptionPlan: 'premium',
              lastInvoiceId: invoice.id,
              lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
              freeTrialEndsAt: admin.firestore.FieldValue.delete(),
              freeTrialStartedAt: admin.firestore.FieldValue.delete(),
              trialEndedAt: admin.firestore.FieldValue.serverTimestamp(),
              trialEndedReason: 'upgraded_to_premium',
            };
            if (invoicePriceId) {
              invoiceUpdate.subscriptionPriceId = invoicePriceId;
              invoiceUpdate.subscription = {
                status: 'active',
                priceId: invoicePriceId,
              };
            }
            attachSubscriptionName(invoiceUpdate, invoicePriceId, true);

            await db.collection('users').doc(uid).update(invoiceUpdate);
          }
          break;
        }

        case 'invoice.payment_failed': {
          const invoice = event.data.object;
          const customer = await stripe.customers.retrieve(invoice.customer);
          const uid = customer.metadata?.userId || customer.metadata?.firebaseUid;

          if (uid) {
            await db.collection('users').doc(uid).update({
              paymentStatus: 'failed',
              subscriptionStatus: 'past_due',
              lastInvoiceId: invoice.id,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // 4. PAYMENT FAILED NOTIFICATION
            const userSnapshot = await db.collection('users').doc(uid).get();
            if (userSnapshot.exists) {
              const userData = userSnapshot.data();
              // Checking both array and single token fields for compatibility
              let fcmTokens = userData.fcmTokens || [];
              if (fcmTokens.length === 0 && userData.fcmToken) {
                fcmTokens = [userData.fcmToken];
              }

              if (fcmTokens.length > 0) {
                const message = {
                  notification: {
                    title: "Payment Failed",
                    body: "Please update your payment method to keep Swan Match Premium.",
                  },
                  tokens: fcmTokens,
                };
                await admin.messaging().sendEachForMulticast(message);
                console.log(`Payment failed notification sent to user ${uid}`);
              }
            }
          }
          break;
        }
      }
      res.json({ received: true });
    } catch (error) {
      console.error('Webhook Processing Error:', error);
      res.status(500).send('Webhook Processing Error');
    }
  });

/**
 * verifySubscription - Source of truth for premium status.
 * Queries Stripe API directly (not just stale Firestore) so this works
 * even when the webhook never fired (e.g. first purchase in test mode).
 * Also writes the authoritative status back to Firestore.
 */
exports.verifySubscription = onCall(
  { secrets: [stripeSecretKey, stripePriceMonthly] },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  await enforceRateLimit(request.auth.uid, 'verifySubscription', 10, 60 * 1000); // 10 requests per minute

  const uid = request.auth.uid;
  console.log(`[verifySubscription] Checking premium for uid=${uid}`);

  try {
    const db = admin.firestore();
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      return { isPremium: false, expiresAt: null };
    }

    const userData = userDoc.data();
    const stripeCustomerId = userData.stripeCustomerId;

    const clearInAppTrialFields = () => ({
      freeTrialEndsAt: admin.firestore.FieldValue.delete(),
      freeTrialStartedAt: admin.firestore.FieldValue.delete(),
      trialEndedAt: admin.firestore.FieldValue.serverTimestamp(),
      trialEndedReason: 'upgraded_to_premium',
    });

    const isInAppTrial =
      userData.subscriptionPlan === 'trial' &&
      userData.subscriptionStatus === 'trialing';

    // ── Fast path: no Stripe customer means no paid subscription ───────────
    if (!stripeCustomerId) {
      console.log(`[verifySubscription] No stripeCustomerId for uid=${uid}`);
      if (isInAppTrial) {
        return { isPremium: false, expiresAt: null };
      }
      const status = userData.subscriptionStatus;
      const plan = userData.subscriptionPlan;
      const isPremiumAdmin =
        (status === 'active' || status === 'trialing') &&
        (plan === 'premium' || plan === 'gold');
      return { isPremium: !!isPremiumAdmin, expiresAt: null };
    }

    // ── Query Stripe for active subscriptions ────────────────────────────────
    const rawSecret = stripeSecretKey.value();
    if (!rawSecret) {
      if (isInAppTrial) {
        return { isPremium: false, expiresAt: null };
      }
      // Fall back to Firestore if secret unavailable
      const status = userData.subscriptionStatus;
      const plan = userData.subscriptionPlan;
      const expiry = userData.billingPeriodEnd;
      const isPremium =
        (status === 'active' || status === 'trialing') &&
        (plan === 'premium' || plan === 'gold') &&
        (!expiry || expiry.toMillis() > Date.now());
      return { isPremium: !!isPremium, expiresAt: expiry ? expiry.toMillis() : null };
    }

    const stripe = require('stripe')(rawSecret.trim());
    const subscriptions = await stripe.subscriptions.list({
      customer: stripeCustomerId,
      status: 'all',
      limit: 5,
    });

    console.log(`[verifySubscription] Found ${subscriptions.data.length} subscriptions for ${stripeCustomerId}`);

    // Find the best active/trialing subscription
    let isPremium = false;
    let expiresAt = null;
    let bestSub = null;

    for (const sub of subscriptions.data) {
      console.log(`[verifySubscription] Sub id=${sub.id} status=${sub.status} end=${sub.current_period_end}`);
      if (sub.status === 'active' || sub.status === 'trialing') {
        isPremium = true;
        expiresAt = sub.current_period_end * 1000;
        bestSub = sub;
        break;
      }
    }

    // In-app free trial with no paid Stripe sub — do not overwrite Firestore.
    if (isInAppTrial && !isPremium) {
      console.log(`[verifySubscription] Preserving in-app trial for uid=${uid}`);
      return { isPremium: false, expiresAt: null };
    }

    // ── Write back to Firestore so isPremium() works offline ─────────────────
    const updatePayload = {
      subscriptionStatus: isPremium ? (bestSub?.status || 'active') : (subscriptions.data[0]?.status || 'free'),
      subscriptionPlan: isPremium ? 'premium' : (isInAppTrial ? 'trial' : 'free'),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (bestSub) {
      const priceId =
        bestSub.items?.data?.[0]?.price?.id ?? bestSub.plan?.id ?? null;

      updatePayload.stripeSubscriptionId = bestSub.id;
      updatePayload.billingPeriodEnd = admin.firestore.Timestamp.fromMillis(bestSub.current_period_end * 1000);
      updatePayload.billingPeriodStart = admin.firestore.Timestamp.fromMillis(bestSub.current_period_start * 1000);

      if (priceId) {
        updatePayload.subscriptionPriceId = priceId;
        updatePayload.subscription = {
          status: bestSub.status,
          priceId,
        };
      }
      attachSubscriptionName(updatePayload, priceId, isPremium);
    } else {
      attachSubscriptionName(updatePayload, null, false);
    }
    if (isPremium) {
      Object.assign(updatePayload, clearInAppTrialFields());
    }
    await userRef.set(updatePayload, { merge: true });
    console.log(`[verifySubscription] Updated Firestore: isPremium=${isPremium}`);

    return { isPremium, expiresAt };
  } catch (error) {
    console.error('[verifySubscription] Error:', error);
    throw new HttpsError('internal', `Error verifying subscription: ${error.message}`);
  }
});

/**
 * getStripePrices - Returns Stripe price details with server-side per-month
 * calculation so the client never hard-codes prices.
 *
 * Expected data: { priceIds: string[] }
 * Returns: { prices: { [priceId]: { id, amount, currency, interval,
 *   intervalCount, formattedAmount, formattedPerMonth, productName } } }
 */
exports.getStripePrices = onCall(
  { secrets: [stripeSecretKey, stripePriceMonthly] },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  await enforceRateLimit(request.auth.uid, 'getStripePrices', 20, 60 * 1000); // 20 requests per minute

  const { priceIds } = request.data;
  if (!Array.isArray(priceIds) || priceIds.length === 0) {
    throw new HttpsError('invalid-argument', '"priceIds" must be a non-empty array.');
  }

  for (const id of priceIds) {
    if (
      !isAllowedPremiumPriceId(id) &&
      id !== LEGACY_MONTHLY_PRICE_ID
    ) {
      throw new HttpsError('invalid-argument', 'One or more price IDs are not allowed.');
    }
  }

  const rawSecret = stripeSecretKey.value();
  if (!rawSecret) {
    throw new HttpsError('internal', 'Payment service is not configured.');
  }

  const stripe = require('stripe')(rawSecret.trim());

  // Currency symbol lookup
  const currencySymbols = {
    usd: '$', eur: '€', gbp: '£', inr: '₹',
    aud: 'A$', cad: 'C$', sgd: 'S$', aed: 'AED',
  };

  function formatAmount(amountInCents, currency) {
    const symbol = currencySymbols[currency] || currency.toUpperCase() + ' ';
    const major = amountInCents / 100;
    const formatted = Number.isInteger(major)
      ? major.toString()
      : major.toFixed(2);
    return `${symbol}${formatted}`;
  }

  try {
    const results = await Promise.all(
      priceIds.map(async (id) => {
        const price = await stripe.prices.retrieve(id, {
          expand: ['product'],
        });

        const unitAmount = price.unit_amount; // in cents / paise
        const currency = price.currency;      // lowercase, e.g. "usd"
        const interval = price.recurring?.interval || 'month';
        const intervalCount = price.recurring?.interval_count || 1;
        const productName = price.product?.name || '';

        // Calculate raw dollar/rupee amount
        const amount = unitAmount / 100;

        // Calculate per-month amount
        let perMonthAmount;
        if (interval === 'year') {
          perMonthAmount = amount / (12 * intervalCount);
        } else if (interval === 'month' && intervalCount > 1) {
          perMonthAmount = amount / intervalCount;
        } else {
          perMonthAmount = amount;
        }

        return {
          id: price.id,
          amount: parseFloat(amount.toFixed(2)),
          currency: currency.toUpperCase(),
          interval,
          intervalCount,
          formattedAmount: formatAmount(unitAmount, currency),
          formattedPerMonth: `${formatAmount(Math.round(perMonthAmount * 100), currency)}/month`,
          productName,
        };
      })
    );

    // Return as a map keyed by priceId for O(1) lookup on client
    const pricesMap = {};
    for (const r of results) {
      pricesMap[r.id] = r;
    }
    return { prices: pricesMap };
  } catch (error) {
    console.error('[getStripePrices] Stripe error:', error.message);
    throw new HttpsError('internal', `Stripe error: ${error.message}`);
  }
});


/**
 * sendNotification - Manual FCM notification sending (callable)
 * Replaces client-side service account usage for security
 */
exports.sendNotification = onCall(async (request) => {
  // MUST BE AUTHENTICATED
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in to send a notification.');
  }

  await enforceRateLimit(request.auth.uid, 'sendNotification', 10, 60 * 1000); // 10 requests per minute

  // RESTRICT: ONLY ADMINS CAN USE THIS FUNCTION
  const email = request.auth.token.email || '';
  const isAdmin = email === "sasikumar.s9951@gmail.com" || 
                  email === "admin@gmail.com" || 
                  email.endsWith("@swan-match.com");
                  
  if (!isAdmin) {
    throw new HttpsError('permission-denied', 'Only administrators can send notifications.');
  }

  const { fcmToken, title, body, data } = request.data;

  if (!fcmToken) {
    throw new HttpsError('invalid-argument', 'FCM token is required.');
  }

  if (!title || !body) {
    throw new HttpsError('invalid-argument', 'Title and body are required.');
  }

  try {
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          sound: 'default',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    };

    const response = await admin.messaging().send(message);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error sending FCM notification:', error);
    throw new HttpsError('internal', error.message);
  }
});

/**
 * Stripe - Create Portal Session
 * Allows users to manage/cancel their subscription
 */
exports.createPortalSession = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  await enforceRateLimit(request.auth.uid, 'createPortalSession', 5, 60 * 1000); // 5 requests per minute

  const uid = request.auth.uid;
  const rawSecret = stripeSecretKey.value();
  if (!rawSecret) {
    throw new HttpsError('internal', 'Payment service is not configured.');
  }

  const stripe = require('stripe')(rawSecret.trim());
  const db = admin.firestore();

  try {
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', 'User not found.');
    }

    const stripeCustomerId = userDoc.data().stripeCustomerId;
    if (!stripeCustomerId) {
      throw new HttpsError('failed-precondition', 'No Stripe customer found for this user.');
    }

    // Create a billing portal session
    const session = await stripe.billingPortal.sessions.create({
      customer: stripeCustomerId,
      return_url: request.data.returnUrl || 'swanmatch://payment-cancel',
    });

    return { url: session.url };
  } catch (error) {
    console.error('[createPortalSession] Stripe error:', error);
    throw new HttpsError('internal', `Stripe error: ${error.message}`);
  }
});

/**
 * hardDeleteExpiredAccounts — runs daily at 03:00 UTC.
 * Permanently removes user data for accounts that have passed their
 * 30-day soft-delete retention window (scheduledHardDeleteAt <= now).
 *
 * For each expired account it will:
 *  1. Delete all photos from Firebase Storage.
 *  2. Delete the Firestore user document.
 *  3. Delete the Firebase Auth account.
 */
exports.hardDeleteExpiredAccounts = onSchedule(
  { schedule: '0 3 * * *', timeZone: 'UTC' },
  async (_event) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    console.log('[hardDelete] Starting daily hard-delete run at', new Date().toISOString());

    const snapshot = await db
      .collection('users')
      .where('isDeleted', '==', true)
      .where('scheduledHardDeleteAt', '<=', now)
      .get();

    if (snapshot.empty) {
      console.log('[hardDelete] No expired accounts found.');
      return;
    }

    console.log(`[hardDelete] Found ${snapshot.size} account(s) to hard-delete.`);

    for (const doc of snapshot.docs) {
      const uid = doc.id;
      console.log(`[hardDelete] Processing uid=${uid}`);

      try {
        // 1. Delete photos from Firebase Storage
        const bucket = admin.storage().bucket();
        const [files] = await bucket.getFiles({ prefix: `users/${uid}/` });
        if (files.length > 0) {
          await Promise.all(files.map((f) => f.delete().catch((e) =>
            console.warn(`[hardDelete] Could not delete file ${f.name}: ${e.message}`)
          )));
          console.log(`[hardDelete] Deleted ${files.length} storage file(s) for uid=${uid}`);
        }

        // 2. Delete Firestore document
        await doc.ref.delete();
        console.log(`[hardDelete] Deleted Firestore doc for uid=${uid}`);

        // 3. Delete Firebase Auth account
        await admin.auth().deleteUser(uid);
        console.log(`[hardDelete] Deleted Auth account for uid=${uid}`);
      } catch (err) {
        console.error(`[hardDelete] Failed for uid=${uid}: ${err.message}`);
        // Continue processing remaining accounts
      }
    }

    console.log('[hardDelete] Run complete.');
  }
);

/**
 * Securely lookup authentication providers by email.
 * This is used for the Forgot Password flow to bypass Email Enumeration 
 * restrictions securely without opening up the users collection in Firestore.
 */
exports.checkAuthProviders = onCall(async (request) => {
  const email = request.data.email;

  // Rate limit: 10 requests per minute per email address (prevents email enumeration abuse)
  if (email && typeof email === 'string') {
    await enforceRateLimit(null, 'checkAuthProviders', 10, 60 * 1000, `email_${email.toLowerCase().trim()}`);
  }

  if (!email || typeof email !== 'string') {
    throw new HttpsError('invalid-argument', 'The function must be called with a valid "email".');
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(email);

    // Extract provider IDs from userRecord
    const providers = userRecord.providerData.map(info => info.providerId);

    return {
      exists: true,
      providers: providers
    };
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return {
        exists: false,
        providers: []
      };
    }
    // For other errors, throw an internal error to obscure details
    console.error('[checkAuthProviders] Error fetching user by email:', error);
    throw new HttpsError('internal', 'An error occurred while checking account status.');
  }
});

/**
 * Ensures Firebase Auth account is deleted even if the user force closes
 * the app during the deletion process. Triggered when `isDeleted: true`.
 */
exports.onUserSoftDeleted = onDocumentUpdated('users/{uid}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const uid = event.params.uid;

  // Only trigger if isDeleted changes from false to true
  if (!before.isDeleted && after.isDeleted === true) {
    console.log(`[onUserSoftDeleted] Triggered for user ${uid}. Deleting Firebase Auth account.`);
    try {
      await admin.auth().deleteUser(uid);
      console.log(`[onUserSoftDeleted] Successfully deleted Firebase Auth for ${uid}.`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log(`[onUserSoftDeleted] Auth account for ${uid} was already deleted.`);
      } else {
        console.error(`[onUserSoftDeleted] Error deleting Auth for ${uid}:`, error);
      }
    }
  }
});

// ─── Login Throttling ────────────────────────────────────────────────────────
// Secure, persistent Firestore-backed throttling tracker (prevents bypasses on scaling/cold starts)
// Reads and writes to private '_loginAttempts' collection which is completely hidden from clients.

/**
 * trackLoginAttempt — called from the client BEFORE signInWithEmailAndPassword.
 * Throws resource-exhausted if the user has exceeded the max attempts within
 * the sliding window. This prevents brute-force password guessing.
 */
exports.trackLoginAttempt = onCall(async (request) => {
  const { email } = request.data;
  if (!email || typeof email !== 'string') {
    throw new HttpsError('invalid-argument', 'Email is required.');
  }

  const key = email.toLowerCase().trim();
  const now = Date.now();
  const windowMs = 15 * 60 * 1000; // 15-minute sliding window
  const maxAttempts = 5;            // 5 failed attempts allowed

  const db = admin.firestore();
  const snap = await db.collection('_loginAttempts').doc(key).get();
  const data = snap.exists ? snap.data() : { timestamps: [] };

  // Clean old entries
  const recent = (data.timestamps || []).filter(t => now - t < windowMs);
  const count = recent.length;

  if (count >= maxAttempts) {
    throw new HttpsError(
      'resource-exhausted',
      'Too many login attempts. Please try again later.'
    );
  }

  // Caller only logs failures via trackLoginFailure. Success resets it via trackLoginSuccess.
  return { allowed: true, attempts: count, remaining: maxAttempts - count };
});

/**
 * trackLoginSuccess — called from the client after a SUCCESSFUL login.
 * Clears the attempt counter for that email so previous failures are forgotten.
 */
exports.trackLoginSuccess = onCall(async (request) => {
  const { email } = request.data;
  if (!email || typeof email !== 'string') return { cleared: false };
  const key = email.toLowerCase().trim();

  const db = admin.firestore();
  await db.collection('_loginAttempts').doc(key).delete();
  return { cleared: true };
});

/**
 * trackLoginFailure — called from the client after a FAILED login.
 * Increments the attempt counter for that email.
 */
exports.trackLoginFailure = onCall(async (request) => {
  const { email } = request.data;
  if (!email || typeof email !== 'string') return { recorded: false };

  const key = email.toLowerCase().trim();
  const now = Date.now();
  const windowMs = 15 * 60 * 1000;

  const db = admin.firestore();
  const ref = db.collection('_loginAttempts').doc(key);

  let attemptsCount = 0;
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const data = snap.exists ? snap.data() : { timestamps: [] };
    const recent = (data.timestamps || []).filter(t => now - t < windowMs);
    recent.push(now);
    transaction.set(ref, { timestamps: recent }, { merge: true });
    attemptsCount = recent.length;
  });

  return { recorded: true, attempts: attemptsCount };
});

// ─── Signup Velocity Tracking ────────────────────────────────────────────────
// Tracks signup IP addresses to detect bulk account creation.

exports.trackSignup = onCall(async (request) => {
  const ip = request.rawRequest?.ip || 'unknown';
  const db = admin.firestore();
  const ref = db.collection('_signupTracker').doc(ip);
  const now = Date.now();
  const hourAgo = now - 3600000;

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(ref);
    const data = doc.exists ? doc.data() : { timestamps: [] };
    const recent = (data.timestamps || []).filter(t => now - t < 3600000);
    recent.push(now);
    transaction.set(ref, { timestamps: recent }, { merge: true });

    // If >3 signups in an hour from same IP → flag for admin
    if (recent.length > 3) {
      await db.collection('_flaggedSignups').add({
        ip,
        count: recent.length,
        firstAt: new Date(recent[0]).toISOString(),
        lastAt: new Date(now).toISOString(),
        detectedAt: new Date().toISOString(),
      });
    }
  });

  return { tracked: true };
});

// ============================================================================
// ADMIN FUNCTIONS
// ============================================================================

function isAdminAuth(request) {
  return request.auth && (
    request.auth.token.email === 'sasikumar.s9951@gmail.com' ||
    request.auth.token.email === 'admin@gmail.com' ||
    (request.auth.token.email || '').endsWith('@swan-match.com')
  );
}

/** Log an admin action to the audit log. */
async function logAdminAction(adminUid, action, targetUid, details) {
  await admin.firestore().collection('admin_audit_logs').add({
    adminUid,
    action,
    targetUid: targetUid || null,
    details: details || '',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/** Admin suspend a user. */
exports.adminSuspendUser = onCall(async (request) => {
  if (!isAdminAuth(request)) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }
  const { uid, reason } = request.data;
  if (!uid) throw new HttpsError('invalid-argument', 'uid required');

  await admin.firestore().collection('users').doc(uid).update({
    account: 'Suspended',
    suspensionReason: reason || 'Violation of terms',
    suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
    suspendedBy: request.auth.uid,
  });

  await logAdminAction(request.auth.uid, 'suspend_user', uid, reason || 'Violation of terms');

  return { success: true };
});

/** Admin unsuspend a user. */
exports.adminUnsuspendUser = onCall(async (request) => {
  if (!isAdminAuth(request)) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }
  const { uid } = request.data;
  if (!uid) throw new HttpsError('invalid-argument', 'uid required');

  await admin.firestore().collection('users').doc(uid).update({
    account: 'Active',
    suspensionReason: admin.firestore.FieldValue.delete(),
    suspendedAt: admin.firestore.FieldValue.delete(),
    suspendedBy: admin.firestore.FieldValue.delete(),
    unsuspendedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logAdminAction(request.auth.uid, 'unsuspend_user', uid, '');

  return { success: true };
});

/** Admin warn a user. */
exports.adminWarnUser = onCall(async (request) => {
  if (!isAdminAuth(request)) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }
  const { uid, message } = request.data;
  if (!uid || !message) throw new HttpsError('invalid-argument', 'uid and message required');

  const warning = {
    message,
    issuedBy: request.auth.uid,
    issuedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await admin.firestore().collection('users').doc(uid).update({
    warnings: admin.firestore.FieldValue.arrayUnion(warning),
  });

  await logAdminAction(request.auth.uid, 'warn_user', uid, message);

  return { success: true };
});

/** Admin resolve an appeal. */
exports.adminResolveAppeal = onCall(async (request) => {
  if (!isAdminAuth(request)) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }
  const { appealId, status, note } = request.data;
  if (!appealId || !status) throw new HttpsError('invalid-argument', 'appealId and status required');

  await admin.firestore().collection('appeals').doc(appealId).update({
    status,
    adminNote: note || '',
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    resolvedBy: request.auth.uid,
  });

  await logAdminAction(request.auth.uid, 'resolve_appeal', null, `appealId=${appealId}, status=${status}, note=${note || ''}`);

  return { success: true };
});

// ============================================================================
// APPEALS
// ============================================================================

/** Submit an appeal (signed-in users only, including suspended). */
exports.submitAppeal = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const uid = request.auth.uid;

  const { reason } = request.data;
  if (!reason || typeof reason !== 'string' || reason.trim().length < 10) {
    throw new HttpsError('invalid-argument', 'Please provide a detailed reason (min 10 characters).');
  }
  if (reason.length > 2000) {
    throw new HttpsError('invalid-argument', 'Reason too long (max 2000 characters).');
  }

  const db = admin.firestore();

  // Rate limit: check existing appeals for this user
  const existing = await db.collection('appeals')
    .where('userId', '==', uid)
    .get();

  // Max 3 total appeals per user
  if (existing.size >= 3) {
    throw new HttpsError('failed-precondition', 'You have reached the maximum of 3 appeals. Please contact support@swan-match.com.');
  }

  // Only 1 pending appeal at a time
  const hasPending = existing.docs.some(doc => doc.data().status === 'pending');
  if (hasPending) {
    throw new HttpsError('failed-precondition', 'You already have a pending appeal. Please wait for a response before submitting a new one.');
  }

  await db.collection('appeals').add({
    userId: uid,
    userEmail: request.auth.token.email || '',
    reason: reason.trim(),
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// ============================================================================
// REPORTS (with rate limiting)
// ============================================================================

/** Submit a report. Rate limited: 5 reports per hour per user. */
exports.submitReport = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  await enforceRateLimit(request.auth.uid, 'submitReport', 5, 3600 * 1000);

  const { reportedUid, reason } = request.data;
  const reporterUid = request.auth.uid;

  if (!reportedUid || typeof reportedUid !== 'string') {
    throw new HttpsError('invalid-argument', 'reportedUid is required.');
  }
  if (reportedUid === reporterUid) {
    throw new HttpsError('invalid-argument', 'Cannot report yourself.');
  }
  if (!reason || typeof reason !== 'string' || reason.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Reason is required.');
  }
  if (reason.length > 500) {
    throw new HttpsError('invalid-argument', 'Reason too long (max 500 characters).');
  }

  const db = admin.firestore();

  // Retrieve chat thread evidence before deleting it
  const chatId = [reporterUid, reportedUid].sort().join('_');
  const chatRef = db.collection('chats').doc(chatId);
  let chatEvidence = [];

  try {
    const msgsSnapshot = await chatRef.collection('messages').get();
    if (!msgsSnapshot.empty) {
      // Sort docs ascending by time
      const sortedDocs = msgsSnapshot.docs.sort((a, b) => {
        const timeA = a.data().time || a.data().createdAt || 0;
        const timeB = b.data().time || b.data().createdAt || 0;
        const getMillis = (t) => {
          if (!t) return 0;
          if (typeof t.toDate === 'function') return t.toDate().getTime();
          if (t.seconds) return t.seconds * 1000;
          const parsed = Date.parse(t);
          return Number.isNaN(parsed) ? 0 : parsed;
        };
        return getMillis(timeA) - getMillis(timeB);
      });

      // Keep only the last 50 messages
      const recentDocs = sortedDocs.slice(-50);
      chatEvidence = recentDocs.map(d => {
        const data = d.data();
        return {
          senderId: data.senderId || '',
          senderName: data.senderName || '',
          text: data.text || data.message || '',
          time: data.time || data.createdAt || null
        };
      });
    }
  } catch (err) {
    console.error(`[submitReport] Error retrieving chat evidence: ${err.message}`);
  }

  // Create report
  await db.collection('reports').add({
    reportedUid,
    reportedBy: reporterUid,
    reason: reason.trim(),
    reportedAt: admin.firestore.FieldValue.serverTimestamp(),
    isReported: true,
    status: 'Open',
    chatEvidence: chatEvidence, // Archive conversation history permanently as moderator evidence
  });

  // Update reporter's blockedUids and reportedUids
  await db.collection('users').doc(reporterUid).update({
    blockedUids: admin.firestore.FieldValue.arrayUnion(reportedUid),
    reportedUids: admin.firestore.FieldValue.arrayUnion(reportedUid),
  });

  // Remove connections (interests, likes, matches, chat)
  try {
    // Mark interests as blocked
    const sentInterests = await db.collection('interests')
      .where('fromUserId', '==', reporterUid)
      .where('toUserId', '==', reportedUid)
      .get();
    const receivedInterests = await db.collection('interests')
      .where('fromUserId', '==', reportedUid)
      .where('toUserId', '==', reporterUid)
      .get();

    const batch = db.batch();
    for (const doc of [...sentInterests.docs, ...receivedInterests.docs]) {
      batch.update(doc.ref, {
        status: 'blocked',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Delete likes (both directions)
    batch.delete(db.collection('likes').doc(reporterUid).collection('likedUsers').doc(reportedUid));
    batch.delete(db.collection('likes').doc(reportedUid).collection('likedUsers').doc(reporterUid));

    // Delete match
    const matchId = reporterUid < reportedUid ? `${reporterUid}_${reportedUid}` : `${reportedUid}_${reporterUid}`;
    batch.delete(db.collection('matches').doc(matchId));

    await batch.commit();

    // Delete chat thread
    const chatId = [reporterUid, reportedUid].sort().join('_');
    const chatRef = db.collection('chats').doc(chatId);
    const msgs = await chatRef.collection('messages').get();
    const msgBatch = db.batch();
    for (const m of msgs.docs) {
      msgBatch.delete(m.ref);
    }
    await msgBatch.commit();
    await chatRef.delete();
  } catch (err) {
    console.error(`[submitReport] Connection cleanup error: ${err.message}`);
  }

  return { success: true };
});

// ============================================================================
// AUTO-SUSPEND ON REPORTS
// ============================================================================

/** When a report is created, check if the reported user has 3+ reports and auto-suspend. */
exports.onReportCreated = onDocumentCreated('reports/{reportId}', async (event) => {
  const report = event.data?.data();
  if (!report) return;

  const reportedUid = report.reportedUid;
  if (!reportedUid) return;

  try {
    const snapshot = await admin.firestore()
      .collection('reports')
      .where('reportedUid', '==', reportedUid)
      .get();

    const reportCount = snapshot.size;

    // Auto-suspend at 3 reports
    if (reportCount >= 3) {
      await admin.firestore().collection('users').doc(reportedUid).update({
        account: 'Suspended',
        suspensionReason: `Auto-suspended: received ${reportCount} reports`,
        suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
        suspendedBy: 'system',
      });

      await logAdminAction('system', 'auto_suspend', reportedUid, `Auto-suspended: ${reportCount} reports`);
      console.log(`[autoSuspend] User ${reportedUid} suspended after ${reportCount} reports`);
    }

    // Send notification to reporter thanking them
    const reporterId = report.reportedBy;
    if (reporterId) {
      await admin.firestore().collection('notifications').add({
        toUserId: reporterId,
        fromUserId: 'system',
        title: 'Report Received',
        message: 'Thank you for your report. Our moderation team will review it and take appropriate action.',
        type: 'report',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (err) {
    console.error(`[onReportCreated] Error: ${err.message}`);
  }
});

// ============================================================================
// SECURITY HARDENING: IP & DEVICE MONITORING
// ============================================================================

/** Captures secure client connection IP and logs device hardware metadata. */
exports.logSessionActivity = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const uid = request.auth.uid;
  
  // Extract secure un-fakeable client IP address directly from connection headers
  const ip = request.rawRequest.ip || request.rawRequest.headers['x-forwarded-for'] || 'unknown';

  const { model, osVersion, brand, deviceId, sessionTrigger } = request.data;

  if (!model || !deviceId) {
    throw new HttpsError('invalid-argument', 'Missing hardware model or device identifier.');
  }

  const db = admin.firestore();

  try {
    // 1. Check if the device is currently associated with any banned/suspended users
    const bannedDevices = await db.collection('users')
      .where('lastLoginDeviceId', '==', deviceId)
      .where('account', '==', 'Suspended')
      .limit(1)
      .get();

    if (!bannedDevices.empty) {
      console.warn(`[logSessionActivity] WARNING: Banned device login attempt: deviceId=${deviceId} uid=${uid}`);
      // Mark this account as flagged for matching a banned device fingerprint
      await db.collection('users').doc(uid).update({
        deviceMatchesSuspendedFingerprint: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // 2. Securely append to the securityLogs subcollection
    const logRef = db.collection('users').doc(uid).collection('securityLogs').doc();
    await logRef.set({
      ipAddress: ip,
      deviceModel: model,
      brand: brand || 'unknown',
      osVersion: osVersion || 'unknown',
      deviceId: deviceId,
      sessionTrigger: sessionTrigger || 'app_start',
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Keep lightweight, readable last login info directly on the primary user document
    await db.collection('users').doc(uid).update({
      lastLoginIp: ip,
      lastLoginDeviceId: deviceId,
      lastLoginDeviceModel: model,
      lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[logSessionActivity] Logged session for uid=${uid} deviceId=${deviceId} IP=${ip} trigger=${sessionTrigger}`);
    return { success: true };
  } catch (err) {
    console.error(`[logSessionActivity] Error: ${err.message}`);
    throw new HttpsError('internal', `Security logging failed: ${err.message}`);
  }
});

// ============================================================================
// SUPPORT & TICKETING SYSTEM (STEP 18)
// ============================================================================
const nodemailer = require('nodemailer');

exports.onSupportQueryCreated = onDocumentCreated(
  { document: 'support_queries/{queryId}' },
  async (event) => {
  // ─── SUPPORT WORKFLOW RECIPIENTS CONFIGURATION (EASILY REMOVABLE/EDITABLE) ──
  const TARGET_SUPPORT_INBOX = 'sasikumar.s9951@gmail.com'; // Temporary for testing, change to support@swan-match.com later
  const DEVELOPER_CC_ADDRESS = ''; // Set to secondary email if needed
  // ───────────────────────────────────────────────────────────────────────────

  const queryData = event.data?.data();
  if (!queryData) {
    console.log('[onSupportQueryCreated] No data in event');
    return;
  }

  const { userId, userName, userEmail, subject, message, deviceInfo } = queryData;
  console.log(`[onSupportQueryCreated] New query from user=${userId} (${userEmail}): ${subject}`);

  const smtpHost = 'smtp.gmail.com';
  const smtpPort = 587;
  const smtpUserVal = process.env.SMTP_USER || '';
  const smtpPassVal = process.env.SMTP_PASS || '';

  if (!smtpUserVal || !smtpPassVal) {
    console.warn('[onSupportQueryCreated] SMTP credentials are not configured in Secret Manager. Skipping email dispatch.');
    return;
  }

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: false,
    auth: {
      user: smtpUserVal,
      pass: smtpPassVal,
    },
  });

  const ccOptions = DEVELOPER_CC_ADDRESS ? { cc: DEVELOPER_CC_ADDRESS } : {};

  const mailOptions = {
    from: `"Swan Match Support" <${smtpUserVal}>`,
    to: TARGET_SUPPORT_INBOX,
    ...ccOptions,
    replyTo: userEmail || smtpUserVal,
    subject: `[Support Query] ${subject || 'No Subject'}`,
    envelope: {
      from: smtpUserVal,
      to: TARGET_SUPPORT_INBOX,
    },
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body {
            font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
            background-color: #0d0d0d;
            color: #ffffff;
            margin: 0;
            padding: 0;
          }
          .container {
            max-width: 600px;
            margin: 40px auto;
            background-color: #121212;
            border: 1px solid #c5a880;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.8);
          }
          .header {
            background: linear-gradient(135deg, #1f1a12 0%, #0d0d0d 100%);
            padding: 30px;
            text-align: center;
            border-bottom: 1px solid #c5a880;
          }
          .header h1 {
            color: #c5a880;
            font-size: 24px;
            margin: 0;
            text-transform: uppercase;
            letter-spacing: 2px;
          }
          .content {
            padding: 30px;
            line-height: 1.6;
          }
          .field {
            margin-bottom: 20px;
          }
          .label {
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #c5a880;
            font-weight: bold;
            margin-bottom: 5px;
          }
          .value {
            font-size: 15px;
            color: #e6e6e6;
            background-color: #1a1a1a;
            padding: 10px 15px;
            border-radius: 6px;
            border: 1px solid #222;
          }
          .message-value {
            font-size: 14px;
            color: #ffffff;
            background-color: #1a1a1a;
            padding: 15px;
            border-radius: 6px;
            border-left: 3px solid #c5a880;
            white-space: pre-wrap;
            border-top: 1px solid #222;
            border-right: 1px solid #222;
            border-bottom: 1px solid #222;
          }
          .footer {
            background-color: #0d0d0d;
            padding: 20px;
            text-align: center;
            font-size: 11px;
            color: #555555;
            border-top: 1px solid #1a1a1a;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Swan Match</h1>
            <div style="color: #888; font-size: 11px; margin-top: 5px; letter-spacing: 1px;">NEW CUSTOMER SUPPORT INQUIRY</div>
          </div>
          <div class="content">
            <div class="field">
              <div class="label">Sender Name</div>
              <div class="value">${userName || 'Anonymous'}</div>
            </div>
            <div class="field">
              <div class="label">Sender Email</div>
              <div class="value">${userEmail || 'No Email'} &nbsp;&bull;&nbsp; UID: <code>${userId || 'N/A'}</code></div>
            </div>
            <div class="field">
              <div class="label">Subject</div>
              <div class="value" style="font-weight: bold; color: #fff;">${subject || 'No Subject'}</div>
            </div>
            <div class="field">
              <div class="label">Message</div>
              <div class="message-value">${message || 'No message content.'}</div>
            </div>
            <div class="field">
              <div class="label">Device Diagnostics</div>
              <div class="value" style="font-size: 13px; line-height: 1.5; color: #bbb;">
                <strong>Platform/OS:</strong> ${deviceInfo?.osVersion || 'Unknown OS'}<br>
                <strong>Device Model:</strong> ${deviceInfo?.deviceModel || 'Unknown Model'}<br>
                <strong>Device Brand:</strong> ${deviceInfo?.deviceBrand || 'Unknown Brand'}<br>
                <strong>App Version:</strong> ${deviceInfo?.appVersion || 'Unknown Version'}
              </div>
            </div>
          </div>
          <div class="footer">
            &copy; ${new Date().getFullYear()} Swan Match. All rights reserved. Confidential Internal Admin Notification.
          </div>
        </div>
      </body>
      </html>
    `,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`[onSupportQueryCreated] Successfully sent support query email. MessageId: ${info.messageId}`);
  } catch (error) {
    console.error('[onSupportQueryCreated] Error sending email:', error.message);
  }
});

/**
 * Send email response directly from Admin Web Dashboard to support users.
 */
exports.sendSupportEmail = onCall(
  {},
  async (request) => {
  // 1. Enforce admin auth
  if (!isAdminAuth(request)) {
    throw new HttpsError('permission-denied', 'Only administrators can send support emails.');
  }

  const { toEmail, subject, htmlMessage } = request.data;
  if (!toEmail || !subject || !htmlMessage) {
    throw new HttpsError('invalid-argument', 'Missing required fields (toEmail, subject, htmlMessage).');
  }

  const smtpUserVal = process.env.SMTP_USER || '';
  const smtpPassVal = process.env.SMTP_PASS || '';

  if (!smtpUserVal || !smtpPassVal) {
    throw new HttpsError(
      'failed-precondition',
      'SMTP credentials are not configured. Please set SMTP_USER and SMTP_PASS secrets in Firebase.'
    );
  }

  const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: {
      user: smtpUserVal,
      pass: smtpPassVal,
    },
  });

  const mailOptions = {
    from: `"Swan Match Support" <${smtpUserVal}>`,
    to: toEmail,
    replyTo: 'support@swan-match.com',
    subject: subject,
    html: htmlMessage,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`[sendSupportEmail] Support reply sent successfully to ${toEmail}. MessageId: ${info.messageId}`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('[sendSupportEmail] Error sending reply email:', error.message);
    throw new HttpsError('internal', `Failed to send email: ${error.message}`);
  }
});


/**
 * Automated Daily Inactivity Recovery Cron (STEP 20 Retention)
 * Scans for users inactive for more than 3 days and dispatches a random re-engagement push notification.
 */
exports.sendInactivityReminders = onSchedule(
  { schedule: '0 10 * * *', timeZone: 'UTC' }, // Runs daily at 10 AM UTC
  async (_event) => {
    const db = admin.firestore();
    const threeDaysAgo = new Date();
    threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);

    console.log('[inactivityRecovery] Starting daily re-engagement scan...');

    try {
      // Query users whose last active date is older than 3 days
      const snapshot = await db.collection('users')
        .where('lastActiveAt', '<=', admin.firestore.Timestamp.fromDate(threeDaysAgo))
        .get();

      if (snapshot.empty) {
        console.log('[inactivityRecovery] No inactive users found.');
        return;
      }

      console.log(`[inactivityRecovery] Found ${snapshot.size} candidate(s) for recovery.`);

      const MESSAGES = [
        {
          title: "Someone is looking at your profile! 👀",
          body: "We found new customized matching recommendations for you today. Open Swan Match to see who it is! 💛"
        },
        {
          title: "Don't miss your perfect match! 👑",
          body: "New members just joined in your area. Open Swan Match now to review your handpicked recommendations!"
        },
        {
          title: "New recommendations are ready! ✨",
          body: "Your daily match list has been updated. Tap to open Swan Match and meet your potential partner today!"
        }
      ];

      let sentCount = 0;

      for (const doc of snapshot.docs) {
        const userData = doc.data();
        
        // Skip soft-deleted or suspended accounts
        if (userData.isDeleted === true || userData.account === 'Suspended') {
          continue;
        }

        // Extract token
        let targetToken = userData.fcmToken;
        if (!targetToken && Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
          targetToken = userData.fcmTokens[0];
        }

        if (!targetToken) {
          continue;
        }

        // Pick a random message
        const randomMsg = MESSAGES[Math.floor(Math.random() * MESSAGES.length)];

        const fcmMessage = {
          token: targetToken,
          notification: {
            title: randomMsg.title,
            body: randomMsg.body,
          },
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            type: 'inactivity_recovery',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'high_importance_channel',
              sound: 'default',
            },
          },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
          },
        };

        try {
          await admin.messaging().send(fcmMessage);
          sentCount++;
          console.log(`[inactivityRecovery] Dispatched push to user uid=${doc.id}`);
        } catch (fcmError) {
          console.warn(`[inactivityRecovery] Failed to send push to user uid=${doc.id}: ${fcmError.message}`);
        }
      }

      console.log(`[inactivityRecovery] Run complete. Successfully sent pushes to ${sentCount} user(s).`);
    } catch (err) {
      console.error('[inactivityRecovery] Fatal execution error:', err.message);
    }
  }
);



