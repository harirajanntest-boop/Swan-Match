const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

exports.onNotificationCreated = onDocumentCreated('notifications/{docId}', async (event) => {
  const notificationDetails = event.data?.data();
  if (!notificationDetails) return;

  const toUserId = notificationDetails.toUserId;
  const title = notificationDetails.title;
  const message = notificationDetails.message;

  if (!toUserId) return;

  try {
    // 1. Fetch user data to get FCM tokens
    const userSnapshot = await admin.firestore().collection('users').doc(toUserId).get();
    
    if (!userSnapshot.exists) {
      console.log(`User ${toUserId} does not exist`);
      return;
    }

    const userData = userSnapshot.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log(`User ${toUserId} has no FCM tokens`);
      return;
    }

    // 2. Construct the push payload
    const payload = {
      notification: {
        title: title || 'New Notification',
        body: message || '',
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        title: title || 'New Notification',
        body: message || '',
        ...notificationDetails.meta, // include any additional metadata for frontend routing
      },
      tokens: fcmTokens,
    };

    // 3. Send the message via FCM
    const response = await admin.messaging().sendEachForMulticast(payload);
    
    console.log(`Successfully sent message to ${response.successCount} tokens`);
    
    // 4. Optionally cleanup invalid tokens
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(fcmTokens[idx]);
        }
      });
      
      if (failedTokens.length > 0) {
        console.log('Removing invalid tokens...');
        await admin.firestore().collection('users').doc(toUserId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens)
        });
      }
    }
  } catch (error) {
    console.error('Error sending push notification:', error);
  }
});

exports.onMessageCreated = onDocumentCreated('messages/{chatId}/messages/{messageId}', async (event) => {
  const messageDetails = event.data?.data();
  if (!messageDetails) return;

  const receiverId = messageDetails.receiverId || messageDetails.toUserId;
  const senderId = messageDetails.senderId;
  const senderName = messageDetails.senderName || 'New message';
  const messageText = messageDetails.text || messageDetails.message || '';
  const chatId = event.params.chatId;

  if (!receiverId) return;

  try {
    const userSnapshot = await admin.firestore().collection('users').doc(receiverId).get();

    if (!userSnapshot.exists) {
      console.log(`User ${receiverId} does not exist`);
      return;
    }

    const userData = userSnapshot.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log(`User ${receiverId} has no FCM tokens`);
      return;
    }

    const payload = {
      notification: {
        title: senderName,
        body: messageText,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        title: senderName,
        body: messageText,
        type: 'chat',
        chatId: chatId || '',
        senderId: senderId || '',
      },
      tokens: fcmTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(payload);

    console.log(`Successfully sent message to ${response.successCount} tokens`);

    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(fcmTokens[idx]);
        }
      });

      if (failedTokens.length > 0) {
        console.log('Removing invalid tokens...');
        await admin.firestore().collection('users').doc(receiverId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens)
        });
      }
    }
  } catch (error) {
    console.error('Error sending message notification:', error);
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
  // 6. AUTH GUARD
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { priceId, successUrl, cancelUrl } = request.data;
  if (!priceId) {
    throw new HttpsError('invalid-argument', 'The function must be called with "priceId".');
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email;
  // 1. Instantiate Stripe INSIDE handler
  const stripe = require('stripe')(stripeSecretKey.value());

  try {
    // 1. Get or create Stripe customer
    const userRef = admin.firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();
    let stripeCustomerId = userDoc.data()?.stripeCustomerId;

    if (!stripeCustomerId) {
      const customer = await stripe.customers.create({
        email: email,
        metadata: { firebaseUid: uid },
      });
      stripeCustomerId = customer.id;
      await userRef.update({ stripeCustomerId: stripeCustomerId });
    }

    // 2. Create session
    const session = await stripe.checkout.sessions.create({
      customer: stripeCustomerId,
      payment_method_types: ['card'],
      line_items: [{ price: priceId, quantity: 1 }],
      mode: 'subscription',
      success_url: successUrl,
      cancel_url: cancelUrl,
      // 5. CHECKOUT SESSION - Added client_reference_id and metadata
      client_reference_id: uid,
      metadata: { userId: uid },
    });

    return { sessionId: session.id, url: session.url };
  } catch (error) {
    console.error('Stripe Session Error:', error);
    throw new HttpsError('internal', error.message);
  }
});

/**
 * Stripe - Webhook Handler
 */
exports.handleStripeWebhook = onRequest({ secrets: [stripeSecretKey, stripeWebhookSecret] }, async (req, res) => {
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

  const stripe = require('stripe')(stripeSecretKey.value());
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
        const customer = await stripe.customers.retrieve(subscription.customer);
        const uid = customer.metadata?.userId || customer.metadata?.firebaseUid;
        
        if (uid) {
          await db.collection('users').doc(uid).update({
            subscriptionStatus: subscription.status,
            stripeSubscriptionId: subscription.id,
            billingPeriodStart: admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000),
            billingPeriodEnd: admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000),
            subscriptionPlan: subscription.status === 'active' ? 'premium' : 'free',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
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
            lastInvoiceId: invoice.id,
            lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
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
 * verifySubscription - Source of truth for premium status
 */
exports.verifySubscription = onCall(async (request) => {
  // Check if context.auth is null
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = request.auth.uid;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) {
      return { isPremium: false, expiresAt: null };
    }

    const userData = userDoc.data();
    const status = userData.subscriptionStatus;
    const expiry = userData.billingPeriodEnd; // This is a Firestore Timestamp
    
    // Check status === 'active' AND billingPeriodEnd > Date.now()
    const isPremium = status === 'active' && expiry && expiry.toMillis() > Date.now();
    
    return { 
      isPremium: !!isPremium, 
      expiresAt: expiry ? expiry.toMillis() : null 
    };
  } catch (error) {
    console.error('verifySubscription Error:', error);
    throw new HttpsError('internal', 'Internal error verifying subscription.');
  }
});
