"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Logo } from "./logo";
import { createClient } from "@/lib/supabase/client";

/** Shown instead of the dashboard after a super admin set a temporary password. */
export function MustChangePassword({ email }: { email: string }) {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (password !== confirm) { setError("The passwords do not match"); return; }
    if (!/^(?=.*[A-Za-z])(?=.*\d).{8,}$/.test(password)) { setError("At least 8 characters with a letter and a number"); return; }
    setBusy(true);
    const { error } = await createClient().auth.updateUser({ password, data: { must_change_password: false } });
    setBusy(false);
    if (error) {
      setError(error.message.toLowerCase().includes("should be different")
        ? "Choose a password different from the temporary one." : error.message);
      return;
    }
    router.refresh();
  }

  const input = "pill w-full bg-white/5 px-4 py-3 text-sm outline-none placeholder:text-white/40 focus:border-cyan/60";
  return (
    <div className="grid min-h-screen place-items-center p-6">
      <form onSubmit={save} className="card w-full max-w-sm p-8">
        <div className="mb-6 flex items-center gap-3">
          <Logo size={40} />
          <div><p className="font-semibold">Rent A Ride</p><p className="text-xs text-cyan">Admin console</p></div>
        </div>
        <h1 className="text-xl font-semibold">Choose your own password</h1>
        <p className="muted mb-6 mt-1 text-sm">
          {email} signed in with a temporary password from a super admin. Set your own to continue.
        </p>
        <div className="space-y-3">
          <input className={input} type="password" placeholder="New password" autoComplete="new-password"
            value={password} onChange={(e) => setPassword(e.target.value)} required />
          <input className={input} type="password" placeholder="Confirm new password" autoComplete="new-password"
            value={confirm} onChange={(e) => setConfirm(e.target.value)} required />
        </div>
        <p className="muted mt-2 text-xs">At least 8 characters with a letter and a number.</p>
        {error && <p className="mt-4 rounded-xl bg-danger/10 px-4 py-2.5 text-sm text-danger">{error}</p>}
        <button disabled={busy}
          className="mt-6 w-full rounded-full bg-gradient-to-r from-royal to-cyan py-3 text-sm font-semibold shadow-lg shadow-royal/30 disabled:opacity-50">
          {busy ? "Saving…" : "Save and continue"}
        </button>
        <button type="button" onClick={async () => { await createClient().auth.signOut(); router.replace("/login"); router.refresh(); }}
          className="muted mt-4 w-full text-sm hover:text-white">Sign out</button>
      </form>
    </div>
  );
}
