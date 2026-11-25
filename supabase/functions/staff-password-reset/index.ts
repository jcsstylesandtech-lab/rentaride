// Super admins reset an employee's dashboard password.
//   POST { user_id, mode: "email" }      → emails the employee a reset code
//   POST { user_id, mode: "temporary" }  → sets a one-time password (returned once);
//                                          the dashboard makes them choose a new one
// Only active super admins may call it, never on themselves, and only for staff.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

/** 4 groups of 4 from letters and digits that can't be confused (no 0/O, 1/l/I). */
function temporaryPassword(): string {
  const alphabet = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  for (;;) {
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    const chars = Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
    if (/[A-Za-z]/.test(chars) && /\d/.test(chars)) return chars.match(/.{4}/g)!.join("-");
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "Use POST" });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Who is calling?
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: caller } = await admin.auth.getUser(jwt);
  if (!caller?.user) return json(401, { error: "Sign in again." });

  const { data: me } = await admin.from("staff_members")
    .select("staff_role, active, profiles!staff_members_user_id_fkey(status)")
    .eq("user_id", caller.user.id).maybeSingle();
  const myStatus = (me?.profiles as { status?: string } | null)?.status;
  if (!me || !me.active || me.staff_role !== "super_admin" || myStatus !== "active") {
    return json(403, { error: "Only super admins can reset staff passwords." });
  }

  let body: { user_id?: string; mode?: string };
  try { body = await req.json(); } catch { return json(400, { error: "Send JSON." }); }
  const { user_id, mode } = body;
  if (!user_id || (mode !== "email" && mode !== "temporary")) {
    return json(400, { error: "Send user_id and mode (email or temporary)." });
  }
  if (user_id === caller.user.id) {
    return json(400, { error: "Use 'Forgot password?' on the sign-in page for your own account." });
  }

  const { data: target } = await admin.from("staff_members").select("user_id").eq("user_id", user_id).maybeSingle();
  if (!target) return json(404, { error: "That person is not on the staff list." });

  const { data: account, error: getErr } = await admin.auth.admin.getUserById(user_id);
  if (getErr || !account?.user) return json(404, { error: "Account not found." });
  const email = account.user.email;

  const audit = (action: string, details: Record<string, unknown>) =>
    admin.from("audit_log").insert({
      actor_id: caller.user.id, action, target_table: "auth.users", target_id: user_id, details,
    });

  if (mode === "email") {
    if (!email) return json(400, { error: "This account has no email address." });
    const { error } = await admin.auth.resetPasswordForEmail(email);
    if (error) return json(502, { error: error.message });
    await audit("staff.password_reset_email", { email });
    return json(200, { ok: true, email });
  }

  const password = temporaryPassword();
  const { error } = await admin.auth.admin.updateUserById(user_id, {
    password,
    user_metadata: { ...(account.user.user_metadata ?? {}), must_change_password: true },
  });
  if (error) return json(502, { error: error.message });
  await audit("staff.password_reset_temporary", { email });
  return json(200, { ok: true, email, password });
});
