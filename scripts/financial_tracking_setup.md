# SWAN MATCH — STRIPE & FINANCIAL METRICS SETUP GUIDE
*A comprehensive guide for configuring products, managing price plans in the Stripe Dashboard, setting secure webhooks, and tracking platform unit economics.*

---

## 1. Stripe Product & Pricing Plan Configurations
To support premium subscription upgrades in the mobile client, configure three pricing tiers inside your Stripe Dashboard (`dashboard.stripe.com`):

### A. Monthly Subscription ($19.99/mo)
- **Product Name:** Swan Match Premium Monthly
- **Billing Period:** Monthly (Recurring)
- **Amount:** $19.99 USD
- **Stripe Price ID:** (Save this ID in your Firebase cloud environment secrets under the key `STRIPE_PRICE_MONTHLY`).
  ```bash
  firebase functions:secrets:set STRIPE_PRICE_MONTHLY="price_YOUR_MONTHLY_PRICE_ID"
  ```

### B. Six-Month Subscription ($79.99/6mo - $13.33/mo)
- **Product Name:** Swan Match Premium 6-Month
- **Billing Period:** Every 6 Months (Recurring)
- **Amount:** $79.99 USD
- **Stripe Price ID:** (Save this ID in your Firebase secrets under the key `STRIPE_PRICE_SIXMONTH`. Falls back to current Test ID if not set).
  ```bash
  firebase functions:secrets:set STRIPE_PRICE_SIXMONTH="price_YOUR_6MONTH_PRICE_ID"
  ```

### C. Yearly Subscription ($119.99/yr - $9.99/mo)
- **Product Name:** Swan Match Premium Yearly
- **Billing Period:** Yearly (Recurring)
- **Amount:** $119.99 USD
- **Stripe Price ID:** (Save this ID in your Firebase secrets under the key `STRIPE_PRICE_YEARLY`. Falls back to current Test ID if not set).
  ```bash
  firebase functions:secrets:set STRIPE_PRICE_YEARLY="price_YOUR_YEARLY_PRICE_ID"
  ```

---

## 2. Webhook & Endpoint Registration
Stripe requires a webhook endpoint registered to sync subscription events (successes, renewals, cancellations, chargebacks) to our database instantly.

1. **Production Endpoint URL:**
   `https://us-central1-swan-match.cloudfunctions.net/handleStripeWebhook`
2. **Stripe Event Subscriptions:**
   Subscribe the webhook to the following events:
   - `checkout.session.completed` (handles initial checkout)
   - `customer.subscription.created`
   - `customer.subscription.updated` (syncs status updates, upgrades, and cancellations)
   - `customer.subscription.deleted` (reverts account back to Free tier)
   - `invoice.paid` (tracks renewals and invoice success)
   - `invoice.payment_failed` (triggers push notifications to update cards)
3. **Save Webhook Secret:**
   Obtain the Signing Secret (looks like `whsec_...`) from Stripe and save it in your Firebase secret vault:
   ```bash
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET="whsec_YOUR_SIGNING_SECRET"
   ```

---

## 3. Web Admin Analytics Dashboard Verification
All unit economics calculations are derived in real-time inside `frontend/src/pages/Analytics.jsx` using transactional billing events. Verify the following metrics when reviewing your dashboard:

- **Customer Acquisition Cost (CAC):** Mapped directly by dividing the monthly marketing budget (configured under the Settings panel or Firebase Config store) by the number of new user signups.
- **Subscription Churn Rate:** Measured as the ratio of `canceled` or `past_due` premium users to total premium signups. The platform target is **< 5.0%**.
- **Customer Lifetime Value (LTV):** Calculated automatically as:
  $$\text{LTV} = \frac{\text{Active Premium ARPU}}{\text{Churn Rate}}$$
  This demonstrates product profitability when LTV is greater than 3x CAC.
- **Refund & Chargeback Rates:** Tracks billing risks. Refund and chargeback webhooks automatically flag users and record dispute metrics.
- **Burn Rate:** Tracks hosting scale and base serverless operation cost allocations.
