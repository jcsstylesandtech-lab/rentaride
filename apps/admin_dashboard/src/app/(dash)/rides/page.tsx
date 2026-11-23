"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { logAudit } from "@/lib/audit";
import { can } from "@/lib/roles";
import { dateTime, naira, titleCase } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { Badge, Button, Drawer, Empty, ErrorNote, PageHeader, StatusBadge, TableSkeleton, Tabs, td, th } from "@/components/ui";

type Filter = "live" | "requested" | "completed" | "cancelled";
const STATUSES: Record<Filter, string[]> = {
  live: ["accepted", "driver_arrived", "in_progress"],
  requested: ["requested"],
  completed: ["completed"],
  cancelled: ["cancelled", "expired"],
};
type Ride = {
  id: string; status: string; pricing_mode: string; vehicle_class: string; pickup_address: string; dropoff_address: string;
  distance_m: number | null; estimated_fare_kobo: number; offered_fare_kobo: number | null; agreed_fare_kobo: number | null;
  final_fare_kobo: number | null; payment_method: string; requested_at: string; cancel_reason: string | null;
  passenger: { full_name: string } | null; driver: { full_name: string } | null;
};

export default function RidesPage() {
  const staff = useStaff();
  const [filter, setFilter] = useState<Filter>("live");
  const [rows, setRows] = useState<Ride[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState<Ride | null>(null);

  const load = useCallback(async () => {
    const { data, error } = await createClient().from("rides")
      .select("*, passenger:profiles!rides_passenger_id_fkey(full_name), driver:drivers!rides_driver_id_fkey(profiles!drivers_id_fkey(full_name))")
      .in("status", STATUSES[filter]).order("requested_at", { ascending: false }).limit(200);
    setError(error?.message ?? null);
    // Flatten driver → profile name.
    setRows(((data ?? []) as unknown as (Ride & { driver: { profiles: { full_name: string } } | null })[])
      .map((r) => ({ ...r, driver: r.driver?.profiles ?? null })));
  }, [filter]);

  useEffect(() => { setRows(null); load(); }, [load]);
  useEffect(() => {
    const supabase = createClient();
    const ch = supabase.channel("rides-page").on("postgres_changes", { event: "*", schema: "public", table: "rides" }, load).subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [load]);

  return (
    <>
      <PageHeader title="Rides" subtitle="Every trip across the platform, updating live." />
      <div className="mb-4"><Tabs value={filter} onChange={setFilter} options={[
        { value: "live", label: "In progress" }, { value: "requested", label: "Waiting for driver" },
        { value: "completed", label: "Completed" }, { value: "cancelled", label: "Cancelled" }]} /></div>
      {error && <ErrorNote message={error} />}
      <div className="card overflow-x-auto">
        {!rows ? <TableSkeleton /> : rows.length === 0 ? <Empty title="No rides here" /> : (
          <table className="w-full min-w-[900px]">
            <thead className="border-b border-white/5"><tr>
              <th className={th}>Requested</th><th className={th}>Route</th><th className={th}>Passenger</th>
              <th className={th}>Driver</th><th className={th}>Fare</th><th className={th}>Status</th><th className={th} />
            </tr></thead>
            <tbody className="divide-y divide-white/5">
              {rows.map((r) => (
                <tr key={r.id} className="hover:bg-white/[0.02]">
                  <td className={td}>{dateTime(r.requested_at)}</td>
                  <td className={`${td} max-w-64`}><p className="truncate">{r.pickup_address}</p><p className="muted truncate text-xs">→ {r.dropoff_address}</p></td>
                  <td className={td}>{r.passenger?.full_name || "—"}</td>
                  <td className={td}>{r.driver?.full_name || "—"}</td>
                  <td className={td}>
                    <p>{naira(r.final_fare_kobo ?? r.agreed_fare_kobo ?? r.estimated_fare_kobo)}</p>
                    <Badge tone={r.pricing_mode === "negotiable" ? "info" : "plain"}>{titleCase(r.pricing_mode)}</Badge>
                  </td>
                  <td className={td}><StatusBadge status={r.status} /></td>
                  <td className={td}><Button variant="ghost" onClick={() => setOpen(r)}>Details</Button></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      {open && <RideDrawer ride={open} canCancel={can.manageRides(staff.role)} staffId={staff.id}
        onClose={() => setOpen(null)} onChanged={() => { setOpen(null); load(); }} />}
    </>
  );
}

function RideDrawer({ ride, canCancel, staffId, onClose, onChanged }: {
  ride: Ride; canCancel: boolean; staffId: string; onClose: () => void; onChanged: () => void;
}) {
  const [events, setEvents] = useState<{ id: number; status: string; created_at: string }[] | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    createClient().from("ride_events").select("id, status, created_at").eq("ride_id", ride.id).order("created_at")
      .then(({ data }) => setEvents(data ?? []));
  }, [ride.id]);

  async function cancel() {
    setBusy(true);
    const supabase = createClient();
    const { error } = await supabase.from("rides").update({
      status: "cancelled", cancelled_by: staffId, cancelled_at: new Date().toISOString(), cancel_reason: `Staff: ${reason.trim()}`,
    }).eq("id", ride.id);
    if (error) { setError(error.message); setBusy(false); return; }
    await logAudit(supabase, staffId, "ride.cancelled", "rides", ride.id, { reason: reason.trim() });
    onChanged();
  }

  const active = ["requested", "accepted", "driver_arrived", "in_progress"].includes(ride.status);
  const row = (label: string, value: string) => (
    <div className="flex justify-between gap-4 py-2"><span className="muted">{label}</span><span className="text-right">{value}</span></div>
  );

  return (
    <Drawer open title="Ride details" onClose={onClose}>
      <div className="space-y-5 text-sm">
        <div className="divide-y divide-white/5">
          {row("Status", titleCase(ride.status))}
          {row("From", ride.pickup_address)}
          {row("To", ride.dropoff_address)}
          {row("Distance", ride.distance_m ? `${(ride.distance_m / 1000).toFixed(1)} km` : "—")}
          {row("Ride type", `${titleCase(ride.vehicle_class)} · ${titleCase(ride.pricing_mode)} fare`)}
          {row("Estimate", naira(ride.estimated_fare_kobo))}
          {ride.offered_fare_kobo && row("Passenger offered", naira(ride.offered_fare_kobo))}
          {row("Agreed fare", ride.agreed_fare_kobo ? naira(ride.agreed_fare_kobo) : "—")}
          {row("Final fare", ride.final_fare_kobo !== null ? naira(ride.final_fare_kobo) : "—")}
          {row("Payment", titleCase(ride.payment_method))}
          {row("Passenger", ride.passenger?.full_name || "—")}
          {row("Driver", ride.driver?.full_name || "Not assigned")}
          {ride.cancel_reason && row("Cancel reason", ride.cancel_reason)}
        </div>
        <section>
          <h3 className="mb-2 font-semibold">Timeline</h3>
          {!events ? <TableSkeleton rows={3} /> : (
            <ol className="space-y-2 border-l border-white/10 pl-4">
              {events.map((e) => (
                <li key={e.id}><span className="font-medium">{titleCase(e.status)}</span> <span className="muted text-xs">{dateTime(e.created_at)}</span></li>
              ))}
            </ol>
          )}
        </section>
        {error && <ErrorNote message={error} />}
        {canCancel && active && (
          <div className="space-y-2 border-t border-white/10 pt-4">
            <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Reason for cancelling"
              className="w-full rounded-xl border border-white/10 bg-white/5 p-3 outline-none focus:border-cyan/60" />
            <Button variant="danger" disabled={busy || !reason.trim()} onClick={cancel}>Cancel this ride</Button>
          </div>
        )}
      </div>
    </Drawer>
  );
}
