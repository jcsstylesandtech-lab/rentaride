"use client";

import { useCallback, useEffect, useState } from "react";
import { MapPin, Siren } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { logAudit } from "@/lib/audit";
import { can } from "@/lib/roles";
import { dateTime, timeAgo } from "@/lib/format";
import { mapsLink, parsePoint } from "@/lib/geo";
import { useStaff } from "@/components/staff-context";
import { Button, Empty, ErrorNote, PageHeader, StatusBadge, TableSkeleton, Tabs } from "@/components/ui";

type Alert = {
  id: string; status: string; note: string | null; location: string | null; created_at: string; resolved_at: string | null;
  ride_id: string | null; user: { full_name: string; phone: string | null; role: string } | null;
  ride: { pickup_address: string; dropoff_address: string; status: string } | null;
};
type Filter = "open" | "resolved";

export default function SafetyPage() {
  const staff = useStaff();
  const [filter, setFilter] = useState<Filter>("open");
  const [rows, setRows] = useState<Alert[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(async () => {
    let req = createClient().from("sos_alerts")
      .select("*, user:profiles!sos_alerts_user_id_fkey(full_name, phone, role), ride:rides(pickup_address, dropoff_address, status)")
      .order("created_at", { ascending: false }).limit(100);
    req = filter === "open" ? req.neq("status", "resolved") : req.eq("status", "resolved");
    const { data, error } = await req;
    setError(error?.message ?? null);
    setRows((data as unknown as Alert[]) ?? []);
  }, [filter]);

  useEffect(() => { setRows(null); load(); }, [load]);
  useEffect(() => {
    const supabase = createClient();
    const ch = supabase.channel("sos-page").on("postgres_changes", { event: "*", schema: "public", table: "sos_alerts" }, load).subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [load]);

  async function update(a: Alert, status: "acknowledged" | "resolved") {
    setBusy(a.id);
    const supabase = createClient();
    const { error } = await supabase.from("sos_alerts").update({
      status, handled_by: staff.id, ...(status === "resolved" ? { resolved_at: new Date().toISOString() } : {}),
    }).eq("id", a.id);
    if (error) setError(error.message);
    else { await logAudit(supabase, staff.id, `sos.${status}`, "sos_alerts", a.id); load(); }
    setBusy(null);
  }

  const allowed = can.handleSos(staff.role);

  return (
    <>
      <PageHeader title="Safety & SOS" subtitle="Emergency alerts from passengers and drivers arrive here instantly." />
      <div className="mb-4"><Tabs value={filter} onChange={setFilter} options={[{ value: "open", label: "Open" }, { value: "resolved", label: "Resolved" }]} /></div>
      {error && <ErrorNote message={error} />}
      {!rows ? <div className="card"><TableSkeleton rows={4} /></div> : rows.length === 0 ? (
        <div className="card"><Empty title={filter === "open" ? "No open alerts" : "No resolved alerts yet"} hint="SOS presses from the apps appear here in real time." /></div>
      ) : (
        <div className="grid gap-4 lg:grid-cols-2">
          {rows.map((a) => {
            const point = parsePoint(a.location);
            return (
              <div key={a.id} className={`card p-5 ${a.status === "open" ? "border-danger/40 shadow-lg shadow-danger/10" : ""}`}>
                <div className="flex items-start gap-3">
                  <div className="grid h-10 w-10 place-items-center rounded-xl bg-danger/15 text-danger"><Siren size={18} /></div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="font-semibold">{a.user?.full_name || "Unknown user"}</p>
                      <span className="muted text-xs">({a.user?.role})</span>
                      <StatusBadge status={a.status} />
                    </div>
                    <p className="muted text-xs">{dateTime(a.created_at)} · {timeAgo(a.created_at)}</p>
                    {a.user?.phone && <p className="mt-1 text-sm">Call: <a className="text-cyan" href={`tel:${a.user.phone}`}>{a.user.phone}</a></p>}
                    {a.note && <p className="mt-2 text-sm">“{a.note}”</p>}
                    {a.ride && <p className="muted mt-2 text-xs">Trip: {a.ride.pickup_address} → {a.ride.dropoff_address} ({a.ride.status})</p>}
                    {point && (
                      <a href={mapsLink(point)} target="_blank" rel="noopener noreferrer"
                        className="mt-2 inline-flex items-center gap-1 text-sm text-cyan hover:underline">
                        <MapPin size={14} /> Open location in Google Maps
                      </a>
                    )}
                  </div>
                </div>
                {allowed && a.status !== "resolved" && (
                  <div className="mt-4 flex gap-2">
                    {a.status === "open" && <Button variant="ghost" disabled={busy === a.id} onClick={() => update(a, "acknowledged")}>Acknowledge</Button>}
                    <Button variant="success" disabled={busy === a.id} onClick={() => update(a, "resolved")}>Mark resolved</Button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </>
  );
}
