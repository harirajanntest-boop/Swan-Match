const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY || 'your_stripe_secret_key_here');

async function listPrices() {
  try {
    const prices = await stripe.prices.list({
      expand: ['data.product'],
    });
    console.log(JSON.stringify(prices.data, null, 2));
  } catch (error) {
    console.error(error);
  }
}

listPrices();
