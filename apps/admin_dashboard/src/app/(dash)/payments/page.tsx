"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { can } from "@/lib/roles";
import { dateTime, naira, titleCase } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { Empty, ErrorNote, PageHeader, StatusBadge, TableSkeleton, Tabs, td, th } from "@/components/ui";
import { Withdrawals } from "./withdrawals";

type Payment = {
  id: string; provider: string; reference: string; amount_kobo: number; status: string; created_at: string;
  failure_reason: string | null; profiles: { full_name: string } | null;
};
type Filter = "all" | "succeeded" | "pending" | "failed" | "refunded";

export default function PaymentsPage() {
  const staff = useStaff();
  const [view, setView] = useState<"payments" | "withdrawals">("payments");
  const [filter, setFilter] = useState<Filter>("all");
  const [rows, setRows] = useState<Payment[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!can.seeMoney(staff.role)) return;
    setRows(null);
    let req = createClient().from("payments")
      .select("id, provider, reference, amount_kobo, status, created_at, failure_reason, profiles!payments_user_id_fkey(full_name)")
      .order("created_at", { ascending: false }).limit(300);
    if (filter !== "all") req = req.eq("status", filter);
    req.then(({ data, error }) => { setError(error?.message ?? null); setRows((data as unknown as Payment[]) ?? []); });
  }, [filter, staff.role]);

  if (!can.seeMoney(staff.role)) {
    return <div className="card"><Empty title="Finance only" hint="Payments are visible to Finance and Super admins." /></div>;
  }

  const sum = (s: string) => rows?.filter((p) => p.status === s).reduce((t, p) => t + p.amount_kobo, 0) ?? 0;

  return (
    <>
      <PageHeader title="Payments" subtitle="Wallet top-ups and trip payments verified with Paystack, and driver withdrawals." />
      <div className="mb-5"><Tabs value={view} onChange={setView}
        options={[{ value: "payments", label: "Payments" }, { value: "withdrawals", label: "Withdrawals" }]} /></div>
      {view === "withdrawals" ? <Withdrawals /> : <>
      <div className="mb-5 grid gap-4 sm:grid-cols-3">
        <Total label="Succeeded" value={naira(sum("succeeded"), 2)} tone="text-success" />
        <Total label="Pending" value={naira(sum("pending"), 2)} tone="text-warning" />
        <Total label="Refunded" value={naira(sum("refunded"), 2)} tone="text-white" />
      </div>
      <div className="mb-4"><Tabs value={filter} onChange={setFilter}
        options={(["all", "succeeded", "pending", "failed", "refunded"] as Filter[]).map((v) => ({ value: v, label: titleCase(v) }))} /></div>
      {error && <ErrorNote message={error} />}
      <div className="card overflow-x-auto">
        {!rows ? <TableSkeleton /> : rows.length === 0 ? (
          <Empty title="No payments yet" hint="Wallet top-ups and wallet-paid trips appear here." />
        ) : (
          <table className="w-full min-w-[760px]">
            <thead className="border-b border-white/5"><tr>
              <th className={th}>Date</th><th className={th}>Customer</th><th className={th}>Provider</th>
              <th className={th}>Reference</th><th className={th}>Amount</th><th className={th}>Status</th>
            </tr></thead>
            <tbody className="divide-y divide-white/5">
              {rows.map((p) => (
                <tr key={p.id}>
                  <td className={td}>{dateTime(p.created_at)}</td>
                  <td className={td}>{p.profiles?.full_name || "—"}</td>
                  <td className={td}>{titleCase(p.provider)}</td>
                  <td className={`${td} font-mono text-xs`}>{p.reference}</td>
                  <td className={td}>{naira(p.amount_kobo, 2)}</td>
                  <td className={td}><StatusBadge status={p.status} />{p.failure_reason && <p className="muted text-xs">{p.failure_reason}</p>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      </>}
    </>
  );
}

function Total({ label, value, tone }: { label: string; value: string; tone: string }) {
  return <div className="card p-5"><p className="muted text-sm">{label} (shown)</p><p className={`mt-2 text-2xl font-semibold ${tone}`}>{value}</p></div>;
}
