"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { can } from "@/lib/roles";
import { dateTime } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { Empty, ErrorNote, PageHeader, TableSkeleton, td, th } from "@/components/ui";

type Entry = { id: number; action: string; target_table: string | null; target_id: string | null;
  details: Record<string, unknown>; created_at: string; actor: { full_name: string } | null };

export default function AuditPage() {
  const staff = useStaff();
  const [rows, setRows] = useState<Entry[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!can.seeAudit(staff.role)) return;
    createClient().from("audit_log").select("*, actor:profiles!audit_log_actor_id_fkey(full_name)")
      .order("created_at", { ascending: false }).limit(300)
      .then(({ data, error }) => { setError(error?.message ?? null); setRows((data as unknown as Entry[]) ?? []); });
  }, [staff.role]);

  if (!can.seeAudit(staff.role)) return <div className="card"><Empty title="Operations and Super admins only" /></div>;

  return (
    <>
      <PageHeader title="Audit log" subtitle="Every approval, suspension, cancellation and access change made by staff." />
      {error && <ErrorNote message={error} />}
      <div className="card overflow-x-auto">
        {!rows ? <TableSkeleton /> : rows.length === 0 ? <Empty title="Nothing recorded yet" /> : (
          <table className="w-full min-w-[720px]">
            <thead className="border-b border-white/5"><tr>
              <th className={th}>When</th><th className={th}>Who</th><th className={th}>Action</th><th className={th}>Target</th><th className={th}>Details</th>
            </tr></thead>
            <tbody className="divide-y divide-white/5">
              {rows.map((e) => (
                <tr key={e.id}>
                  <td className={td}>{dateTime(e.created_at)}</td>
                  <td className={td}>{e.actor?.full_name || "—"}</td>
                  <td className={`${td} font-medium text-cyan`}>{e.action}</td>
                  <td className={`${td} muted text-xs`}>{e.target_table} {e.target_id?.slice(0, 8)}</td>
                  <td className={`${td} muted font-mono text-xs`}>{Object.keys(e.details ?? {}).length ? JSON.stringify(e.details) : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
