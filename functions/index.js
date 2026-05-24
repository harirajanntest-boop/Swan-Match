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
/** Pricing secrets — set via: firebase functions:secrets:set STRIPE_PRICE_MONTHLY, etc. */
const stripePriceMonthly = defineSecret('STRIPE_PRICE_MONTHLY');
const stripePriceSixMonth = defineSecret('STRIPE_PRICE_SIXMONTH');
const stripePriceYearly = defineSecret('STRIPE_PRICE_YEARLY');
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
  const CATEGORY_PRIORITY = {
    harassment: 'P1',
    underage: 'P1',
    fake_profile: 'P2',
    scam: 'P2',
    inappropriate: 'P2',
    spam: 'P3',
    other: null, // null = fall through to keyword scan
  };

  let priority = 'P3'; // Default
  const cat = (category || '').toLowerCase().trim();

  if (cat && CATEGORY_PRIORITY[cat] !== undefined) {
    if (CATEGORY_PRIORITY[cat] !== null) {
      priority = CATEGORY_PRIORITY[cat];
    } else {
      // 'other' category: fall back to keyword scan
      const reasonLower = reason.toLowerCase();
      const P1_KEYWORDS = ['threat', 'kill', 'harm', 'suicide', 'underage', 'minor', 'child', 'blackmail', 'extort'];
      const P2_KEYWORDS = ['scam', 'fraud', 'fake', 'impersonat', 'catfish', 'money', 'escort', 'spam', 'harass', 'stalk'];
      if (P1_KEYWORDS.some(k => reasonLower.includes(k))) priority = 'P1';
      else if (P2_KEYWORDS.some(k => reasonLower.includes(k))) priority = 'P2';
    }
  } else {
    // No category sent (old app version): full keyword scan
    const reasonLower = reason.toLowerCase();
    const P1_KEYWORDS = ['threat', 'kill', 'harm', 'suicide', 'underage', 'minor', 'child', 'blackmail', 'extort'];
    const P2_KEYWORDS = ['scam', 'fraud', 'fake', 'impersonat', 'catfish', 'money', 'escort', 'spam', 'harass', 'stalk'];
    if (P1_KEYWORDS.some(k => reasonLower.includes(k))) priority = 'P1';
    else if (P2_KEYWORDS.some(k => reasonLower.includes(k))) priority = 'P2';
  }

  // Human-readable category labels for admin dashboard
  const CATEGORY_LABELS = {
    harassment: 'Harassment / Threats',
    fake_profile: 'Fake Profile / Catfish',
    scam: 'Scam / Fraud',
    inappropriate: 'Inappropriate Content',
    underage: 'Underage User',
    spam: 'Spam / Solicitation',
    other: 'Other',
  };

  // Create report
  await db.collection('reports').add({
    reportedUid,
    reportedBy: reporterUid,
    reason: reason.trim(),
    category: cat || null,
    categoryLabel: CATEGORY_LABELS[cat] || null,
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
    const p1Reports = snapshot.docs.filter(doc => {
      const data = doc.data();
      return data.priority === 'P1' || data.priority === 1;
    });
    const p1Count = p1Reports.length;

    // Auto-suspend at 3+ P1 reports OR 5+ total reports
    if (p1Count >= 3 || reportCount >= 5) {
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
  { schedule: '0 11 * * 1', timeZone: 'UTC' }, // Runs every Monday at 11 AM UTC
  async (_event) => {
    const smtpUserVal = process.env.SMTP_USER || '';
    const smtpPassVal = process.env.SMTP_PASS || '';

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
  
  // Find matches older than 24 hours where we haven't sent a nudge
  const matchesSnap = await db.collection('matches')
    .where('createdAt', '<=', admin.firestore.Timestamp.fromMillis(oneDayAgo))
    .get();

  let nudgedCount = 0;
  
  for (const doc of matchesSnap.docs) {
    const matchData = doc.data();
    const matchId = doc.id;
    
    // Check if already nudged
    if (matchData.nudgeSent) continue;
    
    // Query chat messages to verify if the thread is truly idle (0 messages)
    const messagesSnap = await db.collection('chats').doc(matchId).collection('messages').limit(1).get();
    if (messagesSnap.empty) {
      // Chat is idle! Identify users
      const userIds = matchData.userIds || matchId.split('_');
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
                    chatId: matchId,
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
        
        // Mark match as nudged
        await doc.ref.update({
          nudgeSent: true,
          nudgedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Log nudge event
        await db.collection('engagement_nudges').add({
          matchId,
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
  // Allow admins or users to invoke nudge checks
  return await processMatchEngagementNudges();
});

exports.scheduledMatchEngagementNudge = onSchedule("0 18 * * *", async (event) => {
  console.log('[scheduledMatchEngagementNudge] Running automated match engagement re-engagement job...');
  const result = await processMatchEngagementNudges();
  console.log(`[scheduledMatchEngagementNudge] Completed successfully. Nudged matches: ${result.nudgedMatches}`);
});

// ============================================================================
// STEP 16: SERVERLESS IMAGE THUMBNAIL GENERATION (REMOVED TO BYPASS IAM BLOCKS)
// ============================================================================
// This feature has been disabled/removed because the mobile application does not reference thumbnailUrl,
// and Cloud Storage Eventarc triggers require administrative IAM permissions (roles/pubsub.publisher)
// on the Google Storage service agent, which blocks standard functions deployments.

