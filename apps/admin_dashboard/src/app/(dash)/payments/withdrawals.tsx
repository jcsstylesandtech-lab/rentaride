"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { dateTime, naira, titleCase } from "@/lib/format";
import { Button, Empty, ErrorNote, StatusBadge, TableSkeleton, Tabs, td, th } from "@/components/ui";

type Withdrawal = {
  id: string; amount_kobo: number; status: string; bank_name: string; account_number: string;
  account_name: string; reference: string; failure_reason: string | null; created_at: string;
  drivers: { profiles: { full_name: string; phone: string | null } | null } | null;
};
type Filter = "requested" | "processing" | "paid" | "failed" | "rejected" | "all";

/** Driver withdrawal requests: approve (sends a Paystack transfer) or reject (money back to the driver). */
export function Withdrawals() {
  const [filter, setFilter] = useState<Filter>("requested");
  const [rows, setRows] = useState<Withdrawal[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [rejecting, setRejecting] = useState<string | null>(null);
  const [reason, setReason] = useState("");

  const load = useCallback(() => {
    setRows(null);
    let req = createClient().from("withdrawals")
      .select("id, amount_kobo, status, bank_name, account_number, account_name, reference, failure_reason, created_at, drivers(profiles(full_name, phone))")
      .order("created_at", { ascending: filter === "requested" }).limit(300);
    if (filter !== "all") req = req.eq("status", filter);
    req.then(({ data, error }) => { setError(error?.message ?? null); setRows((data as unknown as Withdrawal[]) ?? []); });
  }, [filter]);

  useEffect(load, [load]);

  async function approve(w: Withdrawal) {
    if (!window.confirm(`Send ${naira(w.amount_kobo)} to ${w.account_name} (${w.bank_name} ${w.account_number})?`)) return;
    setBusy(w.id); setError(null); setNotice(null);
    const { data, error } = await createClient().functions.invoke("payments", {
      body: { action: "approve_withdrawal", withdrawal_id: w.id },
    });
    setBusy(null);
    if (error) {
      let message = error.message;
      try { message = (await (error as { context?: Response }).context?.json())?.error ?? message; } catch {}
      setError(message);
    } else {
      setNotice(data?.status === "paid"
        ? `Paid ${naira(w.amount_kobo)} to ${w.account_name}.`
        : `Transfer of ${naira(w.amount_kobo)} sent to Paystack. It shows as Paid when the bank confirms.`);
    }
    load();
  }

  async function reject(w: Withdrawal) {
    if (!reason.trim()) { setError("Give the driver a reason."); return; }
    setBusy(w.id); setError(null); setNotice(null);
    const { error } = await createClient().rpc("reject_withdrawal", { p_id: w.id, p_reason: reason.trim() });
    setBusy(null);
    if (error) { setError(error.message); return; }
    setNotice(`Rejected. ${naira(w.amount_kobo)} went back to the driver's wallet.`);
    setRejecting(null); setReason("");
    load();
  }

  const waiting = rows?.filter((w) => w.status === "requested") ?? [];

  return (
    <>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <Tabs value={filter} onChange={setFilter}
          options={(["requested", "processing", "paid", "failed", "rejected", "all"] as Filter[])
            .map((v) => ({ value: v, label: v === "requested" ? "Waiting" : titleCase(v) }))} />
        {filter === "requested" && rows && (
          <p className="muted text-sm">{waiting.length} waiting · {naira(waiting.reduce((t, w) => t + w.amount_kobo, 0))}</p>
        )}
      </div>
      {error && <ErrorNote message={error} />}
      {notice && <p className="mb-4 rounded-xl border border-success/40 bg-success/10 p-3 text-sm text-success" role="status">{notice}</p>}
      <div className="card overflow-x-auto">
        {!rows ? <TableSkeleton /> : rows.length === 0 ? (
          <Empty title={filter === "requested" ? "No withdrawals waiting" : "No withdrawals"}
            hint="Drivers request withdrawals from the Earnings tab once they've added a bank account." />
        ) : (
          <table className="w-full min-w-[860px]">
            <thead className="border-b border-white/5"><tr>
              <th className={th}>Requested</th><th className={th}>Driver</th><th className={th}>Pay to</th>
              <th className={th}>Amount</th><th className={th}>Status</th><th className={th}><span className="sr-only">Actions</span></th>
            </tr></thead>
            <tbody className="divide-y divide-white/5">
              {rows.map((w) => (
                <tr key={w.id} className="align-top">
                  <td className={td}>{dateTime(w.created_at)}</td>
                  <td className={td}>
                    {w.drivers?.profiles?.full_name || "—"}
                    {w.drivers?.profiles?.phone && <p className="muted text-xs">{w.drivers.profiles.phone}</p>}
                  </td>
                  <td className={td}>
                    {w.account_name}
                    <p className="muted text-xs">{w.bank_name} · {w.account_number}</p>
                  </td>
                  <td className={`${td} font-semibold tabular-nums`}>{naira(w.amount_kobo, 2)}</td>
                  <td className={td}>
                    <StatusBadge status={w.status} />
                    {w.failure_reason && <p className="muted mt-1 max-w-[220px] text-xs">{w.failure_reason}</p>}
                  </td>
                  <td className={`${td} w-[260px]`}>
                    {w.status === "requested" && (rejecting === w.id ? (
                      <div className="space-y-2">
                        <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={2} maxLength={200}
                          placeholder="Reason (shown to the driver)" aria-label="Reason for rejecting"
                          className="w-full rounded-xl border border-white/10 bg-white/5 p-3 text-sm outline-none focus:border-cyan/60" />
                        <div className="flex gap-2">
                          <Button variant="danger" disabled={busy === w.id} onClick={() => reject(w)}>Reject and refund</Button>
                          <Button variant="ghost" onClick={() => { setRejecting(null); setReason(""); }}>Cancel</Button>
                        </div>
                      </div>
                    ) : (
                      <div className="flex gap-2">
                        <Button variant="success" disabled={busy !== null} onClick={() => approve(w)}>
                          {busy === w.id ? "Sending…" : "Approve and pay"}
                        </Button>
                        <Button variant="ghost" disabled={busy !== null} onClick={() => { setRejecting(w.id); setReason(""); }}>Reject</Button>
                      </div>
                    ))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
