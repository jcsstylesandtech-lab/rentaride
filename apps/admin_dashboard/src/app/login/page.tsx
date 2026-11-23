"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Logo } from "@/components/logo";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<"in" | "up">("in");
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
        <h1 className="text-xl font-semibold">{mode === "in" ? "Staff sign in" : "Create staff account"}</h1>
        <p className="muted mb-6 mt-1 text-sm">
          {mode === "in" ? "For Rent A Ride employees only." : "A super admin must grant access after you sign up."}
        </p>
        <div className="space-y-3">
          {mode === "up" && (
            <input className={input} placeholder="Full name" value={name} onChange={(e) => setName(e.target.value)} required />
          )}
          <input className={input} type="email" placeholder="Work email" autoComplete="email"
            value={email} onChange={(e) => setEmail(e.target.value)} required />
          <input className={input} type="password" placeholder="Password" minLength={8}
            autoComplete={mode === "in" ? "current-password" : "new-password"}
            value={password} onChange={(e) => setPassword(e.target.value)} required />
        </div>
        {error && <p className="mt-4 rounded-xl bg-danger/10 px-4 py-2.5 text-sm text-danger">{error}</p>}
        {notice && <p className="mt-4 rounded-xl bg-cyan/10 px-4 py-2.5 text-sm text-cyan">{notice}</p>}
        <button disabled={busy}
          className="mt-6 w-full rounded-full bg-gradient-to-r from-royal to-cyan py-3 text-sm font-semibold shadow-lg shadow-royal/30 disabled:opacity-50">
          {busy ? "Please wait…" : mode === "in" ? "Sign in" : "Create account"}
        </button>
        <button type="button" onClick={() => { setMode(mode === "in" ? "up" : "in"); setError(null); }}
          className="muted mt-4 w-full text-sm hover:text-white">
          {mode === "in" ? "New staff member? Create an account" : "Already have an account? Sign in"}
        </button>
      </form>
    </div>
  );
}
