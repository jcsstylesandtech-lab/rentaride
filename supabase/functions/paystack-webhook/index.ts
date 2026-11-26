// Paystack webhook: Paystack → https://<project>.supabase.co/functions/v1/paystack-webhook
// Deployed without JWT checking; every request must carry a valid
// x-paystack-signature (HMAC-SHA512 of the body with the secret key).
//   charge.success                      → confirm with Paystack, credit the wallet (once)
//   transfer.success                    → withdrawal paid
//   transfer.failed / transfer.reversed → withdrawal failed, money back to the driver
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { confirmTopUp, finishWithdrawal, paystackKey, sameSignature, signature } from "../_shared/paystack.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });
  if (!paystackKey()) return new Response("Not configured", { status: 503 });

  const raw = await req.text();
  const expected = await signature(raw);
  const given = req.headers.get("x-paystack-signature") ?? "";
  if (!expected || !sameSignature(expected, given.toLowerCase())) {
    return new Response("Bad signature", { status: 401 });
  }

  let event: { event?: string; data?: Record<string, unknown> };
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }
  const data = event.data ?? {};
  const reference = String(data.reference ?? "");

  try {
    switch (event.event) {
      case "charge.success":
        // Only our wallet top-ups; verify with Paystack rather than trusting the payload.
        if (reference.startsWith("tu-")) await confirmTopUp(reference);
        break;
      case "transfer.success":
        if (reference.startsWith("wd-")) await finishWithdrawal(reference, true, String(data.transfer_code ?? ""));
        break;
      case "transfer.failed":
      case "transfer.reversed":
        if (reference.startsWith("wd-")) {
          await finishWithdrawal(reference, false, String(data.transfer_code ?? ""),
            `Transfer ${event.event === "transfer.failed" ? "failed" : "reversed"} at Paystack`);
        }
        break;
    }
  } catch (e) {
    // A non-2xx makes Paystack retry later; every handler above is idempotent.
    console.error(event.event, reference, e);
    return new Response("Retry later", { status: 500 });
  }
  return new Response("ok", { status: 200 });
});
