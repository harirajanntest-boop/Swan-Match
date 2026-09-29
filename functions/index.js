const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();
const iapEntitlements = require('./iap_entitlements');

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

// FCM error codes meaning the token is permanently dead. Other send errors
// (unavailable, internal, quota) are temporary — removing the token for those
// silently cut working devices off.
const DEAD_FCM_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * Removes only permanently-dead tokens (per sendErrors[i] for fcmTokens[i]),
 * including the legacy single `fcmToken` field when it is one of them.
 */
async function removeDeadFcmTokens(uid, userData, fcmTokens, sendErrors) {
  const dead = fcmTokens.filter(
    (_, i) => sendErrors[i] && DEAD_FCM_TOKEN_CODES.has(sendErrors[i].code),
  );
  if (dead.length === 0) return;
  const update = { fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead) };
  const legacy = typeof userData?.fcmToken === 'string' ? userData.fcmToken.trim() : '';
  if (legacy && dead.includes(legacy)) {
    update.fcmToken = admin.firestore.FieldValue.delete();
  }
  console.log(`[fcm] Removing ${dead.length} dead token(s) for ${uid}`);
  await admin.firestore().collection('users').doc(uid).update(update);
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
    const sendErrors = [];
    const sendPromises = fcmTokens.map((token, i) =>
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
        console.error(`[onNotificationCreated] Failed for token ${token.substring(0, 20)}...: ${err.code} ${err.message}`);
        sendErrors[i] = err;
        return null;
      })
    );

    const results = await Promise.all(sendPromises);
    const successCount = results.filter(r => r !== null).length;
    console.log(`[onNotificationCreated] Sent ${successCount}/${fcmTokens.length} notifications`);

    // 3. Clean up permanently dead tokens only
    await removeDeadFcmTokens(toUserId, userData, fcmTokens, sendErrors);
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
    const sendErrors = [];
    const sendPromises = fcmTokens.map((token, i) =>
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
        sendErrors[i] = err;
        return null;
      })
    );

    const results = await Promise.all(sendPromises);
    const successCount = results.filter(r => r !== null).length;
    console.log(`[onMessageCreated] Sent ${successCount}/${fcmTokens.length} notifications successfully`);

    // Clean up permanently dead tokens only
    await removeDeadFcmTokens(receiverId, userData, fcmTokens, sendErrors);
  } catch (error) {
    console.error('[onMessageCreated] Fatal error:', error.message, error.code);
  }
});

const { onCall, HttpsError, onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

// 1. SECRETS
const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');
/** Pricing secrets — set via: firebase functions:secrets:set STRIPE_PRICE_MONTHLY, etc. */
const stripePriceMonthly = defineSecret('STRIPE_PRICE_MONTHLY');
const stripePriceSixMonth = defineSecret('STRIPE_PRICE_SIXMONTH');
const stripePriceYearly = defineSecret('STRIPE_PRICE_YEARLY');
/** SMTP credentials for Nodemailer email sending — set via:
 *  firebase functions:secrets:set SMTP_USER
 *  firebase functions:secrets:set SMTP_PASS
 *  NOTE: These are optional. If not set, email functions will log a warning and skip.
 */
const smtpUser = defineSecret('SMTP_USER');
const smtpPass = defineSecret('SMTP_PASS');
/** App Store Server API private key (.p8 contents) for verifying iOS purchases. */
const appStoreIapKey = defineSecret('APP_STORE_IAP_KEY');

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

/** Previous $19.00 monthly price — keep mapping for existing subscribers. */
const LEGACY_MONTHLY_PRICE_ID = 'price_1TKOrRE3Rb5ApPY7fOuscBJK';

function readPremiumPriceIds() {
  return {
    monthly: (stripePriceMonthly.value() || '').trim(),
    sixMonth: (stripePriceSixMonth.value() || '').trim(),
    yearly: (stripePriceYearly.value() || '').trim(),
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
  { secrets: [stripeSecretKey, stripePriceMonthly, stripePriceSixMonth, stripePriceYearly] },
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
  { secrets: [stripePriceMonthly, stripePriceSixMonth, stripePriceYearly] },
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

/**
 * Updates a user doc only if it exists. Webhook events can reference Stripe
 * customers whose metadata.userId maps to no Firestore user (e.g. test-mode
 * customers or already-deleted accounts). Calling .update() on a missing doc
 * throws NOT_FOUND, which would surface to Stripe as HTTP 500 and trigger
 * endless retries. Returns true if updated, false if the user no longer exists.
 */
async function updateUserIfExists(db, uid, data) {
  const ref = db.collection('users').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) {
    console.warn(`[handleStripeWebhook] User ${uid} not found — skipping update.`);
    return false;
  }
  await ref.update(data);
  return true;
}

exports.handleStripeWebhook = onRequest(
  {
    secrets: [stripeSecretKey, stripeWebhookSecret, stripePriceMonthly, stripePriceSixMonth, stripePriceYearly],
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

    const stripeKeyValue = (stripeSecretKey.value() || '').trim();
    if (!stripeKeyValue) {
      console.error('STRIPE_SECRET_KEY is not configured.');
      return res.status(500).send('Stripe secret key missing.');
    }
    const stripe = require('stripe')(stripeKeyValue);
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
          const uid = session.metadata?.userId || session.client_reference_id;

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

          // Step 17: Subscription abuse monitoring (multi-account sharing check)
          const abuseQuery = await db.collection('users')
            .where('stripeCustomerId', '==', session.customer)
            .get();
          if (!abuseQuery.empty) {
            const distinctUids = abuseQuery.docs.map(doc => doc.id).filter(id => id !== uid);
            if (distinctUids.length > 0) {
              console.warn(`[subscriptionAbuse] Stripe Customer ID ${session.customer} is shared between current user ${uid} and other users: ${distinctUids.join(', ')}`);
              
              updateData.isFlaggedSubscriptionAbuse = true;
              updateData.subscriptionAbuseReason = `Shared Stripe Customer ID ${session.customer} with: ${distinctUids.join(', ')}`;
              
              await db.collection('subscription_abuse_logs').add({
                stripeCustomerId: session.customer,
                userId: uid,
                sharedWithUids: distinctUids,
                detectedAt: admin.firestore.FieldValue.serverTimestamp()
              });
              
              await logAdminAction('system', 'subscription_abuse_detected', uid, `Shared Stripe Customer ID with ${distinctUids.join(', ')}`);
            }
          }

          await updateUserIfExists(db, uid, updateData);
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
            await updateUserIfExists(db, uid, updateData);
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

            await updateUserIfExists(db, uid, invoiceUpdate);
          }
          break;
        }

        case 'invoice.payment_failed': {
          const invoice = event.data.object;
          const customer = await stripe.customers.retrieve(invoice.customer);
          const uid = customer.metadata?.userId || customer.metadata?.firebaseUid;

          if (uid) {
            await updateUserIfExists(db, uid, {
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
      // Only transient infrastructure errors should return 500 so Stripe retries.
      // Permanent/data errors (bad payload, missing user, etc.) are acknowledged
      // with 200 so Stripe stops retrying a request that can never succeed —
      // this is what clears a backlog of repeated 500 failures.
      const code = error?.code || error?.type;
      const transient =
        code === 'unavailable' ||
        code === 'deadline-exceeded' ||
        code === 'resource-exhausted' ||
        error?.type === 'StripeConnectionError' ||
        error?.type === 'StripeAPIError' ||
        error?.type === 'StripeRateLimitError';
      if (transient) {
        return res.status(500).send('Temporary processing error — retry expected.');
      }
      return res.status(200).send('Acknowledged (non-retryable processing issue logged).');
    }
  });

/**
 * verifySubscription - Source of truth for premium status.
 * Queries Stripe API directly (not just stale Firestore) so this works
 * even when the webhook never fired (e.g. first purchase in test mode).
 * Also writes the authoritative status back to Firestore.
 */
exports.verifySubscription = onCall(
  { secrets: [stripeSecretKey, stripePriceMonthly, stripePriceSixMonth, stripePriceYearly] },
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

    // ── Fast path: no Stripe customer means IAP is the only paid path ──────
    if (!stripeCustomerId) {
      console.log(`[verifySubscription] No stripeCustomerId for uid=${uid}`);
      if (isInAppTrial) {
        return { isPremium: false, expiresAt: null };
      }
      // Do NOT trust subscriptionPlan/subscriptionStatus alone — Firestore
      // rules restrict client writes on those fields to non-paid values, but
      // as defense-in-depth we corroborate against iapTransactionId, which is
      // only ever written by verifyIapPurchase via the Admin SDK.
      const expiry = userData.billingPeriodEnd;
      const notExpired = !expiry || expiry.toMillis() > Date.now();
      const isPremiumIap = !!userData.iapTransactionId && notExpired;
      return { isPremium: isPremiumIap, expiresAt: expiry ? expiry.toMillis() : null };
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

// ─────────────────────────────────────────────────────────────────────────────
// In-App Purchase verification (Apple App Store + Google Play)
//
// Replaces the temporary client-side premium grant with secure server-side
// receipt verification. Writes the SAME Firestore subscription fields the Stripe
// webhook uses, so the app + admin panel are unaffected.
// ─────────────────────────────────────────────────────────────────────────────
const APP_STORE_KEY_ID = '85584667FU';
const APP_STORE_ISSUER_ID = '04d91ed2-c0a2-446d-8dee-ab0eef9d63e8';
const IOS_BUNDLE_ID = 'com.swanmatch.app';
const ANDROID_PACKAGE = 'com.swanmatch.app';

/** Maps a store product ID to the plan label/period stored on the user doc. */
function iapPlanFromProductId(productId) {
  const id = (productId || '').toLowerCase();
  if (id.includes('6month') || id.includes('sixmonth')) {
    return { name: 'Six Month', period: 'sixMonth' };
  }
  if (id.includes('year')) {
    return { name: 'Yearly', period: 'yearly' };
  }
  return { name: 'Monthly', period: 'monthly' };
}

/** Decodes the payload of an Apple JWS (the API call itself is authenticated). */
function decodeJwsPayload(jws) {
  const parts = (jws || '').split('.');
  if (parts.length < 2) return null;
  try {
    return JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
  } catch (_) {
    return null;
  }
}

/**
 * Verifies an iOS subscription via the App Store Server API (prod then sandbox).
 * Returns { checked, valid, entitled, productId, expiresMs, originalTransactionId,
 * status, revoked }. `checked` = Apple actually answered (so a "not entitled"
 * verdict is definitive); network/5xx errors leave it false.
 */
async function verifyAppleTransaction(transactionId, signingKey) {
  if (!transactionId) return { checked: false, valid: false };
  const { AppStoreServerAPIClient, Environment } =
    require('@apple/app-store-server-library');
  let notFound = 0;
  for (const env of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      const client = new AppStoreServerAPIClient(
        signingKey, APP_STORE_KEY_ID, APP_STORE_ISSUER_ID, IOS_BUNDLE_ID, env,
      );
      const resp = await client.getAllSubscriptionStatuses(transactionId);
      for (const group of resp.data || []) {
        for (const lt of group.lastTransactions || []) {
          const tx = decodeJwsPayload(lt.signedTransactionInfo);
          if (!tx) continue;
          const renewal = decodeJwsPayload(lt.signedRenewalInfo) || {};
          const status = typeof lt.status === 'number' ? lt.status : null;
          // Refunded / revoked purchases never grant access.
          const revoked = !!tx.revocationDate || status === 5;
          let expiresMs = Number(tx.expiresDate || 0);
          // In Apple's billing grace period access continues until the grace end.
          if (status === 4 && renewal.gracePeriodExpiresDate) {
            expiresMs = Math.max(expiresMs, Number(renewal.gracePeriodExpiresDate));
          }
          const entitled = !revoked && (status !== null
            ? iapEntitlements.appleStatusEntitled(status)
            : expiresMs > Date.now());
          return {
            checked: true,
            valid: entitled,
            entitled,
            productId: tx.productId,
            expiresMs,
            originalTransactionId: tx.originalTransactionId || lt.originalTransactionId || null,
            status,
            revoked,
          };
        }
      }
      // Apple answered but has no subscription for this transaction.
      return { checked: true, valid: false, entitled: false };
    } catch (e) {
      if (e && e.httpStatusCode === 404) notFound++;
      console.log(`Apple verify (${env}) error: ${e.message || e}`);
    }
  }
  // Unknown to both environments = definitive; anything else = try later.
  return notFound === 2
    ? { checked: true, valid: false, entitled: false }
    : { checked: false, valid: false };
}

/**
 * Verifies an Android subscription purchase token via the Play Developer API.
 * Same verdict shape as verifyAppleTransaction.
 */
async function verifyGooglePurchase(purchaseToken) {
  if (!purchaseToken) return { checked: false, valid: false };
  const { google } = require('googleapis');
  let data;
  try {
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const authClient = await auth.getClient();
    const androidpublisher = google.androidpublisher({ version: 'v3', auth: authClient });
    const res = await androidpublisher.purchases.subscriptionsv2.get({
      packageName: ANDROID_PACKAGE,
      token: purchaseToken,
    });
    data = res.data || {};
  } catch (e) {
    const code = Number(e && (e.code || (e.response && e.response.status)));
    console.log(`Google verify error: ${code} ${e.message || e}`);
    // 404/410 = token unknown or long expired — definitive.
    return code === 404 || code === 410
      ? { checked: true, valid: false, entitled: false }
      : { checked: false, valid: false };
  }
  const li = (data.lineItems || [])[0] || {};
  const expiresMs = li.expiryTime ? new Date(li.expiryTime).getTime() : 0;
  const state = data.subscriptionState;
  // CANCELED = auto-renew turned off; still entitled until the period ends.
  const canceled = state === 'SUBSCRIPTION_STATE_CANCELED';
  const entitled =
    state === 'SUBSCRIPTION_STATE_ACTIVE' ||
    state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
    (canceled && expiresMs > Date.now());
  // With one subscription (`swan_premium`) + base plans, the productId no longer
  // tells the tier — the BASE PLAN id does (`monthly` / `sixmonth` / `yearly`).
  const basePlanId = li.offerDetails && li.offerDetails.basePlanId;
  return {
    checked: true, valid: entitled, entitled, canceled,
    productId: li.productId, planId: basePlanId, expiresMs,
  };
}

/** Store check used by the periodic refresh job (adds the plan name). */
async function verifyStorePurchase(source, ids, signingKey) {
  let r;
  if (source === 'app_store') {
    r = await verifyAppleTransaction(ids.originalTransactionId || ids.transactionId, signingKey);
  } else if (source === 'google_play') {
    r = await verifyGooglePurchase(ids.purchaseToken);
  } else {
    return { checked: false };
  }
  if (r && r.checked && (r.planId || r.productId)) {
    const plan = iapPlanFromProductId(r.planId || r.productId);
    r.planName = plan.name;
    r.planPeriod = plan.period;
  }
  return r;
}

/**
 * verifyIapPurchase - Securely verifies a native purchase and grants premium.
 * data: { productId, source: 'app_store'|'google_play', verificationData, transactionId }
 */
exports.verifyIapPurchase = onCall(
  { secrets: [appStoreIapKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const uid = request.auth.uid;
    const { productId, source, verificationData, transactionId } = request.data || {};
    if (!productId || !source) {
      throw new HttpsError('invalid-argument', 'Missing purchase data.');
    }

    await enforceRateLimit(uid, 'verifyIap', 10, 60 * 1000);

    let result;
    if (source === 'app_store') {
      const signingKey = (appStoreIapKey.value() || '').trim();
      if (!signingKey) {
        throw new HttpsError('failed-precondition', 'App Store key not configured.');
      }
      result = await verifyAppleTransaction(transactionId, signingKey);
    } else if (source === 'google_play') {
      result = await verifyGooglePurchase(verificationData);
    } else {
      throw new HttpsError('invalid-argument', `Unknown source: ${source}`);
    }

    if (!result || !result.valid) {
      throw new HttpsError('failed-precondition', 'Purchase could not be verified.');
    }

    const verifiedProductId = result.productId || productId;
    const db = admin.firestore();

    // One purchase = one account. Claim it for the caller; reject if another
    // account already owns it (a transaction id read off someone's public
    // profile, or a second account restoring on the same phone).
    const claimKey = iapEntitlements.claimKeyFor(source, {
      originalTransactionId: result.originalTransactionId,
      transactionId,
      purchaseToken: source === 'google_play' ? verificationData : null,
    });
    if (claimKey) {
      try {
        await iapEntitlements.claimPurchase(db, {
          uid,
          key: claimKey,
          source,
          productId: verifiedProductId,
          transactionId: transactionId || null,
          originalTransactionId: result.originalTransactionId || null,
          purchaseToken: source === 'google_play' ? verificationData : null,
          expiresMs: result.expiresMs || null,
        });
      } catch (e) {
        if (e instanceof iapEntitlements.PurchaseOwnedByAnotherAccount) {
          console.warn(`[verifyIapPurchase] uid=${uid} tried to claim ${claimKey} owned by another account`);
          throw new HttpsError('already-exists',
            'This subscription is already linked to another Swan Match account.');
        }
        throw e;
      }
    }
    // Prefer the base plan id (Android) for the tier; fall back to the product
    // id (iOS product ids still encode the tier, e.g. `swan_premium_6month`).
    const plan = iapPlanFromProductId(result.planId || verifiedProductId);

    const updateData = {
      subscriptionPlan: 'premium',
      subscriptionStatus: 'active',
      subscriptionName: plan.name,
      subscriptionPeriod: plan.period,
      cancelAtPeriodEnd: result.canceled === true,
      iapSource: source,
      ...(claimKey ? { iapClaimKey: claimKey } : {}),
      iapProductId: verifiedProductId,
      premiumActivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      freeTrialEndsAt: admin.firestore.FieldValue.delete(),
      freeTrialStartedAt: admin.firestore.FieldValue.delete(),
    };
    if (transactionId) updateData.iapTransactionId = transactionId;
    if (result.expiresMs && Number.isFinite(result.expiresMs)) {
      updateData.billingPeriodEnd =
        admin.firestore.Timestamp.fromMillis(result.expiresMs);
    }

    const userRef = db.collection('users').doc(uid);
    const snap = await userRef.get();
    if (!snap.exists) {
      throw new HttpsError('not-found', 'User profile not found.');
    }
    await userRef.set(updateData, { merge: true });

    console.log(`[verifyIapPurchase] premium granted uid=${uid} source=${source} product=${verifiedProductId}`);
    return { isPremium: true, plan: plan.name, expiresAt: result.expiresMs || null };
  },
);

/**
 * refreshIapSubscriptions — scheduled. Re-checks App Store / Google Play
 * subscriptions whose paid period ends within 36h (or has ended) and either
 * records the renewal or downgrades the account to free (cancelled, lapsed,
 * refunded). Before this, a store subscription never expired.
 * Store outages are skipped (retried next run), never treated as expiry.
 */
exports.refreshIapSubscriptions = onSchedule(
  { schedule: 'every 12 hours', secrets: [appStoreIapKey], timeoutSeconds: 300 },
  async () => {
    const signingKey = (appStoreIapKey.value() || '').trim();
    const stats = await iapEntitlements.refreshDueIapSubscriptions(
      admin.firestore(),
      (source, ids) => verifyStorePurchase(source, ids, signingKey),
    );
    console.log(`[refreshIapSubscriptions] ${JSON.stringify(stats)}`);
  },
);

/**
 * getStripePrices - Returns Stripe price details with server-side per-month
 * calculation so the client never hard-codes prices.
 *
 * Expected data: { priceIds: string[] }
 * Returns: { prices: { [priceId]: { id, amount, currency, interval,
 *   intervalCount, formattedAmount, formattedPerMonth, productName } } }
 */
exports.getStripePrices = onCall(
  { secrets: [stripeSecretKey, stripePriceMonthly, stripePriceSixMonth, stripePriceYearly] },
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
  if (!isAdminAuth(request)) {
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

  if (!email || typeof email !== 'string') {
    throw new HttpsError('invalid-argument', 'The function must be called with a valid "email".');
  }

  // Rate limit per-email (prevents hammering one address) AND globally
  // (prevents enumerating many different addresses by rotating targets).
  await enforceRateLimit(null, 'checkAuthProviders', 10, 60 * 1000, `email_${email.toLowerCase().trim()}`);
  await enforceRateLimit(null, 'checkAuthProviders', 60, 60 * 1000, 'global');

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
exports.onUserSoftDeleted = onDocumentUpdated(
  { document: 'users/{uid}', secrets: [stripeSecretKey] },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const uid = event.params.uid;

    // Only trigger if isDeleted changes from false to true
    if (!before.isDeleted && after.isDeleted === true) {
      console.log(`[onUserSoftDeleted] Triggered for user ${uid}.`);

      // 1. Cancel any active Stripe subscription so a deleted user is never
      //    billed again (otherwise their card stays on file and keeps renewing).
      const subId = after.stripeSubscriptionId;
      if (subId) {
        try {
          const stripe = require('stripe')((stripeSecretKey.value() || '').trim());
          await stripe.subscriptions.cancel(subId);
          console.log(`[onUserSoftDeleted] Cancelled Stripe subscription ${subId} for ${uid}.`);
        } catch (error) {
          if ((error.code || error.type) === 'resource_missing') {
            console.log(`[onUserSoftDeleted] Subscription ${subId} already gone for ${uid}.`);
          } else {
            console.error(`[onUserSoftDeleted] Failed to cancel subscription ${subId} for ${uid}:`, error.message);
          }
        }
      }

      // 2. Delete the Firebase Auth account (even if the user force-closed the app).
      console.log(`[onUserSoftDeleted] Deleting Firebase Auth account for ${uid}.`);
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
  }
);

// ─── Login Throttling ────────────────────────────────────────────────────────
// Secure, persistent Firestore-backed throttling tracker (prevents bypasses on scaling/cold starts)
// Reads and writes to private '_loginAttempts' collection which is completely hidden from clients.

/**
 * trackLoginAttempt — called from the client BEFORE signInWithEmailAndPassword.
 * Throws resource-exhausted if the user has exceeded the max attempts within
 * the sliding window. This prevents brute-force password guessing.
 */
exports.trackLoginAttempt = onCall(async (request) => {
  const { email, deviceId, deviceModel, osVersion, platform } = request.data;
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

  // Retrieve IP and user agent
  const ip = request.rawRequest?.ip || request.rawRequest?.headers['x-forwarded-for'] || 'unknown';
  const userAgent = request.rawRequest?.headers['user-agent'] || 'unknown';

  // Persistent audit log of attempt
  await db.collection('_loginLogs').add({
    email: key,
    ip,
    userAgent,
    deviceId: deviceId || 'unknown',
    deviceModel: deviceModel || 'unknown',
    osVersion: osVersion || 'unknown',
    platform: platform || 'unknown',
    status: 'attempt',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

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
  const { email, deviceId, deviceModel, osVersion, platform } = request.data;
  if (!email || typeof email !== 'string') return { cleared: false };
  const key = email.toLowerCase().trim();

  const db = admin.firestore();
  await db.collection('_loginAttempts').doc(key).delete();

  // Retrieve IP and user agent
  const ip = request.rawRequest?.ip || request.rawRequest?.headers['x-forwarded-for'] || 'unknown';
  const userAgent = request.rawRequest?.headers['user-agent'] || 'unknown';

  // Audit successful login
  await db.collection('_loginLogs').add({
    email: key,
    ip,
    userAgent,
    deviceId: deviceId || 'unknown',
    deviceModel: deviceModel || 'unknown',
    osVersion: osVersion || 'unknown',
    platform: platform || 'unknown',
    status: 'success',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { cleared: true };
});

/**
 * trackLoginFailure — called from the client after a FAILED login.
 * Increments the attempt counter for that email.
 */
exports.trackLoginFailure = onCall(async (request) => {
  const { email, deviceId, deviceModel, osVersion, platform } = request.data;
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

  // Retrieve IP and user agent
  const ip = request.rawRequest?.ip || request.rawRequest?.headers['x-forwarded-for'] || 'unknown';
  const userAgent = request.rawRequest?.headers['user-agent'] || 'unknown';

  // Audit failed login
  await db.collection('_loginLogs').add({
    email: key,
    ip,
    userAgent,
    deviceId: deviceId || 'unknown',
    deviceModel: deviceModel || 'unknown',
    osVersion: osVersion || 'unknown',
    platform: platform || 'unknown',
    status: 'failure',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
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
  // Mirrors firestore.rules' isAdmin(): prefer the unforgeable custom-claim
  // "badge" set by the admin-web backend (set_admin_claims.js / adminRoutes.js)
  // when an admin account is created. The email fallback is only a backup and
  // requires a *verified* email — an unverified `x@swan-match.com` signup must
  // not be able to call admin-gated functions (suspend/refund/etc).
  if (!request.auth) return false;
  if (request.auth.token.isAdmin === true) return true;
  const email = request.auth.token.email || '';
  return request.auth.token.email_verified === true && (
    email === 'admin@swan-match.com' ||
    email === 'sasikumar.s9951@gmail.com'
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

/** Human-readable category labels for the admin dashboard. Shared by
 *  submitReport and reportConnectionVideo. */
const REPORT_CATEGORY_LABELS = {
  harassment: 'Harassment / Threats',
  fake_profile: 'Fake Profile / Catfish',
  scam: 'Scam / Fraud',
  inappropriate: 'Inappropriate Content',
  underage: 'Underage User',
  spam: 'Spam / Solicitation',
  other: 'Other',
};

/**
 * Auto-assigns a report priority (P1=critical, P2=high, P3=general):
 * category-first (reliable), keyword fallback for 'other' or a
 * missing/unrecognized category. Extracted so submitReport (chat-report flow)
 * and reportConnectionVideo (pre-chat video-report flow) share identical
 * triage logic rather than drifting apart.
 */
function assignReportPriority(reason, category) {
  const CATEGORY_PRIORITY = {
    harassment: 'P1',
    underage: 'P1',
    fake_profile: 'P2',
    scam: 'P2',
    inappropriate: 'P2',
    spam: 'P3',
    other: null, // null = fall through to keyword scan
  };
  const P1_KEYWORDS = ['threat', 'kill', 'harm', 'suicide', 'underage', 'minor', 'child', 'blackmail', 'extort'];
  const P2_KEYWORDS = ['scam', 'fraud', 'fake', 'impersonat', 'catfish', 'money', 'escort', 'spam', 'harass', 'stalk'];

  let priority = 'P3'; // Default
  const cat = (category || '').toLowerCase().trim();

  if (cat && CATEGORY_PRIORITY[cat] !== undefined) {
    if (CATEGORY_PRIORITY[cat] !== null) {
      priority = CATEGORY_PRIORITY[cat];
    } else {
      // 'other' category: fall back to keyword scan
      const reasonLower = (reason || '').toLowerCase();
      if (P1_KEYWORDS.some(k => reasonLower.includes(k))) priority = 'P1';
      else if (P2_KEYWORDS.some(k => reasonLower.includes(k))) priority = 'P2';
    }
  } else {
    // No category sent (old app version): full keyword scan
    const reasonLower = (reason || '').toLowerCase();
    if (P1_KEYWORDS.some(k => reasonLower.includes(k))) priority = 'P1';
    else if (P2_KEYWORDS.some(k => reasonLower.includes(k))) priority = 'P2';
  }

  return priority;
}

/** Submit a report. Rate limited: 5 reports per hour per user. */
exports.submitReport = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  await enforceRateLimit(request.auth.uid, 'submitReport', 5, 3600 * 1000);

  const { reportedUid, reason, category } = request.data;
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

  // Auto-assign priority: category-first (reliable), keyword fallback for 'other' or missing
  const priority = assignReportPriority(reason, category);
  const cat = (category || '').toLowerCase().trim();

  // Create report
  await db.collection('reports').add({
    reportedUid,
    reportedBy: reporterUid,
    reason: reason.trim(),
    category: cat || null,
    categoryLabel: REPORT_CATEGORY_LABELS[cat] || null,
    priority, // P1=critical, P2=high, P3=general
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

  // Remove connections (connection record, chat)
  try {
    // Video-first redesign: instead of tearing down likes/matches/interests
    // docs, decline the connections/{connectionId} doc between these two
    // users (same sorted-id convention used by submitConnectionRequest /
    // respondToConnection) and flag it reportedAt so
    // expireConnectionRequests/cleanupRejectedIntroVideos-style jobs
    // preserve the video as evidence until an admin resolves the report.
    // Reporting can happen before any connection ever existed (e.g.
    // reporting someone from their Discover profile before connecting) —
    // in that case there's nothing to update, so just skip it.
    const connectionId = [reporterUid, reportedUid].sort().join('_');
    const connectionRef = db.collection('connections').doc(connectionId);
    const connectionSnap = await connectionRef.get();
    if (connectionSnap.exists) {
      await connectionRef.update({
        status: 'declined',
        reportedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Delete chat thread (chatId shares the same sorted-id convention).
    const chatRef = db.collection('chats').doc(connectionId);
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
/**
 * Counts the reports that may auto-suspend [reportedUid]. Previously every
 * report counted — one account could file 5 reports (or 3 "P1") and get
 * anyone suspended. Now:
 *  - one vote per reporter (repeat reports from the same person count once);
 *  - only reporters whose own profile is admin-approved (and not suspended
 *    or deleted) count, so throwaway accounts can't vote;
 *  - only reports an admin hasn't Closed;
 *  - only reports filed after the user's last suspension / reinstatement,
 *    so a reinstated user isn't re-suspended by the old reports.
 * Reports are created only by the submitReport / reportConnectionVideo
 * callables (firestore.rules), so priority is always server-assigned.
 */
async function countAutoSuspendVotes(db, reportedUid) {
  const userSnap = await db.collection('users').doc(reportedUid).get();
  const user = userSnap.exists ? userSnap.data() : {};
  const alreadySuspended = String(user.account || '').toLowerCase() === 'suspended';
  const millis = (ts) => (ts && typeof ts.toMillis === 'function' ? ts.toMillis() : 0);
  const since = Math.max(millis(user.suspendedAt), millis(user.unsuspendedAt));

  const snapshot = await db.collection('reports')
    .where('reportedUid', '==', reportedUid)
    .get();

  const reporterHasP1 = new Map();
  for (const doc of snapshot.docs) {
    const r = doc.data();
    const reporter = r.reportedBy;
    if (!reporter || typeof reporter !== 'string' || reporter === reportedUid) continue;
    const status = String(r.status || 'Open').toLowerCase();
    if (status === 'closed') continue;
    // Server timestamps are always set by the callables; a missing one
    // (just-written) is treated as "now".
    const filedAt = millis(r.reportedAt) || millis(r.createdAt) || Date.now();
    if (filedAt <= since) continue;
    const isP1 = r.priority === 'P1' || r.priority === 1;
    reporterHasP1.set(reporter, reporterHasP1.get(reporter) === true || isP1);
  }

  const reporterIds = [...reporterHasP1.keys()];
  let reporterCount = 0;
  let p1ReporterCount = 0;
  for (let i = 0; i < reporterIds.length; i += 100) {
    const refs = reporterIds.slice(i, i + 100).map((id) => db.collection('users').doc(id));
    const snaps = await db.getAll(...refs);
    for (const s of snaps) {
      if (!s.exists) continue;
      const d = s.data();
      const approved = String(d.profileApprovalStatus || '').toLowerCase() === 'approved';
      const suspended = String(d.account || '').toLowerCase() === 'suspended';
      const deleted = d.isDeleted === true || String(d.status || '').toLowerCase() === 'deleted';
      if (!approved || suspended || deleted) continue;
      reporterCount++;
      if (reporterHasP1.get(s.id)) p1ReporterCount++;
    }
  }
  return { reporterCount, p1ReporterCount, alreadySuspended };
}

exports.onReportCreated = onDocumentCreated('reports/{reportId}', async (event) => {
  const report = event.data?.data();
  if (!report) return;

  const reportedUid = report.reportedUid;
  if (!reportedUid) return;

  try {
    const { reporterCount: reportCount, p1ReporterCount: p1Count, alreadySuspended } =
      await countAutoSuspendVotes(admin.firestore(), reportedUid);

    // Auto-suspend at 3+ distinct approved reporters with a P1 report, OR 5+
    // distinct approved reporters overall (see countAutoSuspendVotes).
    if (!alreadySuspended && (p1Count >= 3 || reportCount >= 5)) {
      const reason = p1Count >= 3 
        ? `Auto-suspended: received ${p1Count} P1 (Critical) reports` 
        : `Auto-suspended: received ${reportCount} total reports`;

      await admin.firestore().collection('users').doc(reportedUid).update({
        account: 'Suspended',
        suspensionReason: reason,
        suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
        suspendedBy: 'system',
      });

      await logAdminAction('system', 'auto_suspend', reportedUid, reason);
      console.log(`[autoSuspend] User ${reportedUid} suspended: ${reason}`);
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
  const { FieldValue } = require('firebase-admin/firestore');
  const userRef = db.collection('users').doc(uid);

  // update() only — never set/merge: this runs at app start, possibly before
  // signup has written the profile. Creating a stub users/{uid} doc here
  // would turn the signup profile write into a rules-denied update.
  const updateUserIfExists = async (data) => {
    try {
      await userRef.update(data);
    } catch (err) {
      if (err.code !== 5) throw err; // 5 = NOT_FOUND: no profile yet, skip
    }
  };

  try {
    // 1. Is this device associated with any suspended account?
    // Device → accounts mapping lives in the server-only deviceIndex
    // collection (no client access in firestore.rules), NOT on the profile
    // doc, which every signed-in user can read.
    const deviceDocId = String(deviceId).replace(/\//g, '_').slice(0, 700);
    const deviceRef = db.collection('deviceIndex').doc(deviceDocId);
    const deviceSnap = await deviceRef.get();
    const otherUids = ((deviceSnap.exists && deviceSnap.get('uids')) || [])
      .filter((u) => u !== uid)
      .slice(-30);
    let matchesSuspended = false;
    if (otherUids.length > 0) {
      const snaps = await db.getAll(...otherUids.map((u) => db.collection('users').doc(u)));
      matchesSuspended = snaps.some((s) => s.exists && s.get('account') === 'Suspended');
    }
    if (!matchesSuspended) {
      // Transitional: accounts not yet migrated still carry the old
      // lastLoginDeviceId on their profile. Remove once the
      // migrate_private_data script has been run in --apply mode.
      const legacy = await db.collection('users')
        .where('lastLoginDeviceId', '==', deviceId)
        .where('account', '==', 'Suspended')
        .limit(1)
        .get();
      matchesSuspended = !legacy.empty;
    }

    if (matchesSuspended) {
      console.warn(`[logSessionActivity] WARNING: Banned device login attempt: deviceId=${deviceId} uid=${uid}`);
      // Mark this account as flagged for matching a banned device fingerprint
      await updateUserIfExists({
        deviceMatchesSuspendedFingerprint: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    await deviceRef.set({
      uids: FieldValue.arrayUnion(uid),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    // 2. Securely append to the securityLogs subcollection
    const logRef = db.collection('users').doc(uid).collection('securityLogs').doc();
    await logRef.set({
      ipAddress: ip,
      deviceModel: model,
      brand: brand || 'unknown',
      osVersion: osVersion || 'unknown',
      deviceId: deviceId,
      sessionTrigger: sessionTrigger || 'app_start',
      lastActive: FieldValue.serverTimestamp(),
    });

    // 3. Activity timestamp only. IP / device details stay in the securityLogs
    // subcollection (owner + admin only) — the profile doc is readable by
    // every signed-in user, so they are removed from it here.
    await updateUserIfExists({
      lastLoginIp: FieldValue.delete(),
      lastLoginDeviceId: FieldValue.delete(),
      lastLoginDeviceModel: FieldValue.delete(),
      lastActiveAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
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
  { document: 'support_queries/{queryId}', secrets: [smtpUser, smtpPass] },
  async (event) => {
  // ─── SUPPORT WORKFLOW RECIPIENTS CONFIGURATION (EASILY REMOVABLE/EDITABLE) ──
  const TARGET_SUPPORT_INBOX = 'support@swan-match.com';
  const DEVELOPER_CC_ADDRESS = ''; // Set to secondary email if needed
  // ───────────────────────────────────────────────────────────────────────────

  const queryData = event.data?.data();
  if (!queryData) {
    console.log('[onSupportQueryCreated] No data in event');
    return;
  }

  const { userId, userName, userEmail, subject, message, deviceInfo } = queryData;
  console.log(`[onSupportQueryCreated] New query from user=${userId} (${userEmail}): ${subject}`);

  // Auto-assign priority based on subject/message keywords
  const combinedText = `${subject || ''} ${message || ''}`.toLowerCase();
  let ticketPriority = 'normal';
  const URGENT_KEYWORDS = ['urgent', 'emergency', 'hacked', 'stolen', 'threat', 'harassment', 'billing error', 'charged twice', 'safety'];
  const HIGH_KEYWORDS = ['refund', 'payment', 'subscription', 'suspended', 'banned', 'cannot login', 'account locked'];
  if (URGENT_KEYWORDS.some(k => combinedText.includes(k))) ticketPriority = 'urgent';
  else if (HIGH_KEYWORDS.some(k => combinedText.includes(k))) ticketPriority = 'high';

  // SLA tracking durations
  const slaDurations = {
    urgent: 2 * 60 * 60 * 1000,   // 2 hours
    high: 4 * 60 * 60 * 1000,     // 4 hours
    normal: 24 * 60 * 60 * 1000,  // 24 hours
  };
  const now = Date.now();
  const durationMs = slaDurations[ticketPriority] || slaDurations.normal;
  const slaDeadline = admin.firestore.Timestamp.fromMillis(now + durationMs);

  // Update the ticket document with computed priority and SLA details
  try {
    await event.data.ref.update({ 
      priority: ticketPriority,
      slaDeadline,
      slaDurationMs: durationMs,
      slaExceeded: false,
      status: 'open'
    });
  } catch (e) {
    console.warn('[onSupportQueryCreated] Could not set priority/SLA:', e.message);
  }

  const smtpHost = 'smtp.gmail.com';
  const smtpPort = 587;
  const smtpUserVal = smtpUser.value() || '';
  const smtpPassVal = smtpPass.value() || '';

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
  { secrets: [smtpUser, smtpPass] },
  async (request) => {
  // 1. Enforce admin auth
  if (!isAdminAuth(request)) {
    throw new HttpsError('permission-denied', 'Only administrators can send support emails.');
  }

  const { toEmail, subject, htmlMessage } = request.data;
  if (!toEmail || !subject || !htmlMessage) {
    throw new HttpsError('invalid-argument', 'Missing required fields (toEmail, subject, htmlMessage).');
  }

  const smtpUserVal = smtpUser.value() || '';
  const smtpPassVal = smtpPass.value() || '';

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


// ============================================================================
// BATCH 1 — STEP 13/17: CHARGEBACK FRAUD AUTO-SUSPENSION
// ============================================================================
// Handles Stripe dispute (chargeback) events. When a user initiates a
// chargeback, their account is auto-suspended and flagged. Admins are notified.
// This is added as NEW webhook cases inside a separate onRequest handler to
// avoid modifying the existing handleStripeWebhook function.
// ============================================================================

/**
 * handleChargebackWebhook — Separate webhook endpoint for chargeback/dispute events.
 * Configure this URL in Stripe Dashboard under Webhooks for:
 *   - charge.dispute.created
 *   - charge.dispute.closed
 *
 * Webhook URL: https://us-central1-swan-match.cloudfunctions.net/handleChargebackWebhook
 */
exports.handleChargebackWebhook = onRequest(
  {
    secrets: [stripeSecretKey, stripeWebhookSecret],
    rawBody: true,
  },
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const webhookSecretValue = stripeWebhookSecret.value();

    if (!webhookSecretValue || !sig) {
      return res.status(400).send('Missing webhook configuration or signature.');
    }

    const stripe = require('stripe')(stripeSecretKey.value().trim());
    let event;

    try {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecretValue);
    } catch (err) {
      console.error('[chargebackWebhook] Signature verification failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    const db = admin.firestore();

    try {
      if (event.type === 'charge.dispute.created') {
        const dispute = event.data.object;
        const customerId = dispute.customer;
        console.log(`[chargebackWebhook] Dispute created for customer=${customerId} amount=${dispute.amount} reason=${dispute.reason}`);

        // Find user by stripeCustomerId
        const userSnapshot = await db.collection('users')
          .where('stripeCustomerId', '==', customerId)
          .limit(1)
          .get();

        if (!userSnapshot.empty) {
          const userDoc = userSnapshot.docs[0];
          const uid = userDoc.id;

          // Auto-suspend the user
          await db.collection('users').doc(uid).update({
            account: 'Suspended',
            suspensionReason: `Auto-suspended: Chargeback dispute filed (${dispute.reason}). Dispute amount: $${(dispute.amount / 100).toFixed(2)}`,
            suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
            suspendedBy: 'system',
            chargebackFlag: true,
            lastDisputeId: dispute.id,
            lastDisputeReason: dispute.reason,
            lastDisputeAmount: dispute.amount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Log to audit
          await logAdminAction('system', 'chargeback_auto_suspend', uid,
            `Chargeback dispute ${dispute.id}: reason=${dispute.reason}, amount=$${(dispute.amount / 100).toFixed(2)}`);

          // Create admin notification
          await db.collection('admin_alerts').add({
            type: 'chargeback',
            severity: 'critical',
            title: `⚠️ Chargeback Alert: User ${uid}`,
            message: `User filed a $${(dispute.amount / 100).toFixed(2)} chargeback (${dispute.reason}). Account auto-suspended.`,
            userId: uid,
            disputeId: dispute.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            resolved: false,
          });

          console.log(`[chargebackWebhook] User ${uid} auto-suspended due to chargeback.`);
        } else {
          console.warn(`[chargebackWebhook] No user found for Stripe customer ${customerId}`);
        }
      }

      if (event.type === 'charge.dispute.closed') {
        const dispute = event.data.object;
        console.log(`[chargebackWebhook] Dispute closed: id=${dispute.id} status=${dispute.status}`);

        // Log the resolution
        const customerId = dispute.customer;
        const userSnapshot = await db.collection('users')
          .where('stripeCustomerId', '==', customerId)
          .limit(1)
          .get();

        if (!userSnapshot.empty) {
          const uid = userSnapshot.docs[0].id;
          await logAdminAction('system', 'chargeback_dispute_closed', uid,
            `Dispute ${dispute.id} closed with status: ${dispute.status}`);

          // If dispute was won by us (lost by customer), optionally unsuspend
          if (dispute.status === 'won') {
            await db.collection('users').doc(uid).update({
              chargebackFlag: false,
              lastDisputeResolution: 'won',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`[chargebackWebhook] Dispute won — cleared chargeback flag for user ${uid}`);
          }
        }
      }

      res.json({ received: true });
    } catch (error) {
      console.error('[chargebackWebhook] Processing error:', error);
      res.status(500).send('Webhook processing error');
    }
  }
);


// ============================================================================
// BATCH 1 — STEP 15: AUTOMATED DAILY FIRESTORE BACKUP
// ============================================================================
// Scheduled Cloud Function that triggers a Firestore export to a GCS bucket
// every day at 2 AM UTC. This ensures automated backups without manual runs.
// Requires: GCS bucket 'swan-match-backups' to exist in the project.
// ============================================================================

exports.scheduledFirestoreBackup = onSchedule(
  { schedule: '0 2 * * *', timeZone: 'UTC' }, // Runs daily at 2 AM UTC
  async (_event) => {
    const projectId = 'swan-match';
    const bucketName = `gs://${projectId}-backups`;
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const outputUri = `${bucketName}/firestore-exports/${timestamp}`;

    console.log(`[scheduledBackup] Starting automated Firestore export to ${outputUri}`);

    try {
      // Use the Firestore admin API to trigger an export
      const client = new admin.firestore.v1.FirestoreAdminClient();
      const databaseName = client.databasePath(projectId, '(default)');

      const [response] = await client.exportDocuments({
        name: databaseName,
        outputUriPrefix: outputUri,
        collectionIds: [], // Empty = export all collections
      });

      console.log(`[scheduledBackup] Export operation started: ${response.name}`);

      // Log backup record
      await admin.firestore().collection('_system_backups').add({
        status: 'initiated',
        outputUri: outputUri,
        operationName: response.name,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: 'automated_daily',
      });

      console.log('[scheduledBackup] Backup record logged successfully.');
    } catch (err) {
      console.error('[scheduledBackup] Export failed:', err.message);

      // Log failure
      await admin.firestore().collection('_system_backups').add({
        status: 'failed',
        error: err.message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: 'automated_daily',
      });
    }
  }
);


// ============================================================================
// BATCH 1 — STEP 17: SPAM/KEYWORD TEXT FILTER
// ============================================================================
// Scans user bios and chat messages against a configurable banned-words list
// stored in Firestore. Flags or blocks content containing prohibited keywords.
// Called from the client before saving bio, or triggered on message creation.
// ============================================================================

/**
 * checkContentFilter — Client calls this before saving profile bio or sending
 * sensitive text. Returns { flagged: true/false, matches: [...] }.
 */
exports.checkContentFilter = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const { text, context } = request.data; // context: 'bio' | 'message' | 'name'

  if (!text || typeof text !== 'string') {
    return { flagged: false, matches: [] };
  }

  // Built-in default keyword blocklist (covers escort, spam, crypto scams, etc.)
  const DEFAULT_BLOCKLIST = [
    // Escort/solicitation
    'escort', 'sugar daddy', 'sugar mommy', 'sugar baby', 'pay per meet',
    'companionship fee', 'hourly rate', 'overnight rate', 'fwb for money',
    // Crypto/financial scams
    'invest with me', 'crypto opportunity', 'guaranteed returns', 'forex trading',
    'binary options', 'send me bitcoin', 'wire transfer', 'western union',
    'cash app me', 'venmo me', 'paypal me',
    // Explicit solicitation
    'onlyfans', 'only fans', 'premium snapchat', 'premium snap', 'adult content',
    'nudes for sale', 'selling pics', 'dm for price',
    // Harassment/threats
    'kill yourself', 'kys', 'i will find you', 'i know where you live',
    // Spam patterns
    'click this link', 'free iphone', 'congratulations you won',
    'make money fast', 'work from home opportunity',
  ];

  const normalizedText = text.toLowerCase().trim();
  const matches = [];

  // Check against default blocklist
  for (const keyword of DEFAULT_BLOCKLIST) {
    if (normalizedText.includes(keyword.toLowerCase())) {
      matches.push(keyword);
    }
  }

  // Check against custom blocklist from Firestore (admin-configurable)
  try {
    const customDoc = await admin.firestore().collection('_system_config').doc('content_filter').get();
    if (customDoc.exists) {
      const customWords = customDoc.data().blocklist || [];
      for (const word of customWords) {
        if (typeof word === 'string' && normalizedText.includes(word.toLowerCase())) {
          matches.push(word);
        }
      }
    }
  } catch (e) {
    console.warn('[contentFilter] Could not load custom blocklist:', e.message);
  }

  if (matches.length > 0) {
    console.log(`[contentFilter] Flagged content from uid=${request.auth.uid} context=${context}: matches=${matches.join(', ')}`);

    // Log flagged content for admin review
    await admin.firestore().collection('flagged_content').add({
      userId: request.auth.uid,
      context: context || 'unknown',
      textSnippet: normalizedText.substring(0, 200), // Store only first 200 chars
      matches: matches,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewed: false,
    });
  }

  return {
    flagged: matches.length > 0,
    matches: matches,
  };
});


// ============================================================================
// BATCH 1 — STEP 18: ADMIN REFUND PROCESSOR
// ============================================================================
// Allows admins to process refunds directly from the web dashboard instead of
// manually logging into Stripe Dashboard. Creates a Stripe refund and logs it.
// ============================================================================

exports.processRefund = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    // 1. Admin-only access
    if (!isAdminAuth(request)) {
      throw new HttpsError('permission-denied', 'Only administrators can process refunds.');
    }

    const { userId, reason, amount } = request.data;

    if (!userId || typeof userId !== 'string') {
      throw new HttpsError('invalid-argument', 'userId is required.');
    }

    const db = admin.firestore();
    const stripe = require('stripe')(stripeSecretKey.value().trim());

    try {
      // 2. Get user's Stripe customer ID
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw new HttpsError('not-found', 'User not found.');
      }

      const userData = userDoc.data();
      const customerId = userData.stripeCustomerId;

      if (!customerId) {
        throw new HttpsError('failed-precondition', 'User has no Stripe customer ID. No payments to refund.');
      }

      // 3. Get the latest charge for this customer
      const charges = await stripe.charges.list({
        customer: customerId,
        limit: 1,
      });

      if (!charges.data || charges.data.length === 0) {
        throw new HttpsError('not-found', 'No charges found for this customer.');
      }

      const latestCharge = charges.data[0];

      // 4. Create refund (full or partial)
      const refundParams = {
        charge: latestCharge.id,
        reason: 'requested_by_customer',
      };

      if (amount && typeof amount === 'number' && amount > 0) {
        refundParams.amount = Math.round(amount * 100); // Convert dollars to cents
      }

      const refund = await stripe.refunds.create(refundParams);

      // 5. Update user record
      await db.collection('users').doc(userId).update({
        lastRefundId: refund.id,
        lastRefundAmount: refund.amount,
        lastRefundDate: admin.firestore.FieldValue.serverTimestamp(),
        refundCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 6. Audit log
      await logAdminAction(
        request.auth.uid,
        'process_refund',
        userId,
        `Refund ${refund.id}: $${(refund.amount / 100).toFixed(2)} — ${reason || 'No reason provided'}`
      );

      console.log(`[processRefund] Refund ${refund.id} processed for user ${userId}: $${(refund.amount / 100).toFixed(2)}`);

      return {
        success: true,
        refundId: refund.id,
        amount: refund.amount / 100,
        status: refund.status,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('[processRefund] Error:', err.message);
      throw new HttpsError('internal', `Refund failed: ${err.message}`);
    }
  }
);


// ============================================================================
// BATCH 1 — STEP 20: RE-ENGAGEMENT EMAIL (PRE-BUILT)
// ============================================================================
// Scheduled function that sends re-engagement emails to inactive users.
// This function is pre-built and will activate once SMTP_USER and SMTP_PASS
// secrets are configured. Until then, it gracefully skips email sending.
// ============================================================================

exports.sendReEngagementEmails = onSchedule(
  { schedule: '0 11 * * 1', timeZone: 'UTC', secrets: [smtpUser, smtpPass] }, // Runs every Monday at 11 AM UTC
  async (_event) => {
    const smtpUserVal = smtpUser.value() || '';
    const smtpPassVal = smtpPass.value() || '';

    if (!smtpUserVal || !smtpPassVal) {
      console.log('[reEngagement] SMTP not configured. Skipping email re-engagement. Set SMTP_USER and SMTP_PASS to activate.');
      return;
    }

    const db = admin.firestore();
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    console.log('[reEngagement] Starting weekly email re-engagement scan...');

    try {
      const snapshot = await db.collection('users')
        .where('lastActiveAt', '<=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
        .get();

      if (snapshot.empty) {
        console.log('[reEngagement] No inactive users found for email re-engagement.');
        return;
      }

      const transporter = nodemailer.createTransport({
        host: 'smtp.gmail.com',
        port: 587,
        secure: false,
        auth: { user: smtpUserVal, pass: smtpPassVal },
      });

      let sentCount = 0;

      for (const doc of snapshot.docs) {
        const userData = doc.data();

        // Skip deleted, suspended, or users without email
        if (userData.isDeleted || userData.account === 'Suspended') continue;
        const email = userData.email || userData.customerEmail;
        if (!email) continue;

        // Don't send more than one re-engagement email per week
        if (userData.lastReEngagementEmail) {
          const lastSent = userData.lastReEngagementEmail.toDate ? userData.lastReEngagementEmail.toDate() : new Date(userData.lastReEngagementEmail);
          if ((Date.now() - lastSent.getTime()) < 7 * 24 * 60 * 60 * 1000) continue;
        }

        const firstName = userData.firstName || userData.name || 'there';

        const mailOptions = {
          from: `"Swan Match" <${smtpUserVal}>`,
          to: email,
          subject: `${firstName}, your matches are waiting! 💛`,
          html: `
            <!DOCTYPE html>
            <html>
            <body style="font-family: 'Helvetica Neue', sans-serif; background-color: #0d0d0d; color: #ffffff; margin: 0; padding: 0;">
              <div style="max-width: 600px; margin: 40px auto; background: #121212; border: 1px solid #c5a880; border-radius: 12px; overflow: hidden;">
                <div style="background: linear-gradient(135deg, #c5a880 0%, #8B6914 100%); padding: 30px; text-align: center;">
                  <h1 style="margin: 0; color: #0d0d0d; font-size: 24px;">We Miss You, ${firstName}! 👑</h1>
                </div>
                <div style="padding: 30px;">
                  <p style="color: #cccccc; font-size: 16px; line-height: 1.6;">
                    New members have joined Swan Match since your last visit, and we've found some amazing recommendations just for you.
                  </p>
                  <p style="color: #cccccc; font-size: 16px; line-height: 1.6;">
                    Don't miss out on your perfect match — open the app and see who's waiting!
                  </p>
                  <div style="text-align: center; margin: 30px 0;">
                    <a href="https://swan-match.com" style="background: linear-gradient(135deg, #c5a880, #8B6914); color: #0d0d0d; padding: 14px 40px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 16px;">
                      Open Swan Match
                    </a>
                  </div>
                  <p style="color: #666666; font-size: 12px; text-align: center;">
                    © ${new Date().getFullYear()} Swan Match, Inc. All Rights Reserved.<br>
                    If you no longer wish to receive these emails, update your notification preferences in the app.
                  </p>
                </div>
              </div>
            </body>
            </html>
          `,
        };

        try {
          await transporter.sendMail(mailOptions);
          sentCount++;

          // Mark last re-engagement email sent
          await db.collection('users').doc(doc.id).update({
            lastReEngagementEmail: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (mailErr) {
          console.warn(`[reEngagement] Failed to send email to ${email}: ${mailErr.message}`);
        }
      }

      console.log(`[reEngagement] Weekly run complete. Sent ${sentCount} re-engagement email(s).`);
    } catch (err) {
      console.error('[reEngagement] Fatal error:', err.message);
    }
  }
);


// ============================================================================
// ONE-TIME BACKFILL: Add priority to existing reports (admin-only)
// ============================================================================
// Call this once after deploy to fix existing reports without priority.
// Can be removed after running once.
// ============================================================================

exports.backfillReportPriority = onCall(async (request) => {
  if (!isAdminAuth(request)) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }

  const db = admin.firestore();
  const snapshot = await db.collection('reports').get();
  const P1_KEYWORDS = ['threat', 'kill', 'harm', 'suicide', 'underage', 'minor', 'child', 'blackmail', 'extort'];
  const P2_KEYWORDS = ['scam', 'fraud', 'fake', 'impersonat', 'catfish', 'money', 'escort', 'spam', 'harass', 'stalk'];

  let updated = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.priority) continue; // Already has priority

    const reason = (data.reason || '').toLowerCase();
    let priority = 'P3';
    if (P1_KEYWORDS.some(k => reason.includes(k))) priority = 'P1';
    else if (P2_KEYWORDS.some(k => reason.includes(k))) priority = 'P2';

    await doc.ref.update({ priority });
    updated++;
  }

  console.log(`[backfillReportPriority] Updated ${updated} of ${snapshot.size} reports.`);
  return { success: true, totalReports: snapshot.size, updated };
});

// ============================================================================
// STEP 17: PHOTO HASH DUPLICATE DETECTION
// ============================================================================

exports.checkPhotoDuplicate = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { photoUrl, photoHash } = request.data;
  if (!photoUrl || !photoHash) {
    throw new HttpsError('invalid-argument', 'photoUrl and photoHash are required.');
  }

  const uid = request.auth.uid;
  const db = admin.firestore();

  // Search for duplicate photo hash from other users
  const duplicatesSnap = await db.collection('user_photo_hashes')
    .where('photoHash', '==', photoHash)
    .get();

  let isDuplicate = false;
  let duplicatedWithUids = [];

  for (const doc of duplicatesSnap.docs) {
    const data = doc.data();
    if (data.userId !== uid) {
      isDuplicate = true;
      duplicatedWithUids.push(data.userId);
    }
  }

  // Save current photo hash
  await db.collection('user_photo_hashes').add({
    userId: uid,
    photoUrl,
    photoHash,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  if (isDuplicate) {
    // Flag current user as suspicious duplicate/catfish
    await db.collection('users').doc(uid).update({
      isFlaggedSuspicious: true,
      suspiciousReason: `Duplicate photo hash detected: matches user(s) ${duplicatedWithUids.join(', ')}`,
      flaggedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Also flag the matching other users to alert admin
    for (const otherUid of duplicatedWithUids) {
      await db.collection('users').doc(otherUid).update({
        isFlaggedSuspicious: true,
        suspiciousReason: `Duplicate photo hash detected: shared with new user ${uid}`,
        flaggedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // Log duplicate incident
    await db.collection('duplicate_photo_logs').add({
      userId: uid,
      sharedWithUids: duplicatedWithUids,
      photoHash,
      photoUrl,
      detectedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await logAdminAction('system', 'duplicate_photo_detected', uid, `Duplicate photo hash matches user(s): ${duplicatedWithUids.join(', ')}`);
  }

  return { isDuplicate, duplicatedWith: duplicatedWithUids };
});

// ============================================================================
// STEP 20: MATCH ENGAGEMENT NUDGES (INACTIVITY RECOVERY)
// ============================================================================

async function processMatchEngagementNudges() {
  const db = admin.firestore();
  const nowMs = Date.now();
  const oneDayAgo = nowMs - 24 * 60 * 60 * 1000;

  // Video-first redesign: "matched more than 24h ago with no messages sent
  // yet" is now expressed against connections/{status:'accepted'}, using
  // resolvedAt (when the pairing actually became active) instead of the old
  // matches doc's createdAt. Chat-idleness check is unchanged — it already
  // keys off chats/{chatId}/messages, and chatId === connectionId by the
  // shared id convention.
  const connectionsSnap = await db.collection('connections')
    .where('status', '==', 'accepted')
    .where('resolvedAt', '<=', admin.firestore.Timestamp.fromMillis(oneDayAgo))
    .get();

  let nudgedCount = 0;

  for (const doc of connectionsSnap.docs) {
    const connectionData = doc.data();
    const connectionId = doc.id;

    // Check if already nudged
    if (connectionData.nudgeSent) continue;

    // Query chat messages to verify if the thread is truly idle (0 messages)
    const messagesSnap = await db.collection('chats').doc(connectionId).collection('messages').limit(1).get();
    if (messagesSnap.empty) {
      // Chat is idle! Identify users
      const userIds = [connectionData.senderId, connectionData.receiverId].filter(Boolean);
      if (userIds.length === 2) {
        const [uid1, uid2] = userIds;

        // Retrieve FCM tokens for both users and send a push nudge
        for (const targetUid of [uid1, uid2]) {
          const userDoc = await db.collection('users').doc(targetUid).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            const fcmTokens = collectFcmTokens(userData);

            if (fcmTokens.length > 0) {
              const otherUid = targetUid === uid1 ? uid2 : uid1;
              const otherDoc = await db.collection('users').doc(otherUid).get();
              const otherName = otherDoc.exists ? (otherDoc.data()?.name || otherDoc.data()?.firstName || 'Someone') : 'Someone';

              const title = 'Yellow Alert! 💛';
              const body = `You matched with ${otherName}! Don't leave them waiting, send a message to say hello 👋`;

              const sendPromises = fcmTokens.map(token =>
                admin.messaging().send({
                  token,
                  notification: { title, body },
                  data: {
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    type: 'chat',
                    chatId: connectionId,
                    senderId: otherUid,
                    title,
                    body,
                  },
                  android: {
                    priority: 'high',
                    notification: { channelId: 'high_importance_channel', sound: 'default' },
                  },
                  apns: {
                    payload: { aps: { sound: 'default', badge: 1 } },
                  }
                }).catch(() => null)
              );
              await Promise.all(sendPromises);
            }
          }
        }

        // Mark connection as nudged
        await doc.ref.update({
          nudgeSent: true,
          nudgedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Log nudge event
        await db.collection('engagement_nudges').add({
          connectionId,
          userIds,
          nudgedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        nudgedCount++;
      }
    }
  }

  return { nudgedMatches: nudgedCount };
}

exports.nudgeMatchEngagement = onCall(async (request) => {
  // Admin-only: the real recurring case is already covered by
  // scheduledMatchEngagementNudge. This manual trigger was previously
  // callable by anyone (no auth check at all) — locking it down to admins
  // prevents unauthenticated notification-spam / cost amplification.
  if (!isAdminAuth(request)) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }
  await enforceRateLimit(request.auth.uid, 'nudgeMatchEngagement', 5, 60 * 1000);
  return await processMatchEngagementNudges();
});

exports.scheduledMatchEngagementNudge = onSchedule("0 18 * * *", async (event) => {
  console.log('[scheduledMatchEngagementNudge] Running automated match engagement re-engagement job...');
  const result = await processMatchEngagementNudges();
  console.log(`[scheduledMatchEngagementNudge] Completed successfully. Nudged matches: ${result.nudgedMatches}`);
});

// ============================================================================
// VIDEO-FIRST REDESIGN: CONNECT / TOPIC / VIDEO / ACCEPT
// Stage 3 (cutover) complete — this is now the only connection path; the old
// likes/matches/interests/journeys collections and their rules/functions
// have been removed.
// ============================================================================

/**
 * Daily Connects quota per tier. Not specified numerically anywhere in the
 * redesign plan's cross-repo contract (only that a daily counter must exist
 * and be enforced server-side) — chosen to mirror the free=1/trial=3 split
 * already used for the legacy dailyInterests/trialInterestsTotal counters in
 * lib/services/subscription_limits_service.dart. Premium = unlimited
 * (never checked below). Revisit if product wants different numbers.
 */
const DAILY_CONNECTS_LIMIT = { free: 1, trial: 3 };

/**
 * Server-side port of UserService.isOnFreeTrial()/isPaidPremium()
 * (lib/services/user_service.dart), close enough to bucket a user doc into
 * 'free' | 'trial' | 'premium'. Needed because the daily-Connects quota (and
 * the dailyAccepts/totalAccepts split on accept) must be enforced inside a
 * Cloud Function — Firestore rules can't do time-windowed aggregation or
 * read arbitrary Stripe-shaped fields for this kind of tiering.
 */
function computeUserTierServerSide(userData) {
  if (!userData) return 'free';

  const plan = (userData.subscriptionPlan || '').toString().toLowerCase();
  const status = (userData.subscriptionStatus || '').toString().toLowerCase();

  // In-app 7-day free trial (not a Stripe subscription).
  let isOnFreeTrial = false;
  if (plan === 'trial' && status === 'trialing') {
    const endsAt = userData.freeTrialEndsAt;
    if (endsAt && typeof endsAt.toDate === 'function') {
      isOnFreeTrial = endsAt.toDate().getTime() > Date.now();
    } else {
      isOnFreeTrial = true;
    }
  }
  if (isOnFreeTrial) return 'trial';

  // A store subscription whose paid period ended (beyond the grace window)
  // is no longer Premium, even if the refresh job hasn't run yet.
  if (iapEntitlements.storeSubscriptionLapsed(userData)) return 'free';

  // Paid Stripe premium (excludes in-app free trial).
  const statuses = [];
  if (status) statuses.push(status);
  const sub = userData.subscription;
  if (sub && typeof sub === 'object') {
    const nestedStatus = (sub.status || '').toString().toLowerCase();
    if (nestedStatus) statuses.push(nestedStatus);
  }
  const hasStripeSub = !!(userData.stripeSubscriptionId || '').toString();
  const hasPaidPlan = plan === 'premium' || plan === 'gold';
  const hasStripePrice = !!(sub && typeof sub === 'object' && (sub.priceId || '').toString());

  for (const s of statuses) {
    if (s !== 'active' && s !== 'trialing') continue;
    if (hasStripeSub || hasPaidPlan || hasStripePrice) return 'premium';
  }
  if (hasStripeSub && (status === 'active' || status === 'trialing')) return 'premium';

  return 'free';
}

/**
 * Lazily resets + enforces + stages an increment of dailyConnects on
 * users/{uid}/meta/subscriptionUsage, inside an already-open transaction.
 * Ports the *daily* reset shape of
 * SubscriptionLimitsService._getOrResetUsage()'s dailySwipes handling (reset
 * every 24h for every non-premium tier) rather than the *lifetime-total*
 * shape used for dailyInterests/trialInterestsTotal — the redesign plan is
 * explicit that Connects should "reset every 24h same way dailySwipes used
 * to work", not accumulate as a trial-lifetime total.
 *
 * Deliberate deviation from the client's exact behavior: the Dart
 * recordSwipe() bumps `lastResetAt` to now() on *every* recorded swipe (not
 * only when the 24h window actually rolls over), which — if ported literally
 * — would mean the daily window keeps sliding forward for an active user and
 * effectively never resets. That reads as a pre-existing quirk in the
 * client-only code, not an intentional design; since dailyConnects is a
 * brand-new field with no other reader/writer, this port only updates
 * `lastResetAt` when a reset actually fires, which is what "resets every
 * 24h" requires to actually happen.
 *
 * Caller must have already read `usageSnap` via `transaction.get()` (all
 * reads in a transaction must precede all writes) and must commit the
 * transaction itself.
 */
function checkAndStageDailyConnectsIncrement(transaction, usageRef, usageSnap, tier) {
  const data = usageSnap.exists ? (usageSnap.data() || {}) : {};
  const lastReset = data.lastResetAt && typeof data.lastResetAt.toDate === 'function'
    ? data.lastResetAt.toDate()
    : new Date(0);
  const hoursSince = (Date.now() - lastReset.getTime()) / (1000 * 60 * 60);
  const shouldReset = !usageSnap.exists || hoursSince >= 24;

  const currentDailyConnects = shouldReset ? 0 : ((typeof data.dailyConnects === 'number') ? data.dailyConnects : 0);

  if (tier !== 'premium') {
    const limit = DAILY_CONNECTS_LIMIT[tier] ?? DAILY_CONNECTS_LIMIT.free;
    if (currentDailyConnects >= limit) {
      throw new HttpsError(
        'resource-exhausted',
        `You've used all ${limit} Connects for today. Upgrade to Premium for unlimited Connects.`
      );
    }
  }

  const update = { dailyConnects: currentDailyConnects + 1 };
  if (shouldReset) {
    update.lastResetAt = admin.firestore.FieldValue.serverTimestamp();
    // lastResetAt is shared with the app's daily swipe counter: starting a
    // new window here must also clear the swipes, or they'd stay used up
    // for another 24h (the app only resets when the window has expired).
    update.dailySwipes = 0;
  }
  transaction.set(usageRef, update, { merge: true });
}

/**
 * Extracts the Storage object path from a Firebase download URL, a gs://
 * URL, or an already-bare object path, and verifies it starts with
 * `expectedPrefix`. Returns null (never throws) if the URL can't be
 * resolved to a path under that prefix — this is what stops a client from
 * passing an arbitrary/forged `videoUrl` into submitConnectionRequest;
 * the caller still separately confirms the object actually exists in the
 * bucket via bucket.file(path).exists().
 */
function extractStoragePathUnderPrefix(videoUrl, expectedPrefix) {
  if (!videoUrl || typeof videoUrl !== 'string') return null;
  try {
    let path = null;
    if (videoUrl.startsWith('gs://')) {
      const withoutScheme = videoUrl.slice('gs://'.length);
      const slashIdx = withoutScheme.indexOf('/');
      path = slashIdx === -1 ? '' : withoutScheme.slice(slashIdx + 1);
    } else if (videoUrl.startsWith('http://') || videoUrl.startsWith('https://')) {
      const parsed = new URL(videoUrl);
      // Firebase Storage download URLs encode the object path after '/o/'.
      const match = parsed.pathname.match(/\/o\/(.+)$/);
      if (match) path = decodeURIComponent(match[1]);
    } else {
      // Assume it's already a bare object path.
      path = videoUrl;
    }
    if (!path || !path.startsWith(expectedPrefix)) return null;
    return path;
  } catch (_err) {
    return null;
  }
}

/**
 * submitConnectionRequest({ receiverId, topic, videoUrl }) — onCall.
 * Client uploads the response video to Storage first, then calls this. Not
 * a direct client Firestore write: the daily-Connects quota can't be
 * enforced by Firestore rules (no time-windowed aggregation in rules), so
 * quota enforcement must happen here.
 */
exports.submitConnectionRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }
  const uid = request.auth.uid;

  await enforceRateLimit(uid, 'submitConnectionRequest', 10, 3600 * 1000);

  const { receiverId, topic, videoUrl, videoThumbnailUrl } = request.data || {};

  if (!receiverId || typeof receiverId !== 'string') {
    throw new HttpsError('invalid-argument', 'receiverId is required.');
  }
  if (receiverId === uid) {
    throw new HttpsError('invalid-argument', 'Cannot connect with yourself.');
  }
  if (!topic || typeof topic !== 'string' || topic.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'topic is required.');
  }
  if (!videoUrl || typeof videoUrl !== 'string') {
    throw new HttpsError('invalid-argument', 'videoUrl is required.');
  }
  if (videoThumbnailUrl !== undefined && videoThumbnailUrl !== null && videoThumbnailUrl !== '' &&
      typeof videoThumbnailUrl !== 'string') {
    throw new HttpsError('invalid-argument', 'videoThumbnailUrl must be a string.');
  }

  const db = admin.firestore();
  const connectionId = [uid, receiverId].sort().join('_');
  const trimmedTopic = topic.trim();

  // videoUrl must point at this project's temp-connection-videos storage
  // path for *this* connection — never trust a client-supplied arbitrary URL.
  const expectedPrefix = `temp-connection-videos/${connectionId}/`;
  const storagePath = extractStoragePathUnderPrefix(videoUrl, expectedPrefix);
  if (!storagePath) {
    throw new HttpsError('invalid-argument', 'videoUrl is not a valid connection video path.');
  }

  const bucket = admin.storage().bucket();
  const [videoExists] = await bucket.file(storagePath).exists();
  if (!videoExists) {
    throw new HttpsError('failed-precondition', 'Video upload not found. Please try again.');
  }

  // Thumbnail is best-effort: client-side generation can fail, so an
  // absent/empty videoThumbnailUrl is fine and never blocks the request.
  // When present, it must resolve to a real object under this connection's
  // own temp-connection-videos prefix, same trust model as videoUrl.
  let resolvedThumbnailUrl = '';
  if (typeof videoThumbnailUrl === 'string' && videoThumbnailUrl.trim().length > 0) {
    const thumbnailStoragePath = extractStoragePathUnderPrefix(videoThumbnailUrl, expectedPrefix);
    if (!thumbnailStoragePath) {
      throw new HttpsError('invalid-argument', 'videoThumbnailUrl is not a valid connection video path.');
    }
    const [thumbnailExists] = await bucket.file(thumbnailStoragePath).exists();
    if (!thumbnailExists) {
      throw new HttpsError('failed-precondition', 'Thumbnail upload not found. Please try again.');
    }
    resolvedThumbnailUrl = videoThumbnailUrl;
  }

  const receiverRef = db.collection('users').doc(receiverId);
  const senderRef = db.collection('users').doc(uid);
  const connectionRef = db.collection('connections').doc(connectionId);
  const usageRef = senderRef.collection('meta').doc('subscriptionUsage');
  const notificationRef = db.collection('notifications').doc();

  await db.runTransaction(async (transaction) => {
    const [receiverSnap, senderSnap, connectionSnap, usageSnap] = await Promise.all([
      transaction.get(receiverRef),
      transaction.get(senderRef),
      transaction.get(connectionRef),
      transaction.get(usageRef),
    ]);

    if (!receiverSnap.exists) {
      throw new HttpsError('not-found', 'Receiver not found.');
    }
    const receiverData = receiverSnap.data() || {};
    if (receiverData.introVideoStatus !== 'approved') {
      throw new HttpsError('failed-precondition', 'This user is not available to connect with right now.');
    }
    // A block in either direction stops new requests (same neutral message,
    // so the sender can't tell they were blocked).
    const senderBlocked = senderSnap.exists ? (senderSnap.data() || {}).blockedUids : null;
    if ((Array.isArray(receiverData.blockedUids) && receiverData.blockedUids.includes(uid)) ||
        (Array.isArray(senderBlocked) && senderBlocked.includes(receiverId))) {
      throw new HttpsError('failed-precondition', 'This user is not available to connect with right now.');
    }

    if (connectionSnap.exists) {
      const existingStatus = connectionSnap.data()?.status;
      if (existingStatus === 'pending' || existingStatus === 'accepted') {
        throw new HttpsError('already-exists', 'A connection request already exists between you and this user.');
      }
    }

    const senderData = senderSnap.exists ? senderSnap.data() : null;
    const tier = computeUserTierServerSide(senderData);
    checkAndStageDailyConnectsIncrement(transaction, usageRef, usageSnap, tier);

    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + 72 * 60 * 60 * 1000);

    // Full overwrite (not merge): if a prior declined/expired doc exists for
    // this pair, this starts a clean new request lifecycle.
    transaction.set(connectionRef, {
      senderId: uid,
      receiverId,
      topic: trimmedTopic,
      videoUrl,
      videoThumbnailUrl: resolvedThumbnailUrl,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
      resolvedAt: null,
      reportedAt: null,
    });

    transaction.set(notificationRef, {
      toUserId: receiverId,
      fromUserId: uid,
      title: 'New Connection Request',
      message: `Someone sent you a Connect request on "${trimmedTopic}".`,
      type: 'connection_request',
      connectionId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true, connectionId };
});

/**
 * respondToConnection({ connectionId, action: 'accept'|'decline' }) — onCall.
 * Not a direct client write: accept must atomically create the chats doc AND
 * delete the temp Storage video, and this project cannot use Storage
 * triggers (see functions/index.js's original Eventarc/IAM note near the
 * bottom of this file) to fan that out safely from a plain rules-gated
 * client write. A defense-in-depth Firestore rule also exists on
 * connections/{connectionId} as a backstop against a forged direct write,
 * but this callable is the only supported path.
 */
exports.respondToConnection = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }
  const uid = request.auth.uid;
  const { connectionId, action } = request.data || {};

  if (!connectionId || typeof connectionId !== 'string') {
    throw new HttpsError('invalid-argument', 'connectionId is required.');
  }
  if (action !== 'accept' && action !== 'decline') {
    throw new HttpsError('invalid-argument', "action must be 'accept' or 'decline'.");
  }

  const db = admin.firestore();
  const connectionRef = db.collection('connections').doc(connectionId);
  const chatRef = db.collection('chats').doc(connectionId);

  let senderId = null;
  let receiverId = null;

  await db.runTransaction(async (transaction) => {
    const connectionSnap = await transaction.get(connectionRef);
    if (!connectionSnap.exists) {
      throw new HttpsError('not-found', 'Connection not found.');
    }
    const data = connectionSnap.data();
    senderId = data.senderId;
    receiverId = data.receiverId;

    if (uid !== receiverId) {
      throw new HttpsError('permission-denied', 'Only the receiver can respond to this connection request.');
    }
    if (data.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'This connection request is no longer pending.');
    }

    if (action === 'accept') {
      const receiverUserRef = db.collection('users').doc(receiverId);
      const [chatSnap, receiverUserSnap] = await Promise.all([
        transaction.get(chatRef),
        transaction.get(receiverUserRef),
      ]);

      transaction.update(connectionRef, {
        status: 'accepted',
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create the chat doc only if one doesn't already exist (mirrors
      // ChatService.ensureChatThread()'s field shape, lib/services/chat_service.dart).
      if (!chatSnap.exists) {
        transaction.set(chatRef, {
          id: connectionId,
          participants: [senderId, receiverId],
          lastMessage: '',
          lastMessageSenderId: senderId,
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      // Mirrors SubscriptionLimitsService.recordAccept(): trial accumulates a
      // lifetime total, free/other tiers use a daily counter, premium is
      // exempt entirely.
      const receiverTier = computeUserTierServerSide(receiverUserSnap.exists ? receiverUserSnap.data() : null);
      if (receiverTier !== 'premium') {
        const usageRef = receiverUserRef.collection('meta').doc('subscriptionUsage');
        const field = receiverTier === 'trial' ? 'totalAccepts' : 'dailyAccepts';
        transaction.set(usageRef, { [field]: admin.firestore.FieldValue.increment(1) }, { merge: true });
      }
    } else {
      transaction.update(connectionRef, {
        status: 'declined',
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  // Storage cleanup happens after the transaction commits (best-effort,
  // logged-not-thrown — mirrors hardDeleteExpiredAccounts' resilience style)
  // for both accept and decline: the temp video is never needed again once
  // the request is resolved either way.
  try {
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix: `temp-connection-videos/${connectionId}/` });
    if (files.length > 0) {
      await Promise.all(files.map((f) => f.delete().catch((e) =>
        console.warn(`[respondToConnection] Could not delete file ${f.name}: ${e.message}`)
      )));
    }
  } catch (err) {
    console.error(`[respondToConnection] Storage cleanup error for ${connectionId}: ${err.message}`);
  }

  // Notify the sender on accept only — decline is silent by design.
  if (action === 'accept') {
    try {
      await db.collection('notifications').add({
        toUserId: senderId,
        fromUserId: receiverId,
        title: 'Connection Accepted',
        message: 'Your Connect request was accepted! Start chatting now.',
        type: 'connection_accepted',
        connectionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error(`[respondToConnection] Notification error for ${connectionId}: ${err.message}`);
    }
  }

  return { success: true, action };
});

/**
 * disconnectConnection({ connectionId }) — onCall.
 * Unmatch for an already-ACCEPTED connection. Unlike respondToConnection's
 * accept/decline (receiver-only, pending-only), this is caller-agnostic:
 * either participant (sender or receiver) may end an active connection.
 * Sets status back to 'declined' rather than inventing a new terminal
 * status — 'declined' already means "not an active connection" everywhere
 * else (e.g. the Discover exclusion filter only excludes pending/accepted),
 * so this is exactly the desired "both parties reappear in Discover" effect.
 * Does NOT touch chats/{connectionId} or its messages: this is an unmatch,
 * not a data-deletion request, and the two people may still want their chat
 * history. A fresh submitConnectionRequest is required to reconnect, which
 * is expected — chats/create's rule requires status == 'accepted'.
 */
exports.disconnectConnection = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }
  const uid = request.auth.uid;
  const { connectionId } = request.data || {};
  // silent = the caller is BLOCKING the other person: end a pending or
  // accepted connection and do NOT notify them (a "Connection Ended"
  // notification from the blocker would alert the blocked user and link
  // back to the blocker's profile).
  const silent = request.data?.silent === true;

  if (!connectionId || typeof connectionId !== 'string') {
    throw new HttpsError('invalid-argument', 'connectionId is required.');
  }

  const db = admin.firestore();
  const connectionRef = db.collection('connections').doc(connectionId);

  let senderId = null;
  let receiverId = null;
  let otherUserId = null;

  await db.runTransaction(async (transaction) => {
    const connectionSnap = await transaction.get(connectionRef);
    if (!connectionSnap.exists) {
      throw new HttpsError('not-found', 'Connection not found.');
    }
    const data = connectionSnap.data();
    senderId = data.senderId;
    receiverId = data.receiverId;

    if (uid !== senderId && uid !== receiverId) {
      throw new HttpsError('permission-denied', 'You are not a participant in this connection.');
    }
    const endable = silent ? ['accepted', 'pending'] : ['accepted'];
    if (!endable.includes(data.status)) {
      throw new HttpsError('failed-precondition', 'Only an active (accepted) connection can be disconnected.');
    }

    otherUserId = uid === senderId ? receiverId : senderId;

    transaction.update(connectionRef, {
      status: 'declined',
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  console.log(`[disconnectConnection] uid=${uid} disconnected connectionId=${connectionId}${silent ? ' (block, silent)' : ''}`);

  if (silent) return { success: true };

  // Notify the other participant — unlike respondToConnection's silent
  // decline (which fires before the two people ever chatted), this ends an
  // established connection the other side has been actively using, so they
  // should be told why it disappeared rather than finding out silently.
  try {
    await db.collection('notifications').add({
      toUserId: otherUserId,
      fromUserId: uid,
      title: 'Connection Ended',
      message: 'A connection has ended.',
      type: 'connection_ended',
      connectionId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error(`[disconnectConnection] Notification error for ${connectionId}: ${err.message}`);
  }

  return { success: true };
});

/**
 * reportConnectionVideo({ connectionId, reason, category }) — onCall.
 * Distinct from submitReport because the calling context (reporting before
 * ever chatting) differs from the existing chat-report flow, but shares its
 * priority-assignment helper (assignReportPriority) and category labels
 * (REPORT_CATEGORY_LABELS) so moderation triage stays consistent.
 */
exports.reportConnectionVideo = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }
  const reporterUid = request.auth.uid;

  await enforceRateLimit(reporterUid, 'reportConnectionVideo', 5, 3600 * 1000);

  const { connectionId, reason, category } = request.data || {};
  if (!connectionId || typeof connectionId !== 'string') {
    throw new HttpsError('invalid-argument', 'connectionId is required.');
  }
  if (!reason || typeof reason !== 'string' || reason.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Reason is required.');
  }
  if (reason.length > 500) {
    throw new HttpsError('invalid-argument', 'Reason too long (max 500 characters).');
  }

  const db = admin.firestore();
  const connectionRef = db.collection('connections').doc(connectionId);
  const connectionSnap = await connectionRef.get();
  if (!connectionSnap.exists) {
    throw new HttpsError('not-found', 'Connection not found.');
  }
  const data = connectionSnap.data();
  if (reporterUid !== data.senderId && reporterUid !== data.receiverId) {
    throw new HttpsError('permission-denied', 'You are not a participant in this connection.');
  }
  // Never trust a client-supplied target — derive it from the connection doc.
  const reportedUid = reporterUid === data.senderId ? data.receiverId : data.senderId;

  const priority = assignReportPriority(reason, category);
  const cat = (category || '').toLowerCase().trim();

  await db.collection('reports').add({
    reportedUid,
    reportedBy: reporterUid,
    reason: reason.trim(),
    category: cat || null,
    categoryLabel: REPORT_CATEGORY_LABELS[cat] || null,
    priority,
    reportedAt: admin.firestore.FieldValue.serverTimestamp(),
    isReported: true,
    status: 'Open',
    contentType: 'video',
    connectionId,
    videoUrl: data.videoUrl || null,
  });

  // Blocks the cleanup job from deleting the video until an admin resolves
  // the report (see expireConnectionRequests below).
  await connectionRef.update({
    reportedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * expireConnectionRequests — runs every 30 minutes.
 * Template: hardDeleteExpiredAccounts (per-doc try/catch resilience, above).
 * Sweeps connections stuck in 'pending' past their 72h expiresAt window,
 * freeing the temp Storage video and flipping status to 'expired' — never
 * hard-deleted, which keeps an audit trail and lets
 * submitConnectionRequest's duplicate-check correctly allow a fresh request
 * after expiry.
 */
exports.expireConnectionRequests = onSchedule(
  { schedule: 'every 30 minutes' },
  async (_event) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    console.log('[expireConnectionRequests] Starting run at', new Date().toISOString());

    // Firestore can't cleanly combine this range filter (expiresAt<=now)
    // with an equality-null filter (reportedAt==null) in one query here, so
    // reportedAt is filtered in-memory after the range query instead.
    const snapshot = await db
      .collection('connections')
      .where('status', '==', 'pending')
      .where('expiresAt', '<=', now)
      .limit(200)
      .get();

    if (snapshot.empty) {
      console.log('[expireConnectionRequests] No expired pending connections found.');
      return;
    }

    const candidates = snapshot.docs.filter((doc) => !doc.data().reportedAt);
    console.log(`[expireConnectionRequests] Found ${snapshot.size} expired, ${candidates.length} eligible (not reported).`);

    for (const doc of candidates) {
      const connectionId = doc.id;
      try {
        // Re-check status is still 'pending' to avoid a race with a
        // concurrent respondToConnection call that may have just
        // accepted/declined it since the query ran.
        const freshSnap = await doc.ref.get();
        if (!freshSnap.exists || freshSnap.data().status !== 'pending') {
          console.log(`[expireConnectionRequests] Skipping ${connectionId}: no longer pending.`);
          continue;
        }

        const bucket = admin.storage().bucket();
        const [files] = await bucket.getFiles({ prefix: `temp-connection-videos/${connectionId}/` });
        if (files.length > 0) {
          await Promise.all(files.map((f) => f.delete().catch((e) =>
            console.warn(`[expireConnectionRequests] Could not delete file ${f.name}: ${e.message}`)
          )));
          console.log(`[expireConnectionRequests] Deleted ${files.length} storage file(s) for ${connectionId}`);
        }

        await doc.ref.update({
          status: 'expired',
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`[expireConnectionRequests] Expired connection ${connectionId}`);
      } catch (err) {
        console.error(`[expireConnectionRequests] Failed for ${connectionId}: ${err.message}`);
        // Continue processing remaining connections
      }
    }

    console.log('[expireConnectionRequests] Run complete.');
  }
);

/**
 * cleanupRejectedIntroVideos — runs daily at 04:00 UTC.
 * Reclaims Storage for intro videos rejected 7+ days ago (gives the user a
 * window to see the rejection and re-upload before the file is reclaimed).
 * introVideoStatus itself is left untouched here ('rejected' stays
 * 'rejected') — only the Storage object is deleted. This replaces the
 * originally-considered adminRejectIntroVideo callable, keeping admin-web's
 * "always a direct Firestore write, never a callable, no Storage SDK"
 * convention fully intact.
 */
exports.cleanupRejectedIntroVideos = onSchedule(
  { schedule: '0 4 * * *', timeZone: 'UTC' },
  async (_event) => {
    const db = admin.firestore();
    const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 7 * 24 * 60 * 60 * 1000);

    console.log('[cleanupRejectedIntroVideos] Starting run at', new Date().toISOString());

    const snapshot = await db
      .collection('users')
      .where('introVideoStatus', '==', 'rejected')
      .where('introVideoStatusUpdatedAt', '<=', sevenDaysAgo)
      .limit(200)
      .get();

    if (snapshot.empty) {
      console.log('[cleanupRejectedIntroVideos] No rejected intro videos old enough to clean up.');
      return;
    }

    console.log(`[cleanupRejectedIntroVideos] Found ${snapshot.size} user(s) to clean up.`);

    for (const doc of snapshot.docs) {
      const uid = doc.id;
      try {
        const bucket = admin.storage().bucket();
        const [files] = await bucket.getFiles({ prefix: `intro-videos/${uid}/` });
        if (files.length > 0) {
          await Promise.all(files.map((f) => f.delete().catch((e) =>
            console.warn(`[cleanupRejectedIntroVideos] Could not delete file ${f.name}: ${e.message}`)
          )));
          console.log(`[cleanupRejectedIntroVideos] Deleted ${files.length} storage file(s) for uid=${uid}`);
        }
      } catch (err) {
        console.error(`[cleanupRejectedIntroVideos] Failed for uid=${uid}: ${err.message}`);
        // Continue processing remaining users
      }
    }

    console.log('[cleanupRejectedIntroVideos] Run complete.');
  }
);

/**
 * onIntroVideoStatusChanged — reactive trigger on users/{uid} update.
 * Follows the same before/after-diff v2 trigger style as onUserSoftDeleted
 * above. Fires a notification whenever introVideoStatus changes value
 * (covers admin-web's direct updateDoc writes without requiring admin-web to
 * also create a notification), and is the sole writer of
 * introVideoStatusUpdatedAt so that field reliably reflects "when did status
 * last change" for cleanupRejectedIntroVideos, regardless of who changed the
 * status. (Re-triggering on its own introVideoStatusUpdatedAt-only write is
 * a no-op: the early-return check below only compares introVideoStatus.)
 */
exports.onIntroVideoStatusChanged = onDocumentUpdated('users/{uid}', async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const uid = event.params.uid;

  if (before.introVideoStatus === after.introVideoStatus) {
    return;
  }

  try {
    await event.data.after.ref.update({
      introVideoStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error(`[onIntroVideoStatusChanged] Failed to stamp introVideoStatusUpdatedAt for ${uid}: ${err.message}`);
  }

  // No user notification here: the admin panel's Video Moderation Queue —
  // the only place that approves/rejects intro videos — already sends one
  // ("Video Approved!" / "Video Rejected" / "Please Re-record Your Video").
  // Sending another from this trigger gave users two notifications (and two
  // pushes) for every decision.
});

// ─── Swan AI (Groq dev / OpenAI prod) ───────────────────────────────────────
const swanAi = require('./swan_ai');
exports.generateCompatibilityNarrative = swanAi.generateCompatibilityNarrative;

// ============================================================================
// STEP 16: SERVERLESS IMAGE THUMBNAIL GENERATION (REMOVED TO BYPASS IAM BLOCKS)
// ============================================================================
// This feature has been disabled/removed because the mobile application does not reference thumbnailUrl,
// and Cloud Storage Eventarc triggers require administrative IAM permissions (roles/pubsub.publisher)
// on the Google Storage service agent, which blocks standard functions deployments.

