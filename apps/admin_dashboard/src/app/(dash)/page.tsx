"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { ArrowUpRight, Car, ShieldCheck, Siren, Users, Wifi } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { naira, timeAgo, titleCase } from "@/lib/format";
import { Skeleton, StatusBadge } from "@/components/ui";
import { Avatar } from "@/components/avatar";

type Range = "7d" | "30d" | "90d" | "1y";
const RANGE_DAYS: Record<Range, number> = { "7d": 7, "30d": 30, "90d": 90, "1y": 365 };

type Counts = { ridesToday: number; active: number; online: number; pending: number; sos: number; passengers: number };
type PendingDriver = { id: string; created_at: string; profiles: { full_name: string; avatar_url: string | null } | null };
type LiveRide = {
  id: string; status: string; pickup_address: string; dropoff_address: string;
  agreed_fare_kobo: number | null; estimated_fare_kobo: number; pricing_mode: string; vehicle_class: string;
};

export default function OverviewPage() {
  const [range, setRange] = useState<Range>("30d");
  const [counts, setCounts] = useState<Counts | null>(null);
  const [completed, setCompleted] = useState<{ completed_at: string; final_fare_kobo: number | null }[] | null>(null);
  const [pending, setPending] = useState<PendingDriver[] | null>(null);
  const [live, setLive] = useState<LiveRide[] | null>(null);

  useEffect(() => {
    const supabase = createClient();
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const head = { count: "exact" as const, head: true };
    const loadCounts = async () => {
      const [a, b, c, d, e, f] = await Promise.all([
        supabase.from("rides").select("id", head).gte("requested_at", today.toISOString()),
        supabase.from("rides").select("id", head).in("status", ["accepted", "driver_arrived", "in_progress"]),
        supabase.from("drivers").select("id", head).eq("is_online", true).eq("status", "approved"),
        supabase.from("drivers").select("id", head).eq("status", "pending"),
        supabase.from("sos_alerts").select("id", head).neq("status", "resolved"),
        supabase.from("profiles").select("id", head).eq("role", "passenger"),
      ]);
      setCounts({ ridesToday: a.count ?? 0, active: b.count ?? 0, online: c.count ?? 0,
        pending: d.count ?? 0, sos: e.count ?? 0, passengers: f.count ?? 0 });
    };
    const loadLists = async () => {
      const [p, l] = await Promise.all([
        supabase.from("drivers").select("id, created_at, profiles!drivers_id_fkey(full_name, avatar_url)")
          .eq("status", "pending").order("created_at").limit(4),
        supabase.from("rides").select("id, status, pickup_address, dropoff_address, agreed_fare_kobo, estimated_fare_kobo, pricing_mode, vehicle_class")
          .in("status", ["requested", "accepted", "driver_arrived", "in_progress"]).order("requested_at", { ascending: false }).limit(4),
      ]);
      setPending((p.data as unknown as PendingDriver[]) ?? []);
      setLive((l.data as LiveRide[]) ?? []);
    };
    loadCounts(); loadLists();
    const channel = supabase.channel("overview")
      .on("postgres_changes", { event: "*", schema: "public", table: "rides" }, () => { loadCounts(); loadLists(); })
      .on("postgres_changes", { event: "*", schema: "public", table: "drivers" }, () => { loadCounts(); loadLists(); })
      .on("postgres_changes", { event: "*", schema: "public", table: "sos_alerts" }, loadCounts)
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, []);

  useEffect(() => {
    setCompleted(null);
    const since = new Date(Date.now() - RANGE_DAYS[range] * 86400000).toISOString();
    createClient().from("rides").select("completed_at, final_fare_kobo")
      .eq("status", "completed").gte("completed_at", since).limit(10000)
      .then(({ data }) => setCompleted(data ?? []));
  }, [range]);

  // Completed fares per day (or per month for 1Y).
  const chart = useMemo(() => {
    if (!completed) return [];
    const monthly = range === "1y";
    const buckets = new Map<string, number>();
    const days = RANGE_DAYS[range];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(Date.now() - i * 86400000);
      const key = monthly ? d.toLocaleDateString("en-NG", { month: "short" }) : d.toLocaleDateString("en-NG", { day: "numeric", month: "short" });
      buckets.set(key, 0);
    }
    for (const r of completed) {
      const d = new Date(r.completed_at);
      const key = monthly ? d.toLocaleDateString("en-NG", { month: "short" }) : d.toLocaleDateString("en-NG", { day: "numeric", month: "short" });
      if (buckets.has(key)) buckets.set(key, (buckets.get(key) ?? 0) + (r.final_fare_kobo ?? 0) / 100);
    }
    return [...buckets].map(([label, value]) => ({ label, value }));
  }, [completed, range]);

  const total = completed?.reduce((s, r) => s + (r.final_fare_kobo ?? 0), 0) ?? 0;

  return (
    <div className="space-y-5">
      {/* Stat strip */}
      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
        <Stat icon={Car} label="Rides today" value={counts?.ridesToday} />
        <Stat icon={Car} label="Active trips" value={counts?.active} tone="text-cyan" />
        <Stat icon={Wifi} label="Drivers online" value={counts?.online} tone="text-success" />
        <Stat icon={ShieldCheck} label="Awaiting verification" value={counts?.pending} tone="text-warning" href="/drivers" />
        <Stat icon={Siren} label="Open SOS" value={counts?.sos} tone="text-danger" href="/safety" />
        <Stat icon={Users} label="Passengers" value={counts?.passengers} href="/passengers" />
      </div>

      <div className="grid gap-5 xl:grid-cols-3">
        {/* Left column: totals + insight */}
        <div className="space-y-5">
          <div className="card relative overflow-hidden p-6">
            <div className="absolute -right-10 -top-10 h-40 w-40 rounded-full bg-royal/30 blur-3xl" />
            <div className="relative flex items-center justify-between">
              <p className="text-sm text-white/75">Completed fares</p>
              <RangePicker value={range} onChange={setRange} />
            </div>
            <p className="relative mt-5 text-4xl font-semibold tracking-tight">
              {completed ? naira(total, 2) : <Skeleton className="h-10 w-48" />}
            </p>
            <p className="muted relative mt-1 text-xs">{completed?.length ?? 0} completed trips in this period</p>
          </div>
          <div className="card relative overflow-hidden p-6 text-center">
            <div className="absolute inset-x-0 -bottom-24 mx-auto h-48 w-72 rounded-full bg-cyan/25 blur-3xl" />
            <p className="relative font-semibold">Keep every driver verified</p>
            <p className="muted relative mx-auto mt-2 max-w-xs text-xs">
              Review licences, ID and vehicle papers before a driver can accept rides. Riders only ever see verified drivers.
            </p>
            <Link href="/drivers"
              className="relative mt-5 inline-block rounded-full bg-gradient-to-r from-royal to-cyan px-5 py-2 text-sm font-medium shadow-lg shadow-royal/30">
              Open verification queue
            </Link>
          </div>
        </div>

        {/* Verification queue (like Watchlist) */}
        <div className="card p-5">
          <div className="mb-4 flex items-center justify-between">
            <p className="font-semibold">Verification queue</p>
            <Link href="/drivers" className="pill px-3 py-1 text-xs hover:bg-white/5">See all</Link>
          </div>
          {!pending ? <ListSkeleton /> : pending.length === 0 ? (
            <p className="muted py-10 text-center text-sm">No drivers waiting. 🎉</p>
          ) : (
            <ul className="divide-y divide-white/5">
              {pending.map((d) => (
                <li key={d.id}>
                  <Link href={`/drivers?open=${d.id}`} className="flex items-center gap-3 py-3 hover:opacity-80">
                    <Avatar name={d.profiles?.full_name} url={d.profiles?.avatar_url} />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">{d.profiles?.full_name || "Unnamed driver"}</p>
                      <p className="muted text-xs">Applied {timeAgo(d.created_at)}</p>
                    </div>
                    <StatusBadge status="pending" />
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Live trips (like My Portfolio) */}
        <div className="card p-5">
          <div className="mb-4 flex items-center justify-between">
            <p className="font-semibold">Live trips</p>
            <Link href="/rides" aria-label="All rides" className="pill grid h-8 w-8 place-items-center hover:bg-white/5">
              <ArrowUpRight size={15} />
            </Link>
          </div>
          {!live ? <ListSkeleton /> : live.length === 0 ? (
            <p className="muted py-10 text-center text-sm">No trips in progress right now.</p>
          ) : (
            <div className="grid grid-cols-2 gap-3">
              {live.map((r) => (
                <div key={r.id} className="rounded-2xl border border-white/10 bg-white/[0.03] p-3.5">
                  <p className="text-lg font-semibold">{naira(r.agreed_fare_kobo ?? r.estimated_fare_kobo)}</p>
                  <p className="text-xs text-cyan">{titleCase(r.pricing_mode)} · {titleCase(r.vehicle_class)}</p>
                  <p className="muted mt-3 truncate text-[11px]">{r.pickup_address}</p>
                  <p className="truncate text-[11px]">→ {r.dropoff_address}</p>
                  <div className="mt-2"><StatusBadge status={r.status} /></div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Performance chart */}
      <div className="card p-5">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="font-semibold">Ride performance</p>
            <p className="muted text-xs">Completed fares (₦) over time</p>
          </div>
          <RangePicker value={range} onChange={setRange} />
        </div>
        <div className="h-72">
          {!completed ? <Skeleton className="h-full w-full" /> : (
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chart} margin={{ left: 0, right: 8, top: 10 }}>
                <defs>
                  <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#00C8FF" stopOpacity={0.45} />
                    <stop offset="100%" stopColor="#0866FF" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke="rgba(255,255,255,0.06)" vertical={false} />
                <XAxis dataKey="label" tick={{ fill: "rgba(255,255,255,0.45)", fontSize: 11 }} axisLine={false} tickLine={false} minTickGap={24} />
                <YAxis tick={{ fill: "rgba(255,255,255,0.45)", fontSize: 11 }} axisLine={false} tickLine={false} width={64}
                  tickFormatter={(v: number) => (v >= 1000 ? `₦${Math.round(v / 1000)}k` : `₦${v}`)} />
                <Tooltip
                  contentStyle={{ background: "#061B49", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 12, color: "#fff" }}
                  formatter={(v) => [`₦${Number(v ?? 0).toLocaleString("en-NG")}`, "Fares"]} />
                <Area type="monotone" dataKey="value" stroke="#00C8FF" strokeWidth={2.2} fill="url(#fill)"
                  activeDot={{ r: 6, fill: "#fff", stroke: "#0866FF", strokeWidth: 3 }} />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </div>
        {completed?.length === 0 && (
          <p className="muted -mt-40 mb-32 text-center text-sm">No completed trips in this period yet.</p>
        )}
      </div>
    </div>
  );
}

function Stat({ icon: Icon, label, value, tone = "text-white", href }: {
  icon: React.ElementType; label: string; value: number | undefined; tone?: string; href?: string;
}) {
  const body = (
    <div className="card h-full p-4 transition hover:border-white/20">
      <div className="flex items-center gap-2 text-xs text-white/55"><Icon size={14} />{label}</div>
      <p className={`mt-2 text-2xl font-semibold ${tone}`}>{value === undefined ? <Skeleton className="h-7 w-12" /> : value}</p>
    </div>
  );
  return href ? <Link href={href}>{body}</Link> : body;
}

function RangePicker({ value, onChange }: { value: Range; onChange: (r: Range) => void }) {
  return (
    <div className="flex gap-1.5">
      {(Object.keys(RANGE_DAYS) as Range[]).map((r) => (
        <button key={r} onClick={() => onChange(r)}
          className={`pill px-3 py-1 text-xs uppercase ${value === r ? "border-transparent bg-royal" : "text-white/60 hover:bg-white/5"}`}>
          {r}
        </button>
      ))}
    </div>
  );
}

function ListSkeleton() {
  return <div className="space-y-3">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-11 w-full" />)}</div>;
}
