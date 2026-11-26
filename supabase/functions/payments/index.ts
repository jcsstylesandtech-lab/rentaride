// Rent A Ride payments (Paystack). Every call needs a signed-in user.
//   { action: "top_up", amount_kobo, callback_url? }  → { reference, authorization_url }
//   { action: "verify", reference }                    → { status, amount_kobo }   (credits the wallet once)
//   { action: "banks" }                                → { banks: [{ name, code }] }
//   { action: "save_payout_account", bank_code, account_number } (drivers)
//                                                      → { bank_name, account_number, account_name }
//   { action: "approve_withdrawal", withdrawal_id }    (finance staff) → { status }
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  CORS, NOT_CONFIGURED, PaystackError, confirmTopUp, finishWithdrawal, json, paystack, paystackKey,
  serviceClient, userClient,
} from "../_shared/paystack.ts";

type Bank = { name: string; code: string; active?: boolean };
let bankCache: { at: number; banks: Bank[] } | null = null;

async function listBanks(): Promise<Bank[]> {
  if (bankCache && Date.now() - bankCache.at < 6 * 60 * 60 * 1000) return bankCache.banks;
  const key = paystackKey();
  if (!key) throw new PaystackError(NOT_CONFIGURED, 503);
  const banks: Bank[] = [];
  let next: string | null = null;
  for (let page = 0; page < 10; page++) {
    const q = new URLSearchParams({ country: "nigeria", currency: "NGN", perPage: "100", use_cursor: "true" });
    if (next) q.set("next", next);
    const res = await fetch(`https://api.paystack.co/bank?${q}`, { headers: { Authorization: `Bearer ${key}` } });
    const body = await res.json().catch(() => ({}));
    if (!res.ok || body.status === false) throw new PaystackError(body.message ?? "Couldn't load banks.");
    banks.push(...(body.data as Bank[]));
    next = body.meta?.next ?? null;
    if (!next) break;
  }
  const unique = new Map<string, Bank>();
  for (const b of banks) if (b.active !== false) unique.set(b.code, { name: b.name, code: b.code });
  const sorted = [...unique.values()].sort((a, b) => a.name.localeCompare(b.name));
  bankCache = { at: Date.now(), banks: sorted };
  return sorted;
}

const hex = () => crypto.randomUUID().replaceAll("-", "");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "Use POST" });

  const db = serviceClient();
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: auth } = await db.auth.getUser(jwt);
  const user = auth?.user;
  if (!user) return json(401, { error: "Sign in again." });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Send a JSON body." });
  }

  try {
    switch (body.action) {
      case "top_up": {
        const amount = Number(body.amount_kobo);
        if (!Number.isSafeInteger(amount) || amount <= 0) return json(400, { error: "Enter an amount." });
        if (!paystackKey()) return json(503, { error: NOT_CONFIGURED });
        const { data: profile } = await db.from("profiles").select("email, status").eq("id", user.id).single();
        if (profile?.status !== "active") return json(403, { error: "Your account isn't active." });
        const reference = `tu-${hex()}`;
        const { error } = await db.rpc("start_top_up", {
          p_user: user.id, p_amount_kobo: amount, p_reference: reference,
        });
        if (error) return json(400, { error: error.message });
        const callback = typeof body.callback_url === "string" &&
            /^(https:\/\/|rentaride:\/\/)/.test(body.callback_url) ? body.callback_url : undefined;
        try {
          const init = await paystack<{ authorization_url: string }>("/transaction/initialize", {
            method: "POST",
            body: {
              email: profile?.email ?? user.email ?? `rider-${user.id}@users.rentaride.ng`,
              amount,
              currency: "NGN",
              reference,
              callback_url: callback,
              channels: ["card", "bank", "ussd", "bank_transfer"],
              metadata: { purpose: "wallet_top_up", user_id: user.id },
            },
          });
          return json(200, { reference, authorization_url: init.authorization_url });
        } catch (e) {
          await db.rpc("fail_top_up", { p_reference: reference, p_reason: (e as Error).message });
          throw e;
        }
      }

      case "verify": {
        const reference = String(body.reference ?? "");
        const { data: payment } = await db.from("payments").select("user_id, status, amount_kobo")
          .eq("reference", reference).maybeSingle();
        if (!payment || payment.user_id !== user.id) return json(404, { error: "Payment not found." });
        if (payment.status !== "pending") return json(200, { status: payment.status, amount_kobo: payment.amount_kobo });
        return json(200, await confirmTopUp(reference));
      }

      case "banks":
        return json(200, { banks: await listBanks() });

      case "save_payout_account": {
        const bankCode = String(body.bank_code ?? "");
        const accountNumber = String(body.account_number ?? "");
        if (!/^\d{10}$/.test(accountNumber)) return json(400, { error: "Enter your 10-digit account number." });
        const { data: driver } = await db.from("drivers").select("id").eq("id", user.id).maybeSingle();
        if (!driver) return json(403, { error: "Only drivers can add a payout account." });
        const bank = (await listBanks()).find((b) => b.code === bankCode);
        if (!bank) return json(400, { error: "Choose your bank from the list." });
        let resolved: { account_name: string };
        try {
          resolved = await paystack(`/bank/resolve?account_number=${accountNumber}&bank_code=${encodeURIComponent(bankCode)}`);
        } catch (e) {
          if (e instanceof PaystackError && e.status === 503) throw e;
          return json(400, { error: "We couldn't find that account at this bank. Check the number and bank." });
        }
        const recipient = await paystack<{ recipient_code: string }>("/transferrecipient", {
          method: "POST",
          body: { type: "nuban", name: resolved.account_name, account_number: accountNumber, bank_code: bankCode, currency: "NGN" },
        });
        const { error } = await db.from("payout_accounts").upsert({
          driver_id: user.id, bank_code: bankCode, bank_name: bank.name, account_number: accountNumber,
          account_name: resolved.account_name, recipient_code: recipient.recipient_code, updated_at: new Date().toISOString(),
        });
        if (error) return json(500, { error: error.message });
        return json(200, { bank_name: bank.name, account_number: accountNumber, account_name: resolved.account_name });
      }

      case "approve_withdrawal": {
        if (!paystackKey()) return json(503, { error: NOT_CONFIGURED });
        // The role check and the status change happen in the database as the caller.
        const { data: w, error } = await userClient(req).rpc("begin_withdrawal", { p_id: body.withdrawal_id });
        if (error) return json(error.code === "42501" ? 403 : 400, { error: error.message });
        try {
          const transfer = await paystack<{ status: string; transfer_code: string }>("/transfer", {
            method: "POST",
            body: {
              source: "balance", amount: w.amount_kobo, recipient: w.recipient_code,
              reference: w.reference, reason: "Rent A Ride driver earnings",
            },
          });
          if (transfer.status === "success") {
            await finishWithdrawal(w.reference, true, transfer.transfer_code);
            return json(200, { status: "paid" });
          }
          if (transfer.status === "otp") {
            await finishWithdrawal(w.reference, false, transfer.transfer_code,
              "Paystack asked for an OTP. Turn off OTP for transfers in Paystack, then approve again.");
            return json(409, { error: "Paystack needs an OTP for transfers. Turn it off in Paystack settings; the money went back to the driver." });
          }
          await serviceClient().rpc("set_withdrawal_transfer", { p_reference: w.reference, p_transfer_code: transfer.transfer_code });
          return json(200, { status: "processing" }); // the webhook reports the outcome
        } catch (e) {
          await finishWithdrawal(w.reference, false, undefined, (e as Error).message);
          throw e;
        }
      }

      default:
        return json(400, { error: "Unknown action." });
    }
  } catch (e) {
    if (e instanceof PaystackError) return json(e.status, { error: e.message });
    console.error(e);
    return json(500, { error: "Something went wrong. Try again." });
  }
});
