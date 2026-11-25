"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Logo } from "@/components/logo";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<"in" | "up" | "forgot" | "reset">("in");
  const [code, setCode] = useState("");
  const [confirm, setConfirm] = useState("");
  const [codeAccepted, setCodeAccepted] = useState(false); // a used code can't be checked twice
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null); setNotice(null);
    const supabase = createClient();
    if (mode === "forgot") {
      const { error } = await supabase.auth.resetPasswordForEmail(email.trim());
      setBusy(false);
      if (error) { setError(friendly(error.message)); return; }
      setNotice(`We emailed a code to ${email.trim()}. It may take a minute — check spam too.`);
      setPassword(""); setCode(""); setConfirm(""); setCodeAccepted(false);
      setMode("reset");
      return;
    }
    if (mode === "reset") {
      if (password !== confirm) { setError("The passwords do not match"); setBusy(false); return; }
      if (!/^(?=.*[A-Za-z])(?=.*\d).{8,}$/.test(password)) {
        setError("At least 8 characters with a letter and a number"); setBusy(false); return;
      }
      if (!codeAccepted) {
        const { error } = await supabase.auth.verifyOtp({ email: email.trim(), token: code.trim(), type: "recovery" });
        if (error) { setError(friendly(error.message)); setBusy(false); return; }
        setCodeAccepted(true);
      }
      const { error } = await supabase.auth.updateUser({ password });
      if (error) { setError(friendly(error.message)); setBusy(false); return; }
      router.replace("/"); router.refresh();
      return;
    }
    if (mode === "in") {
      const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (error) { setError(error.message); setBusy(false); return; }
      router.replace("/"); router.refresh();
    } else {
      const { data, error } = await supabase.auth.signUp({
        email: email.trim(), password, options: { data: { full_name: name.trim() } },
      });
      setBusy(false);
      if (error) { setError(error.message); return; }
      if (data.session) { router.replace("/"); router.refresh(); return; }
      setNotice("Check your email to confirm your account, then sign in. A super admin must also add you as staff.");
      setMode("in");
    }
  }

  const input = "pill w-full bg-white/5 px-4 py-3 text-sm outline-none placeholder:text-white/40 focus:border-cyan/60";

  return (
    <div className="grid min-h-screen place-items-center p-6">
      <form onSubmit={submit} className="card w-full max-w-sm p-8">
        <div className="mb-6 flex items-center gap-3">
          <Logo size={40} />
          <div>
            <p className="font-semibold">Rent A Ride</p>
            <p className="text-xs text-cyan">Admin console</p>
          </div>
        </div>
        <h1 className="text-xl font-semibold">{TITLES[mode]}</h1>
        <p className="muted mb-6 mt-1 text-sm">{SUBTITLES[mode]}</p>
        <div className="space-y-3">
          {mode === "up" && (
            <input className={input} placeholder="Full name" value={name} onChange={(e) => setName(e.target.value)} required />
          )}
          <input className={input} type="email" placeholder="Work email" autoComplete="email" disabled={mode === "reset"}
            value={email} onChange={(e) => setEmail(e.target.value)} required />
          {mode === "reset" && !codeAccepted && (
            <input className={input} inputMode="numeric" placeholder="Code from the email" autoComplete="one-time-code"
              pattern="[0-9]{6,10}" title="The code from the email"
              value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))} required />
          )}
          {mode !== "forgot" && (
            <input className={input} type="password" placeholder={mode === "reset" ? "New password" : "Password"} minLength={8}
              autoComplete={mode === "in" ? "current-password" : "new-password"}
              value={password} onChange={(e) => setPassword(e.target.value)} required />
          )}
          {mode === "reset" && (
            <input className={input} type="password" placeholder="Confirm new password" autoComplete="new-password"
              value={confirm} onChange={(e) => setConfirm(e.target.value)} required />
          )}
          {mode === "in" && (
            <button type="button" onClick={() => { setMode("forgot"); setError(null); setNotice(null); }}
              className="block w-full text-right text-sm text-cyan hover:text-white">
              Forgot password?
            </button>
          )}
        </div>
        {error && <p className="mt-4 rounded-xl bg-danger/10 px-4 py-2.5 text-sm text-danger">{error}</p>}
        {notice && <p className="mt-4 rounded-xl bg-cyan/10 px-4 py-2.5 text-sm text-cyan">{notice}</p>}
        <button disabled={busy}
          className="mt-6 w-full rounded-full bg-gradient-to-r from-royal to-cyan py-3 text-sm font-semibold shadow-lg shadow-royal/30 disabled:opacity-50">
          {busy ? "Please wait…" : BUTTONS[mode]}
        </button>
        {mode === "reset" && !codeAccepted && (
          <button type="button" disabled={busy} onClick={() => { setMode("forgot"); setError(null); setNotice(null); }}
            className="muted mt-4 w-full text-sm hover:text-white">
            Send a new code or use a different email
          </button>
        )}
        <button type="button" onClick={() => { setMode(mode === "in" ? "up" : "in"); setError(null); setNotice(null); }}
          className="muted mt-4 w-full text-sm hover:text-white">
          {mode === "in" ? "New staff member? Create an account" : "Back to sign in"}
        </button>
      </form>
    </div>
  );
}

const TITLES = { in: "Staff sign in", up: "Create staff account", forgot: "Reset your password", reset: "Choose a new password" };
const SUBTITLES = {
  in: "For Rent A Ride employees only.",
  up: "A super admin must grant access after you sign up.",
  forgot: "Enter your work email. We'll send you a code to reset your password.",
  reset: "Enter the code from the email and choose a new password.",
};
const BUTTONS = { in: "Sign in", up: "Create account", forgot: "Send code", reset: "Save new password" };

/** Plain-language versions of the Supabase errors staff are likely to see here. */
function friendly(message: string): string {
  const m = message.toLowerCase();
  if (m.includes("expired") || m.includes("invalid")) return "That code is wrong or has expired. Check it, or send a new code.";
  if (m.includes("should be different")) return "Choose a password different from your old one.";
  if (m.includes("rate limit") || m.includes("security purposes")) return "Too many attempts. Wait a minute and try again.";
  return message;
}
