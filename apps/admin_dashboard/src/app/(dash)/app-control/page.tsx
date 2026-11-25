"use client";

import { useCallback, useEffect, useState } from "react";
import { Construction, Megaphone } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { logAudit } from "@/lib/audit";
import { can } from "@/lib/roles";
import { dateTime } from "@/lib/format";
import { SERVICES } from "@/lib/services";
import { useStaff } from "@/components/staff-context";
import { Button, Empty, ErrorNote, PageHeader, TableSkeleton } from "@/components/ui";

type Settings = {
  rides_enabled: boolean; dispatch_enabled: boolean; delivery_enabled: boolean;
  passenger_maintenance: boolean; driver_maintenance: boolean; maintenance_message: string;
  passenger_announcement: string | null; driver_announcement: string | null; updated_at: string;
};
type Switch = "rides_enabled" | "dispatch_enabled" | "delivery_enabled" | "passenger_maintenance" | "driver_maintenance";

const SERVICE_SWITCH: Record<string, Switch> = { ride: "rides_enabled", dispatch: "dispatch_enabled", delivery: "delivery_enabled" };
const SERVICE_TITLE: Record<string, string> = { ride: "Rides", dispatch: "Dispatch", delivery: "Delivery" };

export default function AppControlPage() {
  const staff = useStaff();
  const allowed = can.controlApp(staff.role);
  const [s, setS] = useState<Settings | null>(null);
  const [draft, setDraft] = useState({ maintenance_message: "", passenger_announcement: "", driver_announcement: "" });
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const { data, error } = await createClient().from("app_settings").select("*").eq("id", 1).single();
    if (error) { setError(error.message); return; }
    setS(data as Settings);
    setDraft({
      maintenance_message: data.maintenance_message ?? "",
      passenger_announcement: data.passenger_announcement ?? "",
      driver_announcement: data.driver_announcement ?? "",
    });
  }, []);
  useEffect(() => { load(); }, [load]);

  async function save(patch: Partial<Settings>, label: string) {
    setBusy(true); setError(null); setSaved(null);
    const supabase = createClient();
    const { error } = await supabase.from("app_settings").update({ ...patch, updated_by: staff.id }).eq("id", 1);
    setBusy(false);
    if (error) { setError(error.message); return; }
    await logAudit(supabase, staff.id, "app_settings.changed", "app_settings", "1", patch);
    setSaved(label);
    load();
  }

  function toggle(key: Switch, label: string) {
    if (!s) return;
    const next = !s[key];
    const risky = key.endsWith("maintenance") ? next : !next;
    if (risky && !window.confirm(`${label}: turn ${next ? "on" : "off"}? Customers notice this immediately.`)) return;
    save({ [key]: next } as Partial<Settings>, `${label} ${next ? "on" : "off"}`);
  }

  if (!allowed) return <div className="card"><Empty title="Operations and super admins only" hint="Ask them to change app settings." /></div>;

  return (
    <>
      <PageHeader title="App control" subtitle="Switch services on or off, put an app into maintenance, and show announcements. Open apps update within seconds." />
      {error && <div className="mb-4"><ErrorNote message={error} /></div>}
      {saved && <div className="mb-4 rounded-xl bg-success/10 px-4 py-3 text-sm text-success">Saved: {saved}.</div>}
      {!s ? <div className="card"><TableSkeleton rows={4} /></div> : (
        <div className="grid gap-5 xl:grid-cols-2">
          <section className="card p-5">
            <h2 className="font-semibold">Services</h2>
            <p className="muted mb-4 text-xs">When a service is off, customers can&apos;t request it; trips already under way carry on.</p>
            <div className="space-y-2">
              {SERVICES.map((sv) => {
                const key = SERVICE_SWITCH[sv.value];
                const Icon = sv.icon;
                return (
                  <Row key={sv.value} icon={<Icon size={18} className="text-cyan" />} title={SERVICE_TITLE[sv.value]}
                    hint={sv.hint} on={s[key]} disabled={busy} onLabel="Taking requests" offLabel="Paused"
                    onToggle={() => toggle(key, SERVICE_TITLE[sv.value])} />
                );
              })}
            </div>
          </section>

          <section className="card p-5">
            <h2 className="flex items-center gap-2 font-semibold"><Construction size={17} className="text-warning" /> Maintenance</h2>
            <p className="muted mb-4 text-xs">Shows a full-screen message in that app instead of the usual screens. Use for outages or updates.</p>
            <div className="space-y-2">
              <Row title="Passenger app" hint="Riders and package senders" on={s.passenger_maintenance} danger disabled={busy}
                onLabel="In maintenance" offLabel="Running" onToggle={() => toggle("passenger_maintenance", "Passenger app maintenance")} />
              <Row title="Driver app" hint="Drivers, dispatch riders and delivery drivers" on={s.driver_maintenance} danger disabled={busy}
                onLabel="In maintenance" offLabel="Running" onToggle={() => toggle("driver_maintenance", "Driver app maintenance")} />
            </div>
            <label className="mt-4 block text-sm">
              <span className="muted mb-1 block text-xs">Message shown during maintenance</span>
              <textarea rows={2} maxLength={300} value={draft.maintenance_message}
                onChange={(e) => setDraft({ ...draft, maintenance_message: e.target.value })}
                className="w-full rounded-xl border border-white/10 bg-white/5 p-3 text-sm outline-none focus:border-cyan/60" />
            </label>
            <Button className="mt-2" variant="ghost"
              disabled={busy || !draft.maintenance_message.trim() || draft.maintenance_message === s.maintenance_message}
              onClick={() => save({ maintenance_message: draft.maintenance_message.trim() }, "maintenance message")}>Save message</Button>
          </section>

          <section className="card p-5 xl:col-span-2">
            <h2 className="flex items-center gap-2 font-semibold"><Megaphone size={17} className="text-cyan" /> Announcement banners</h2>
            <p className="muted mb-4 text-xs">A short line at the top of the app, e.g. “Fares are 10% off this weekend”. Leave it empty to hide it.</p>
            <div className="grid gap-4 md:grid-cols-2">
              {(["passenger_announcement", "driver_announcement"] as const).map((key) => (
                <div key={key}>
                  <label className="block text-sm">
                    <span className="muted mb-1 block text-xs">{key === "passenger_announcement" ? "Passenger app" : "Driver app"}</span>
                    <textarea rows={2} maxLength={300} value={draft[key]} placeholder="No banner"
                      onChange={(e) => setDraft({ ...draft, [key]: e.target.value })}
                      className="w-full rounded-xl border border-white/10 bg-white/5 p-3 text-sm outline-none focus:border-cyan/60" />
                  </label>
                  <div className="mt-2 flex gap-2">
                    <Button variant="ghost" disabled={busy || draft[key].trim() === (s[key] ?? "")}
                      onClick={() => save({ [key]: draft[key].trim() || null } as Partial<Settings>, "announcement")}>
                      {draft[key].trim() ? "Publish" : "Remove banner"}
                    </Button>
                    {s[key] && <span className="muted self-center text-xs">Live now</span>}
                  </div>
                </div>
              ))}
            </div>
          </section>
          <p className="muted text-xs xl:col-span-2">Last changed {dateTime(s.updated_at)}.</p>
        </div>
      )}
    </>
  );
}

function Row({ icon, title, hint, on, onToggle, disabled, danger, onLabel, offLabel }: {
  icon?: React.ReactNode; title: string; hint: string; on: boolean; onToggle: () => void; disabled?: boolean;
  danger?: boolean; onLabel: string; offLabel: string;
}) {
  const alarm = danger ? on : !on;
  return (
    <div className="flex items-center gap-3 rounded-xl border border-white/10 p-3">
      {icon}
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium">{title}</p>
        <p className="muted truncate text-xs">{hint}</p>
      </div>
      <span className={`text-xs ${alarm ? "text-warning" : "text-success"}`}>{on ? onLabel : offLabel}</span>
      <button role="switch" aria-checked={on} aria-label={title} disabled={disabled} onClick={onToggle}
        className={`relative h-6 w-11 shrink-0 rounded-full transition disabled:opacity-50 ${on ? (danger ? "bg-warning" : "bg-success") : "bg-white/15"}`}>
        <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${on ? "left-[22px]" : "left-0.5"}`} />
      </button>
    </div>
  );
}
