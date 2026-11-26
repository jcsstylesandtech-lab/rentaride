// Paystack helpers shared by the payments and paystack-webhook functions.
// The secret key lives only in the Edge Function environment:
//   Supabase dashboard → Edge Functions → Secrets → PAYSTACK_SECRET_KEY=sk_test_...
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

export const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

export class PaystackError extends Error {
  constructor(message: string, readonly status = 502) {
    super(message);
  }
}

export const NOT_CONFIGURED =
  "Payments aren't switched on yet. The Paystack key still needs to be added on the server.";

export function paystackKey(): string | null {
  return Deno.env.get("PAYSTACK_SECRET_KEY") ?? null;
}

/** Calls the Paystack API and returns `data`, or throws PaystackError with Paystack's message. */
export async function paystack<T = Record<string, unknown>>(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<T> {
  const key = paystackKey();
  if (!key) throw new PaystackError(NOT_CONFIGURED, 503);
  let res: Response;
  try {
    res = await fetch(`https://api.paystack.co${path}`, {
      method: init.method ?? "GET",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });
  } catch {
    throw new PaystackError("Couldn't reach Paystack. Try again in a moment.");
  }
  const payload = await res.json().catch(() => ({}));
  if (!res.ok || payload.status === false) {
    throw new PaystackError(payload.message ?? `Paystack error (${res.status})`, res.status >= 500 ? 502 : 400);
  }
  return payload.data as T;
}

export function serviceClient() {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** A client that acts as the calling user, so row-level security and auth.uid() apply. */
export function userClient(req: Request) {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** HMAC-SHA512 of the raw body with the secret key, hex encoded (Paystack's x-paystack-signature). */
export async function signature(body: string): Promise<string | null> {
  const key = paystackKey();
  if (!key) return null;
  const k = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(key), { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(body));
  return Array.from(new Uint8Array(sig), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Constant-time comparison of two hex strings. */
export function sameSignature(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

type Verified = { status: string; amount: number; currency: string; channel?: string; reference: string };

/** Confirms a payment with Paystack and credits the wallet (idempotent). */
export async function confirmTopUp(reference: string) {
  const db = serviceClient();
  const tx = await paystack<Verified>(`/transaction/verify/${encodeURIComponent(reference)}`);
  if (tx.status === "success" && tx.currency === "NGN") {
    const { data, error } = await db.rpc("complete_top_up", {
      p_reference: reference, p_amount_kobo: tx.amount, p_channel: tx.channel ?? null,
    });
    if (error) throw new PaystackError(error.message, 500);
    return data as { status: string; amount_kobo: number };
  }
  if (["failed", "abandoned", "reversed"].includes(tx.status)) {
    await db.rpc("fail_top_up", { p_reference: reference, p_reason: `Paystack: ${tx.status}` });
    return { status: "failed", amount_kobo: tx.amount };
  }
  return { status: "pending", amount_kobo: tx.amount };
}

/** Transfer outcome → withdrawal status (money is returned on failure). */
export async function finishWithdrawal(reference: string, success: boolean, transferCode?: string, reason?: string) {
  const { error } = await serviceClient().rpc("finish_withdrawal", {
    p_reference: reference, p_success: success, p_transfer_code: transferCode ?? null, p_reason: reason ?? null,
  });
  if (error) throw new PaystackError(error.message, 500);
}
