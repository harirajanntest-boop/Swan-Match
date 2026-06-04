Subject: Important decision before App Store submission — Apple payment rules

Hi Sasikumar,

Before we submit to the Apple App Store, there's one important issue I want to flag so we can decide
together. It affects how we charge for premium on iPhone.

## The situation
Right now the app uses Stripe for premium subscriptions. Stripe works perfectly on the website and on
Android. However, Apple has a strict rule: anything "digital" that is unlocked inside an iPhone app
(like our premium features — messaging, unlimited profiles, etc.) must be purchased through Apple's
own payment system, called In-App Purchase. Apple takes a 15–30% commission on those payments.

If we submit the iPhone app using only Stripe, Apple will very likely reject it. This is the same
reason apps like Tinder, Bumble, and Hinge all use Apple's payment system on iPhone.

## Our options
1. Add Apple In-App Purchase for iPhone (recommended, safest)
   - Use Apple's payment on iPhone, and keep Stripe on the website and Android.
   - Pro: gets us approved everywhere with no surprises.
   - Con: Apple takes 15–30%, and it requires some additional development work.

2. Use Apple's new "external link" option (US only)
   - Since 2025, Apple allows apps in the US to link out to an outside payment page (Stripe).
   - Pro: we could keep Stripe and avoid Apple's commission.
   - Con: this only applies to the US App Store, the rules are strict, and it carries more risk of
     rejection if not done exactly right.

3. Keep Stripe only
   - No change, but Apple will most likely reject the app. Not recommended.

## My recommendation
- iPhone: add Apple In-App Purchase for the subscription (the safe path to approval).
- Android: keep Stripe (or add Google Play Billing — Google is more flexible).
- Website: keep Stripe — no change needed.

## What I need from you
Please confirm how you'd like to proceed on iPhone payments:
- Option 1 (add Apple In-App Purchase), or
- Option 2 (try the US external-link approach).

Once you decide, I'll scope the work and timeline. Everything else for launch is in good shape — this
is the main remaining item that affects Apple approval.

Happy to jump on a quick call if it's easier to talk through.

Best regards,
[Your name]
