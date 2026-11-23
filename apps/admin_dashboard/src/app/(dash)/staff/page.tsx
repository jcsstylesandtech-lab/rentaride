"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { logAudit } from "@/lib/audit";
import { can, ROLE_HELP, ROLE_LABEL, type StaffRole } from "@/lib/roles";
import { initials, shortDate } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { Badge, Button, Empty, ErrorNote, PageHeader, TableSkeleton, td, th } from "@/components/ui";

type Member = { user_id: string; staff_role: StaffRole; active: boolean; created_at: string;
  profile: { full_name: string; email: string | null } | null };
const ROLES = Object.keys(ROLE_LABEL) as StaffRole[];

export default function StaffPage() {
  const me = useStaff();
  const [rows, setRows] = useState<Member[] | null>(null);
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<StaffRole>("support");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const { data, error } = await createClient().from("staff_members")
      .select("user_id, staff_role, active, created_at, profile:profiles!staff_members_user_id_fkey(full_name, email)")
      .order("created_at");
    if (error) setError(error.message);
    setRows((data as unknown as Member[]) ?? []);
  }, []);
  useEffect(() => { load(); }, [load]);

  if (!can.manageStaff(me.role)) {
    return <div className="card"><Empty title="Super admins only" hint="Ask a super admin to change staff access." /></div>;
  }

  async function add(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null); setNotice(null);
    const supabase = createClient();
    const { data: person } = await supabase.from("profiles").select("id, full_name").ilike("email", email.trim()).maybeSingle();
    if (!person) {
      setError("No account with that email. Ask them to create one on the dashboard sign-in page first.");
      setBusy(false); return;
    }
    const { error } = await supabase.from("staff_members").insert({ user_id: person.id, staff_role: role, added_by: me.id });
    if (error) setError(error.code === "23505" ? "That person is already staff — change their role below." : error.message);
    else {
      await logAudit(supabase, me.id, "staff.added", "staff_members", person.id, { role });
      setNotice(`${person.full_name || email} can now sign in as ${ROLE_LABEL[role]}.`);
      setEmail(""); load();
    }
    setBusy(false);
  }

  async function change(m: Member, patch: Partial<Pick<Member, "staff_role" | "active">>) {
    const supabase = createClient();
    const { error } = await supabase.from("staff_members").update(patch).eq("user_id", m.user_id);
    if (error) { setError(error.message); return; }
    await logAudit(supabase, me.id, "staff.changed", "staff_members", m.user_id, patch);
    load();
  }

  return (
    <>
      <PageHeader title="Staff & access" subtitle="Who can use this dashboard and what each person can do." />
      <form onSubmit={add} className="card mb-5 flex flex-wrap items-end gap-3 p-5">
        <label className="flex-1 text-sm">
          <span className="muted mb-1 block text-xs">Employee email (they must have signed up)</span>
          <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@rentaride.ng"
            className="pill w-full bg-white/5 px-4 py-2.5 outline-none focus:border-cyan/60" />
        </label>
        <label className="text-sm">
          <span className="muted mb-1 block text-xs">Role</span>
          <select value={role} onChange={(e) => setRole(e.target.value as StaffRole)}
            className="pill bg-ink px-4 py-2.5 outline-none">
            {ROLES.map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
          </select>
        </label>
        <Button disabled={busy}>Give access</Button>
        <p className="muted w-full text-xs">{ROLE_LABEL[role]}: {ROLE_HELP[role]}</p>
      </form>
      {error && <div className="mb-4"><ErrorNote message={error} /></div>}
      {notice && <div className="mb-4 rounded-xl bg-success/10 px-4 py-3 text-sm text-success">{notice}</div>}
      <div className="card overflow-x-auto">
        {!rows ? <TableSkeleton /> : (
          <table className="w-full min-w-[700px]">
            <thead className="border-b border-white/5"><tr>
              <th className={th}>Employee</th><th className={th}>Role</th><th className={th}>Since</th><th className={th}>Access</th>
            </tr></thead>
            <tbody className="divide-y divide-white/5">
              {rows.map((m) => {
                const self = m.user_id === me.id;
                return (
                  <tr key={m.user_id}>
                    <td className={td}><div className="flex items-center gap-3">
                      <div className="grid h-9 w-9 place-items-center rounded-full bg-white/10 text-xs font-semibold">{initials(m.profile?.full_name)}</div>
                      <div><p className="font-medium">{m.profile?.full_name || "Unnamed"} {self && <Badge tone="info">You</Badge>}</p>
                        <p className="muted text-xs">{m.profile?.email}</p></div>
                    </div></td>
                    <td className={td}>
                      <select disabled={self} value={m.staff_role} onChange={(e) => change(m, { staff_role: e.target.value as StaffRole })}
                        className="pill bg-ink px-3 py-1.5 text-sm outline-none disabled:opacity-60">
                        {ROLES.map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
                      </select>
                    </td>
                    <td className={td}>{shortDate(m.created_at)}</td>
                    <td className={td}>
                      {self ? <span className="muted text-xs">You can&apos;t remove yourself</span> : m.active
                        ? <Button variant="danger" onClick={() => change(m, { active: false })}>Revoke</Button>
                        : <Button variant="success" onClick={() => change(m, { active: true })}>Restore</Button>}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
