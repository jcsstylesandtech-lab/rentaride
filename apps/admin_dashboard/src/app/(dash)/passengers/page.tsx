"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { logAudit } from "@/lib/audit";
import { can } from "@/lib/roles";
import { dateTime, initials, naira, shortDate } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { Button, Drawer, Empty, ErrorNote, PageHeader, SearchInput, StatusBadge, TableSkeleton, Tabs, td, th } from "@/components/ui";

type Person = {
  id: string; full_name: string; email: string | null; phone: string | null; status: string;
  phone_verified: boolean; rating_avg: number; rating_count: number; created_at: string;
};
type Filter = "active" | "suspended";

export default function PassengersPage() {
  const staff = useStaff();
  const [filter, setFilter] = useState<Filter>("active");
  const [query, setQuery] = useState("");
  const [rows, setRows] = useState<Person[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState<Person | null>(null);

  const load = useCallback(async () => {
    let req = createClient().from("profiles")
      .select("id, full_name, email, phone, status, phone_verified, rating_avg, rating_count, created_at")
      .eq("role", "passenger").eq("status", filter).order("created_at", { ascending: false }).limit(200);
    const q = query.trim();
    if (q) req = req.or(`full_name.ilike.%${q}%,email.ilike.%${q}%,phone.ilike.%${q}%`);
    const { data, error } = await req;
    setError(error?.message ?? null);
    setRows((data as Person[]) ?? []);
  }, [filter, query]);

  useEffect(() => { const t = setTimeout(load, 250); return () => clearTimeout(t); }, [load]);

  return (
    <>
      <PageHeader title="Passengers" subtitle="Everyone using the passenger app."
        actions={<SearchInput value={query} onChange={setQuery} placeholder="Search name, email, phone…" />} />
      <div className="mb-4"><Tabs value={filter} onChange={setFilter}
        options={[{ value: "active", label: "Active" }, { value: "suspended", label: "Suspended" }]} /></div>
      {error && <ErrorNote message={error} />}
      <div className="card overflow-x-auto">
        {!rows ? <TableSkeleton /> : rows.length === 0 ? <Empty title="No passengers found" /> : (
          <table className="w-full min-w-[720px]">
            <thead className="border-b border-white/5"><tr>
              <th className={th}>Passenger</th><th className={th}>Phone</th><th className={th}>Rating</th>
              <th className={th}>Joined</th><th className={th}>Status</th><th className={th} />
            </tr></thead>
            <tbody className="divide-y divide-white/5">
              {rows.map((p) => (
                <tr key={p.id} className="hover:bg-white/[0.02]">
                  <td className={td}><div className="flex items-center gap-3">
                    <div className="grid h-9 w-9 place-items-center rounded-full bg-white/10 text-xs font-semibold">{initials(p.full_name)}</div>
                    <div><p className="font-medium">{p.full_name || "Unnamed"}</p><p className="muted text-xs">{p.email ?? "—"}</p></div>
                  </div></td>
                  <td className={td}>{p.phone ?? "—"} {p.phone_verified && <span className="text-xs text-success">✓</span>}</td>
                  <td className={td}>{Number(p.rating_avg).toFixed(2)} ({p.rating_count})</td>
                  <td className={td}>{shortDate(p.created_at)}</td>
                  <td className={td}><StatusBadge status={p.status} /></td>
                  <td className={td}><Button variant="ghost" onClick={() => setOpen(p)}>Open</Button></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      {open && <PassengerDrawer person={open} canManage={can.manageUsers(staff.role)} staffId={staff.id}
        onClose={() => setOpen(null)} onChanged={() => { setOpen(null); load(); }} />}
    </>
  );
}

function PassengerDrawer({ person, canManage, staffId, onClose, onChanged }: {
  person: Person; canManage: boolean; staffId: string; onClose: () => void; onChanged: () => void;
}) {
  const [rides, setRides] = useState<{ id: string; status: string; dropoff_address: string; final_fare_kobo: number | null; estimated_fare_kobo: number; requested_at: string }[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    createClient().from("rides").select("id, status, dropoff_address, final_fare_kobo, estimated_fare_kobo, requested_at")
      .eq("passenger_id", person.id).order("requested_at", { ascending: false }).limit(20)
      .then(({ data }) => setRides(data ?? []));
  }, [person.id]);

  async function setStatus(status: "active" | "suspended") {
    setBusy(true);
    const supabase = createClient();
    const { error } = await supabase.from("profiles").update({ status }).eq("id", person.id);
    if (error) { setError(error.message); setBusy(false); return; }
    await logAudit(supabase, staffId, `user.${status === "active" ? "reactivated" : "suspended"}`, "profiles", person.id);
    onChanged();
  }

  return (
    <Drawer open title={person.full_name || "Passenger"} onClose={onClose}>
      <div className="space-y-5 text-sm">
        <div className="grid grid-cols-2 gap-3">
          <Field label="Email" value={person.email ?? "—"} />
          <Field label="Phone" value={`${person.phone ?? "—"}${person.phone_verified ? " (verified)" : ""}`} />
          <Field label="Joined" value={dateTime(person.created_at)} />
          <Field label="Rating" value={`${Number(person.rating_avg).toFixed(2)} from ${person.rating_count}`} />
        </div>
        <section>
          <h3 className="mb-2 font-semibold">Recent rides</h3>
          {!rides ? <TableSkeleton rows={3} /> : rides.length === 0 ? <p className="muted">No rides yet.</p> : (
            <ul className="divide-y divide-white/5">
              {rides.map((r) => (
                <li key={r.id} className="flex items-center gap-3 py-2.5">
                  <div className="min-w-0 flex-1"><p className="truncate">{r.dropoff_address}</p><p className="muted text-xs">{dateTime(r.requested_at)}</p></div>
                  <span>{naira(r.final_fare_kobo ?? r.estimated_fare_kobo)}</span>
                  <StatusBadge status={r.status} />
                </li>
              ))}
            </ul>
          )}
        </section>
        {error && <ErrorNote message={error} />}
        {canManage && (
          person.status === "active"
            ? <Button variant="danger" disabled={busy} onClick={() => setStatus("suspended")}>Suspend account</Button>
            : <Button variant="success" disabled={busy} onClick={() => setStatus("active")}>Reactivate account</Button>
        )}
      </div>
    </Drawer>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return <div className="rounded-xl bg-white/[0.03] p-3"><p className="muted text-xs">{label}</p><p className="mt-0.5 break-words">{value}</p></div>;
}
