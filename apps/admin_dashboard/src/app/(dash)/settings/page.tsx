"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { can, ROLE_HELP, ROLE_LABEL } from "@/lib/roles";
import { useStaff } from "@/components/staff-context";
import { Button, ErrorNote, PageHeader } from "@/components/ui";

export default function SettingsPage() {
  const staff = useStaff();
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  async function changePassword(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null); setDone(false);
    const { error } = await createClient().auth.updateUser({ password });
    setBusy(false);
    if (error) setError(error.message); else { setDone(true); setPassword(""); }
  }

  const perms: [string, boolean][] = [
    ["Approve or reject drivers", can.verifyDrivers(staff.role)],
    ["Suspend or reactivate users", can.manageUsers(staff.role)],
    ["Cancel rides", can.manageRides(staff.role)],
    ["Handle SOS alerts", can.handleSos(staff.role)],
    ["See payments and revenue", can.seeMoney(staff.role)],
    ["See the audit log", can.seeAudit(staff.role)],
    ["Manage staff access", can.manageStaff(staff.role)],
  ];

  return (
    <>
      <PageHeader title="Settings" subtitle="Your account and what your role allows." />
      <div className="grid gap-5 lg:grid-cols-2">
        <div className="card p-6">
          <p className="font-semibold">Your account</p>
          <p className="muted mt-3 text-sm">Name</p><p>{staff.name || "—"}</p>
          <p className="muted mt-3 text-sm">Email</p><p>{staff.email}</p>
          <p className="muted mt-3 text-sm">Role</p><p className="text-cyan">{ROLE_LABEL[staff.role]}</p>
          <p className="muted mt-1 text-xs">{ROLE_HELP[staff.role]}</p>
          <form onSubmit={changePassword} className="mt-6 space-y-3">
            <p className="font-semibold">Change password</p>
            <input type="password" minLength={8} required value={password} onChange={(e) => setPassword(e.target.value)}
              placeholder="New password (8+ characters)" autoComplete="new-password"
              className="pill w-full bg-white/5 px-4 py-2.5 text-sm outline-none focus:border-cyan/60" />
            {error && <ErrorNote message={error} />}
            {done && <p className="text-sm text-success">Password updated.</p>}
            <Button disabled={busy}>Update password</Button>
          </form>
        </div>
        <div className="card p-6">
          <p className="font-semibold">What you can do</p>
          <ul className="mt-4 space-y-2.5 text-sm">
            {perms.map(([label, ok]) => (
              <li key={label} className="flex items-center justify-between">
                <span>{label}</span>
                <span className={ok ? "text-success" : "text-white/35"}>{ok ? "Allowed" : "Not allowed"}</span>
              </li>
            ))}
          </ul>
          <p className="muted mt-5 text-xs">These rules are enforced by the database, not just this screen.</p>
        </div>
      </div>
    </>
  );
}
