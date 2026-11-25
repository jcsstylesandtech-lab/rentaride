"use client";

import { useCallback, useEffect, useState } from "react";
import { BellRing } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { can } from "@/lib/roles";
import { dateTime } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { Badge, Button, Empty, ErrorNote, PageHeader, TableSkeleton, td, th } from "@/components/ui";

type Audience = "everyone" | "passengers" | "drivers" | "ride_drivers" | "dispatch_riders" | "delivery_drivers" | "one_person";
type Broadcast = { id: string; title: string; body: string; audience: Audience; recipients: number; created_at: string;
  author: { full_name: string } | null };

const AUDIENCES: { value: Audience; label: string }[] = [
  { value: "everyone", label: "Everyone (passengers and drivers)" },
  { value: "passengers", label: "All passengers" },
  { value: "drivers", label: "All drivers and riders" },
  { value: "ride_drivers", label: "Ride drivers" },
  { value: "dispatch_riders", label: "Dispatch riders" },
  { value: "delivery_drivers", label: "Delivery drivers" },
  { value: "one_person", label: "One person (by email)" },
];
const AUDIENCE_LABEL = Object.fromEntries(AUDIENCES.map((a) => [a.value, a.label])) as Record<Audience, string>;

export default function NotificationsPage() {
  const staff = useStaff();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState<Audience>("passengers");
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [history, setHistory] = useState<Broadcast[] | null>(null);

  const load = useCallback(async () => {
    const { data, error } = await createClient().from("broadcasts")
      .select("id, title, body, audience, recipients, created_at, author:profiles!broadcasts_created_by_fkey(full_name)")
      .order("created_at", { ascending: false }).limit(50);
    if (error) setError(error.message);
    setHistory((data as unknown as Broadcast[]) ?? []);
  }, []);
  useEffect(() => { load(); }, [load]);

  if (!can.sendNotifications(staff.role)) {
    return <div className="card"><Empty title="Operations, support and super admins only" /></div>;
  }

  async function send(e: React.FormEvent) {
    e.preventDefault();
    setError(null); setNotice(null);
    const supabase = createClient();
    let target: string | null = null;
    if (audience === "one_person") {
      const { data: person } = await supabase.from("profiles").select("id, full_name").ilike("email", email.trim()).maybeSingle();
      if (!person) { setError("No account with that email."); return; }
      target = person.id;
    } else if (!window.confirm(`Send “${title.trim()}” to ${AUDIENCE_LABEL[audience].toLowerCase()}?`)) {
      return;
    }
    setBusy(true);
    const { data, error } = await supabase.rpc("send_broadcast", {
      p_title: title.trim(), p_body: body.trim(), p_audience: audience, p_user: target,
    });
    setBusy(false);
    if (error) { setError(error.message); return; }
    const n = (data as { recipients: number }).recipients;
    setNotice(n === 0 ? "Sent, but nobody matched that audience yet." : `Sent to ${n} ${n === 1 ? "person" : "people"}.`);
    setTitle(""); setBody(""); setEmail("");
    load();
  }

  const input = "w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2.5 text-sm outline-none focus:border-cyan/60";
  return (
    <>
      <PageHeader title="Notifications" subtitle="Send a message to passengers, drivers or one person. It appears in their app straight away and stays in their notifications list." />
      <form onSubmit={send} className="card mb-5 grid gap-3 p-5 md:grid-cols-2">
        <label className="text-sm">
          <span className="muted mb-1 block text-xs">Title</span>
          <input required maxLength={120} value={title} onChange={(e) => setTitle(e.target.value)}
            placeholder="e.g. Rain in Abuja — allow extra time" className={input} />
        </label>
        <label className="text-sm">
          <span className="muted mb-1 block text-xs">Send to</span>
          <select value={audience} onChange={(e) => setAudience(e.target.value as Audience)} className={`${input} bg-ink`}>
            {AUDIENCES.map((a) => <option key={a.value} value={a.value}>{a.label}</option>)}
          </select>
        </label>
        <label className="text-sm md:col-span-2">
          <span className="muted mb-1 block text-xs">Message</span>
          <textarea rows={3} maxLength={500} value={body} onChange={(e) => setBody(e.target.value)} className={input}
            placeholder="What should they know or do?" />
        </label>
        {audience === "one_person" && (
          <label className="text-sm md:col-span-2">
            <span className="muted mb-1 block text-xs">Their account email</span>
            <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} className={input} />
          </label>
        )}
        <div className="flex items-center gap-3 md:col-span-2">
          <Button disabled={busy || !title.trim()}><span className="inline-flex items-center gap-2"><BellRing size={15} />{busy ? "Sending…" : "Send notification"}</span></Button>
          <span className="muted text-xs">{body.length}/500</span>
        </div>
        {error && <div className="md:col-span-2"><ErrorNote message={error} /></div>}
        {notice && <p className="rounded-xl bg-success/10 px-4 py-3 text-sm text-success md:col-span-2">{notice}</p>}
      </form>

      <div className="card overflow-x-auto">
        {!history ? <TableSkeleton /> : history.length === 0 ? <Empty title="Nothing sent yet" /> : (
          <table className="w-full min-w-[720px]">
            <thead className="border-b border-white/5"><tr>
              <th className={th}>Message</th><th className={th}>Audience</th><th className={th}>Reached</th>
              <th className={th}>Sent by</th><th className={th}>When</th>
            </tr></thead>
            <tbody className="divide-y divide-white/5">
              {history.map((b) => (
                <tr key={b.id}>
                  <td className={td}><p className="font-medium">{b.title}</p>{b.body && <p className="muted line-clamp-2 text-xs">{b.body}</p>}</td>
                  <td className={td}><Badge>{AUDIENCE_LABEL[b.audience]}</Badge></td>
                  <td className={td}>{b.recipients}</td>
                  <td className={td}>{b.author?.full_name ?? "—"}</td>
                  <td className={td}>{dateTime(b.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
