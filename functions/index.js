const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();

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
    const fcmTokens = userData.fcmTokens || [];
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

exports.onMessageCreated = onDocumentCreated('messages/{chatId}/messages/{messageId}', async (event) => {
  const messageDetails = event.data?.data();
  if (!messageDetails) {
    console.log('[onMessageCreated] No message data');
    return;
  }

  const receiverId = messageDetails.receiverId || messageDetails.toUserId;
  const senderId = messageDetails.senderId;
  const senderName = messageDetails.senderName || 'New message';
  const messageText = messageDetails.text || messageDetails.message || '';
  const chatId = event.params.chatId;

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
    const fcmTokens = userData.fcmTokens || [];
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

exports.checkPhoneExists = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

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
exports.createCheckoutSession = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  // AUTH GUARD
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { priceId, successUrl, cancelUrl } = request.data;
  if (!priceId) {
    throw new HttpsError('invalid-argument', 'The function must be called with "priceId".');
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
  console.log(`[createCheckoutSession] Stripe key prefix: ${rawSecret.trim().substring(0, 7)}...`);

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
 * Stripe - Webhook Handler
 */
exports.handleStripeWebhook = onRequest(
  {
    secrets: [stripeSecretKey, stripeWebhookSecret],
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
    console.log('webhookSecret starts with whsec_:', stripeWebhookSecret.value()?.startsWith('whsec_'));

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

          const updateData = {
            subscriptionStatus: subscription.status,
            stripeSubscriptionId: subscription.id,
            subscriptionPlan: subscription.status === 'active' ? 'premium' : 'free',
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

            await db.collection('users').doc(uid).update({
              paymentStatus: 'paid',
              subscriptionStatus: 'active',
              subscriptionPlan: 'premium',
              lastInvoiceId: invoice.id,
              lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
              freeTrialEndsAt: admin.firestore.FieldValue.delete(),
              freeTrialStartedAt: admin.firestore.FieldValue.delete(),
              trialEndedAt: admin.firestore.FieldValue.serverTimestamp(),
              trialEndedReason: 'upgraded_to_premium',
            });
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
exports.verifySubscription = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

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
exports.getStripePrices = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { priceIds } = request.data;
  if (!Array.isArray(priceIds) || priceIds.length === 0) {
    throw new HttpsError('invalid-argument', '"priceIds" must be a non-empty array.');
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
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
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
        notification: {
          channel_id: 'high_importance_channel',
        },
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

