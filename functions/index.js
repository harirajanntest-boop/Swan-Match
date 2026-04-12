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

const { onCall, HttpsError, onRequest } = require('firebase-functions/v2/https');
// Set this using: firebase functions:secrets:set STRIPE_SECRET_KEY
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY || 'sk_test_PLACEHOLDER');

exports.checkPhoneExists = onCall(async (request) => {
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
exports.createCheckoutSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { priceId, successUrl, cancelUrl } = request.data;
  if (!priceId) {
    throw new HttpsError('invalid-argument', 'The function must be called with "priceId".');
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email;

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
      metadata: { firebaseUid: uid },
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
exports.handleStripeWebhook = onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const endpointSecret = 'whsec_...'; // USER MUST CONFIG THIS

  let event;

  try {
    // For local testing without signature verification, you can use:
    // event = req.body;
    // But for production/deployed:
    event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
  } catch (err) {
    console.error('Webhook Signature Verify Failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  const db = admin.firestore();

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object;
        const uid = session.metadata.firebaseUid;
        if (uid) {
          await db.collection('users').doc(uid).update({
            subscriptionStatus: 'active',
            lastCheckoutSessionId: session.id,
            stripeSubscriptionId: session.subscription,
            stripeCustomerId: session.customer,
            customerEmail: session.customer_details?.email,
            customerName: session.customer_details?.name,
            subscriptionPlan: 'premium',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        break;
      }
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
      case 'customer.subscription.created': {
        const subscription = event.data.object;
        const customer = await stripe.customers.retrieve(subscription.customer);
        const uid = customer.metadata?.firebaseUid;
        
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
        const uid = customer.metadata?.firebaseUid;
        if (uid) {
          await db.collection('users').doc(uid).update({
            paymentStatus: 'paid',
            lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        break;
      }
      case 'invoice.payment_failed': {
        const invoice = event.data.object;
        const customer = await stripe.customers.retrieve(invoice.customer);
        const uid = customer.metadata?.firebaseUid;
        if (uid) {
          await db.collection('users').doc(uid).update({
            paymentStatus: 'failed',
            subscriptionStatus: 'past_due',
          });
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
