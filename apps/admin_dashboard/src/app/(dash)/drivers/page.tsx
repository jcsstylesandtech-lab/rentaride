"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { FileText } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { logAudit } from "@/lib/audit";
import { can } from "@/lib/roles";
import { dateTime, initials, shortDate, titleCase } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { SERVICES, isService, serviceInfo, type ServiceType } from "@/lib/services";
import {
  Badge, Button, Drawer, Empty, ErrorNote, PageHeader, SearchInput, StatusBadge, TableSkeleton, Tabs, td, th,
} from "@/components/ui";

type Status = "pending" | "approved" | "rejected" | "suspended";
type DriverRow = {
  id: string; status: Status; service_type: ServiceType; licence_number: string | null; is_online: boolean;
  rejection_reason: string | null; created_at: string; approved_at: string | null;
  profiles: { full_name: string; email: string | null; phone: string | null; rating_avg: number; rating_count: number } | null;
};
type Vehicle = {
  id: string; class: string; make: string; model: string; colour: string; year: number | null;
  plate_number: string; seats: number; review: string; is_active: boolean;
};
type Doc = { id: string; type: string; storage_path: string; review: string; reviewer_note: string | null; expires_on: string | null; created_at: string };

const SELECT = "id, status, service_type, licence_number, is_online, rejection_reason, created_at, approved_at, profiles!drivers_id_fkey(full_name, email, phone, rating_avg, rating_count)";

export default function DriversPage() {
  return <Suspense><Drivers /></Suspense>;
}

function Drivers() {
  const staff = useStaff();
  const params = useSearchParams();
  const raw = params.get("service");
  const service: ServiceType | null = isService(raw) ? raw : null;
  const [tab, setTab] = useState<Status>("pending");
  const [query, setQuery] = useState("");
  const [rows, setRows] = useState<DriverRow[] | null>(null);
  const [counts, setCounts] = useState<Record<Status, number>>({ pending: 0, approved: 0, rejected: 0, suspended: 0 });
  const [error, setError] = useState<string | null>(null);
  const [openId, setOpenId] = useState<string | null>(params.get("open"));

  const load = useCallback(async () => {
    const supabase = createClient();
    let list = supabase.from("drivers").select(SELECT).eq("status", tab);
    if (service) list = list.eq("service_type", service);
    const { data, error } = await list.order("created_at", { ascending: tab === "pending" }).limit(200);
    if (error) setError(error.message);
    setRows((data as unknown as DriverRow[]) ?? []);
    const statuses: Status[] = ["pending", "approved", "rejected", "suspended"];
    const res = await Promise.all(statuses.map((s) => {
      const c = supabase.from("drivers").select("id", { count: "exact", head: true }).eq("status", s);
      return service ? c.eq("service_type", service) : c;
    }));
    setCounts(Object.fromEntries(statuses.map((s, i) => [s, res[i].count ?? 0])) as Record<Status, number>);
  }, [tab, service]);

  useEffect(() => { setRows(null); load(); }, [load]);
  useEffect(() => {
    const supabase = createClient();
    const ch = supabase.channel("drivers-page")
      .on("postgres_changes", { event: "*", schema: "public", table: "drivers" }, load)
      .on("postgres_changes", { event: "*", schema: "public", table: "driver_documents" }, load)
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [load]);

  const q = query.trim().toLowerCase();
  const shown = rows?.filter((r) => !q || [r.profiles?.full_name, r.profiles?.email, r.profiles?.phone, r.licence_number]
    .some((v) => v?.toLowerCase().includes(q)));

  return (
    <>
      <PageHeader title={service ? serviceInfo(service).label : "All drivers"}
        subtitle={`${service ? serviceInfo(service).hint + ". " : ""}${can.verifyDrivers(staff.role)
          ? "Review documents and vehicles, then approve or reject."
          : "View only — your role can't approve drivers."}`}
        actions={<SearchInput value={query} onChange={setQuery} placeholder="Search name, phone, licence…" />} />
      <div className="mb-4">
        <Tabs value={tab} onChange={setTab} options={(["pending", "approved", "rejected", "suspended"] as Status[])
          .map((s) => ({ value: s, label: titleCase(s), count: counts[s] }))} />
      </div>
      {error && <ErrorNote message={error} />}
      <div className="card overflow-x-auto">
        {!shown ? <TableSkeleton /> : shown.length === 0 ? (
          <Empty title={`No ${tab} ${service ? serviceInfo(service).label.toLowerCase() : "drivers"}`}
            hint={tab === "pending" ? "New sign-ups from the driver app appear here." : undefined} />
        ) : (
          <table className="w-full min-w-[760px]">
            <thead className="border-b border-white/5"><tr>
              <th className={th}>Driver</th><th className={th}>Service</th><th className={th}>Phone</th><th className={th}>Licence</th>
              <th className={th}>Rating</th><th className={th}>Applied</th><th className={th}>Status</th><th className={th} />
            </tr></thead>
            <tbody className="divide-y divide-white/5">
              {shown.map((d) => (
                <tr key={d.id} className="hover:bg-white/[0.02]">
                  <td className={td}>
                    <div className="flex items-center gap-3">
                      <div className="grid h-9 w-9 place-items-center rounded-full bg-white/10 text-xs font-semibold">{initials(d.profiles?.full_name)}</div>
                      <div><p className="font-medium">{d.profiles?.full_name || "Unnamed"}</p><p className="muted text-xs">{d.profiles?.email}</p></div>
                    </div>
                  </td>
                  <td className={td}><ServiceTag service={d.service_type} /></td>
                  <td className={td}>{d.profiles?.phone ?? "—"}</td>
                  <td className={td}>{d.licence_number ?? "—"}</td>
                  <td className={td}>{d.profiles ? `${Number(d.profiles.rating_avg).toFixed(2)} (${d.profiles.rating_count})` : "—"}</td>
                  <td className={td}>{shortDate(d.created_at)}</td>
                  <td className={td}>
                    <div className="flex items-center gap-2"><StatusBadge status={d.status} />{d.is_online && <Badge tone="info">Online</Badge>}</div>
                  </td>
                  <td className={td}><Button variant="ghost" onClick={() => setOpenId(d.id)}>Review</Button></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      {openId && <DriverDrawer id={openId} onClose={() => setOpenId(null)} onChanged={load} />}
    </>
  );
}

function DriverDrawer({ id, onClose, onChanged }: { id: string; onClose: () => void; onChanged: () => void }) {
  const staff = useStaff();
  const allowed = can.verifyDrivers(staff.role);
  const [driver, setDriver] = useState<DriverRow | null>(null);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [docs, setDocs] = useState<Doc[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reason, setReason] = useState("");

  const load = useCallback(async () => {
    const supabase = createClient();
    const [d, v, docsRes] = await Promise.all([
      supabase.from("drivers").select(SELECT).eq("id", id).single(),
      supabase.from("vehicles").select("*").eq("driver_id", id).order("created_at"),
      supabase.from("driver_documents").select("*").eq("driver_id", id).order("created_at"),
    ]);
    if (d.error) setError(d.error.message);
    setDriver(d.data as unknown as DriverRow);
    setVehicles((v.data as Vehicle[]) ?? []);
    setDocs((docsRes.data as Doc[]) ?? []);
  }, [id]);
  useEffect(() => { load(); }, [load]);

  async function run(action: string, table: string, targetId: string, fn: () => PromiseLike<{ error: { message: string } | null }>, details = {}) {
    setBusy(true); setError(null);
    const { error } = await fn();
    if (error) setError(error.message);
    else { await logAudit(createClient(), staff.id, action, table, targetId, details); await load(); onChanged(); }
    setBusy(false);
  }

  const supabase = createClient();
  const setDriverStatus = (status: Status, extra: Record<string, unknown> = {}) =>
    run(`driver.${status}`, "drivers", id, () => supabase.from("drivers").update({ status, ...extra }).eq("id", id), extra);
  const reviewDoc = (doc: Doc, review: "approved" | "rejected") =>
    run(`document.${review}`, "driver_documents", doc.id, () => supabase.from("driver_documents")
      .update({ review, reviewed_by: staff.id, reviewed_at: new Date().toISOString() }).eq("id", doc.id), { type: doc.type });
  const reviewVehicle = (v: Vehicle, review: "approved" | "rejected") =>
    run(`vehicle.${review}`, "vehicles", v.id, () => supabase.from("vehicles").update({ review }).eq("id", v.id), { plate: v.plate_number });

  async function openDoc(doc: Doc) {
    const { data, error } = await createClient().storage.from("driver-documents").createSignedUrl(doc.storage_path, 120);
    if (error || !data) { setError(error?.message ?? "Could not open the file"); return; }
    window.open(data.signedUrl, "_blank", "noopener,noreferrer");
  }

  const approvedVehicle = vehicles.some((v) => v.review === "approved" && v.is_active);
  const docsPending = docs.some((d) => d.review === "pending");
  const p = driver?.profiles;

  return (
    <Drawer open title="Driver review" onClose={onClose}>
      {!driver ? <TableSkeleton rows={4} /> : (
        <div className="space-y-6">
          <div className="flex items-center gap-4">
            <div className="grid h-14 w-14 place-items-center rounded-full bg-gradient-to-br from-royal to-cyan text-lg font-semibold">{initials(p?.full_name)}</div>
            <div className="min-w-0">
              <p className="text-lg font-semibold">{p?.full_name || "Unnamed driver"}</p>
              <p className="muted truncate text-sm">{p?.email ?? "No email"} · {p?.phone ?? "No phone"}</p>
              <div className="mt-1 flex gap-2"><StatusBadge status={driver.status} />{driver.is_online && <Badge tone="info">Online</Badge>}</div>
            </div>
          </div>

          <dl className="grid grid-cols-2 gap-3 text-sm">
            <div className="col-span-2 rounded-xl bg-white/[0.03] p-3">
              <dt className="muted text-xs">Service</dt>
              <dd className="mt-1.5 flex flex-wrap gap-2">
                {allowed ? SERVICES.map((sv) => {
                  const Icon = sv.icon;
                  const on = driver.service_type === sv.value;
                  return (
                    <button key={sv.value} disabled={busy || on} aria-pressed={on}
                      onClick={() => run("driver.service_changed", "drivers", id,
                        () => supabase.from("drivers").update({ service_type: sv.value }).eq("id", id),
                        { from: driver.service_type, to: sv.value })}
                      className={`pill flex items-center gap-1.5 px-3 py-1 text-xs ${on ? "border-transparent bg-royal text-white" : "text-white/70 hover:bg-white/5"}`}>
                      <Icon size={13} />{sv.short}
                    </button>
                  );
                }) : <ServiceTag service={driver.service_type} />}
              </dd>
            </div>
            <Info label="Licence number" value={driver.licence_number ?? "—"} />
            <Info label="Applied" value={dateTime(driver.created_at)} />
            <Info label="Approved" value={dateTime(driver.approved_at)} />
            <Info label="Rating" value={p ? `${Number(p.rating_avg).toFixed(2)} from ${p.rating_count}` : "—"} />
          </dl>
          {driver.rejection_reason && <ErrorNote message={`Reason given: ${driver.rejection_reason}`} />}

          <section>
            <h3 className="mb-2 font-semibold">Documents</h3>
            {docs.length === 0 ? <p className="muted text-sm">No documents uploaded yet.</p> : (
              <ul className="space-y-2">
                {docs.map((doc) => (
                  <li key={doc.id} className="flex items-center gap-3 rounded-xl border border-white/10 p-3">
                    <FileText size={18} className="text-cyan" />
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium">{titleCase(doc.type)}</p>
                      <p className="muted text-xs">Uploaded {shortDate(doc.created_at)}{doc.expires_on ? ` · expires ${shortDate(doc.expires_on)}` : ""}</p>
                    </div>
                    <StatusBadge status={doc.review} />
                    <Button variant="ghost" onClick={() => openDoc(doc)}>View</Button>
                    {allowed && doc.review !== "approved" && <Button variant="success" disabled={busy} onClick={() => reviewDoc(doc, "approved")}>✓</Button>}
                    {allowed && doc.review !== "rejected" && <Button variant="danger" disabled={busy} onClick={() => reviewDoc(doc, "rejected")}>✕</Button>}
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section>
            <h3 className="mb-2 font-semibold">Vehicles</h3>
            {vehicles.length === 0 ? <p className="muted text-sm">No vehicle added yet.</p> : (
              <ul className="space-y-2">
                {vehicles.map((v) => (
                  <li key={v.id} className="flex items-center gap-3 rounded-xl border border-white/10 p-3">
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium">{v.colour} {v.make} {v.model} {v.year ?? ""}</p>
                      <p className="muted text-xs">{v.plate_number} · {titleCase(v.class)} · {v.seats} seats</p>
                    </div>
                    <StatusBadge status={v.review} />
                    {allowed && v.review !== "approved" && <Button variant="success" disabled={busy} onClick={() => reviewVehicle(v, "approved")}>✓</Button>}
                    {allowed && v.review !== "rejected" && <Button variant="danger" disabled={busy} onClick={() => reviewVehicle(v, "rejected")}>✕</Button>}
                  </li>
                ))}
              </ul>
            )}
          </section>

          {error && <ErrorNote message={error} />}

          {allowed && (
            <section className="space-y-3 border-t border-white/10 pt-5">
              {driver.status !== "approved" && (
                <>
                  {(!approvedVehicle || docsPending) && (
                    <p className="text-xs text-warning">
                      {!approvedVehicle ? "Approve at least one vehicle first. " : ""}{docsPending ? "Some documents are still pending review." : ""}
                    </p>
                  )}
                  <Button disabled={busy || !approvedVehicle}
                    onClick={() => setDriverStatus("approved", { approved_at: new Date().toISOString(), rejection_reason: null })}>
                    {driver.status === "suspended" ? "Reinstate driver" : "Approve driver"}
                  </Button>
                </>
              )}
              <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={2} placeholder="Reason (shown to the driver)"
                className="w-full rounded-xl border border-white/10 bg-white/5 p-3 text-sm outline-none focus:border-cyan/60" />
              <div className="flex flex-wrap gap-2">
                {driver.status === "pending" && (
                  <Button variant="danger" disabled={busy || !reason.trim()}
                    onClick={() => setDriverStatus("rejected", { rejection_reason: reason.trim(), is_online: false })}>Reject application</Button>
                )}
                {driver.status === "approved" && (
                  <Button variant="danger" disabled={busy || !reason.trim()}
                    onClick={() => setDriverStatus("suspended", { rejection_reason: reason.trim(), is_online: false })}>Suspend driver</Button>
                )}
              </div>
            </section>
          )}
        </div>
      )}
    </Drawer>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-white/[0.03] p-3">
      <dt className="muted text-xs">{label}</dt>
      <dd className="mt-0.5">{value}</dd>
    </div>
  );
}

function ServiceTag({ service }: { service: ServiceType }) {
  const info = serviceInfo(service);
  const Icon = info.icon;
  return <span className="inline-flex items-center gap-1.5 text-sm"><Icon size={14} className="text-cyan" />{info.short}</span>;
}
