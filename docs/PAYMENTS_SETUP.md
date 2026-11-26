# Switching on payments (Paystack)

Everything for wallets, top-ups, trip settlement and driver withdrawals is
built and deployed. Until a Paystack key is added, the apps show
"Payments aren't switched on yet" instead of opening a checkout.

## 1. Add your Paystack secret key (5 minutes)

1. Paystack dashboard → **Settings → API Keys & Webhooks**. Copy the
   **Test Secret Key** (`sk_test_…`). Use the live key only when you go live.
2. Supabase dashboard → project **apebeihmocdomsrhefqs** → **Edge Functions →
   Secrets** → add `PAYSTACK_SECRET_KEY` with that value.

Never put the secret key in the apps or in git. Only the Edge Functions use it.

## 2. Point Paystack's webhook at Rent A Ride

In the same Paystack page, set **Webhook URL** (test and live) to:

```
https://apebeihmocdomsrhefqs.supabase.co/functions/v1/paystack-webhook
```

The webhook checks Paystack's signature on every request. The passenger
app also confirms a top-up itself when the rider returns from checkout, so a
slow webhook never leaves money missing.

## 3. Driver payouts (transfers)

- Paystack → **Settings → Preferences → Transfers**: turn **off** "Confirm
  transfers with OTP". With it on, approving a withdrawal can't complete;
  the money goes back to the driver with a message saying why.
- Transfers are paid from your **Paystack balance**. In test mode, top up
  the test balance from the Paystack dashboard.
- Live transfers need a Paystack business that is activated for transfers.

## How money moves

| Event | Passenger wallet | Driver wallet |
|-------|------------------|---------------|
| Top-up (Paystack) | + amount | |
| Trip paid by wallet | − fare | + fare − 15% commission |
| Trip paid in cash | | − 15% commission (owed if the balance is short; taken from the next earnings) |
| Withdrawal requested | | − amount (held) |
| Withdrawal rejected / transfer failed | | + amount back |

Commission, minimum top-up (₦500), maximum top-up (₦500,000) and minimum
withdrawal (₦1,000) live in the `platform_settings` table. Finance staff can
change them.

## Testing with Paystack test cards

Card `4084 0840 8408 4081`, any future expiry, CVV `408`, PIN `0000`, OTP
`123456`. More are listed in Paystack's "Test payments" docs.

## Not built yet

- Flutterwave (Paystack only for now).
- Charging a saved card at the end of a trip. Riders pay by wallet or cash.
- Refunds to a card (wallet refunds work).
