"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Send } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { useLiveChannel } from "@/lib/realtime";
import { dateTime, timeAgo, titleCase } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { Avatar } from "@/components/avatar";
import { Badge, Empty, ErrorNote, PageHeader, Skeleton, Tabs } from "@/components/ui";

type Kind = "support" | "safety";
type Thread = {
  id: string; kind: Kind; created_at: string; user_id: string; full_name: string | null; phone: string | null;
  avatar_url: string | null; role: string; last_body: string | null; last_at: string | null;
  last_from_user: boolean | null; unread: number;
};
type Message = {
  id: string; sender_id: string; body: string; created_at: string; read_at: string | null;
  state?: "sending" | "failed";
};

export default function SupportPage() {
  const [kind, setKind] = useState<Kind>("support");
  const [list, setList] = useState<Thread[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);

  const load = useCallback(async () => {
    const { data, error } = await createClient().rpc("support_inbox", { p_kind: kind });
    setError(error?.message ?? null);
    setList((data as Thread[]) ?? []);
  }, [kind]);

  useEffect(() => { setList(null); setActiveId(null); load(); }, [load]);
  // New threads and new messages re-order the inbox and update unread counts.
  useLiveChannel(`support-inbox-${kind}`, (ch) => ch
    .on("postgres_changes", { event: "*", schema: "public", table: "conversations" }, load)
    .on("postgres_changes", { event: "*", schema: "public", table: "messages" }, load), load);

  const active = list?.find((t) => t.id === activeId) ?? null;
  const totalUnread = list?.reduce((n, t) => n + t.unread, 0) ?? 0;

  return (
    <>
      <PageHeader title="Support chats"
        subtitle="Reply to riders and drivers. Messages arrive live and your replies appear instantly in their app." />
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <Tabs value={kind} onChange={setKind} options={[{ value: "support", label: "Support" }, { value: "safety", label: "Safety team" }]} />
        {totalUnread > 0 && <Badge tone="info">{totalUnread} unread</Badge>}
      </div>
      {error && <ErrorNote message={error} />}
      <div className="grid h-[calc(100vh-16rem)] min-h-[480px] gap-4 lg:grid-cols-[340px_1fr]">
        <div className="card overflow-y-auto p-2">
          {!list ? <div className="space-y-2 p-2">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-14" />)}</div>
            : list.length === 0 ? <Empty title="No conversations yet" hint="Chats start when a rider or driver messages from their app." />
            : list.map((t) => (
              <button key={t.id} onClick={() => setActiveId(t.id)}
                className={`flex w-full items-center gap-3 rounded-xl p-3 text-left ${activeId === t.id ? "bg-royal/30" : "hover:bg-white/5"}`}>
                <Avatar name={t.full_name} url={t.avatar_url} size="md" />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className={`truncate text-sm ${t.unread ? "font-semibold" : "font-medium"}`}>{t.full_name || "Unnamed"}</p>
                    <span className="shrink-0 text-[10px] uppercase tracking-wide text-cyan">{t.role === "driver" ? "Driver" : "Rider"}</span>
                  </div>
                  <p className={`truncate text-xs ${t.unread ? "text-white" : "muted"}`}>
                    {t.last_body ? `${t.last_from_user ? "" : "You: "}${t.last_body}` : "No messages yet"}
                  </p>
                </div>
                <div className="flex shrink-0 flex-col items-end gap-1">
                  {t.last_at && <span className="muted text-[10px]">{timeAgo(t.last_at)}</span>}
                  {t.unread > 0 && (
                    <span className="grid h-5 min-w-5 place-items-center rounded-full bg-royal px-1 text-[10px] font-semibold">{t.unread}</span>
                  )}
                </div>
              </button>
            ))}
        </div>
        <div className="card flex min-h-0 flex-col">
          {active ? <ThreadView key={active.id} thread={active} /> : (
            <div className="grid flex-1 place-items-center"><Empty title="Pick a conversation" /></div>
          )}
        </div>
      </div>
    </>
  );
}

function ThreadView({ thread }: { thread: Thread }) {
  const staff = useStaff();
  const [messages, setMessages] = useState<Message[] | null>(null);
  const [text, setText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [peerTyping, setPeerTyping] = useState(false);
  const bottom = useRef<HTMLDivElement>(null);
  const typingOff = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const lastTypingSent = useRef(0);

  const markRead = useCallback(() => {
    createClient().rpc("mark_conversation_read", { p_conversation: thread.id }).then(() => {});
  }, [thread.id]);

  const load = useCallback(async () => {
    const { data, error } = await createClient().from("messages").select("id, sender_id, body, created_at, read_at")
      .eq("conversation_id", thread.id).order("created_at").limit(500);
    if (error) { setError(error.message); return; }
    setMessages((prev) => [...(data ?? []), ...(prev ?? []).filter((m) => m.state)]);
    markRead();
  }, [thread.id, markRead]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { bottom.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, peerTyping]);
  useEffect(() => () => clearTimeout(typingOff.current), []);

  // New messages and read receipts for this thread.
  useLiveChannel(`thread-${thread.id}`, (ch) => ch.on("postgres_changes",
    { event: "*", schema: "public", table: "messages", filter: `conversation_id=eq.${thread.id}` },
    (payload) => {
      const row = payload.new as Message;
      if (!row?.id) return;
      setMessages((prev) => {
        const list = (prev ?? []).filter((m) => m.id !== row.id);
        return [...list, row].sort((a, b) => a.created_at.localeCompare(b.created_at));
      });
      if (row.sender_id === thread.user_id) { setPeerTyping(false); if (!row.read_at) markRead(); }
    }), load);

  // Typing indicator, both ways, on a private channel only this thread's people can join.
  const typingChannel = useLiveChannel(`chat:${thread.id}`, (ch) => ch.on("broadcast", { event: "typing" }, ({ payload }) => {
    if (payload?.user_id !== thread.user_id) return;
    setPeerTyping(true);
    clearTimeout(typingOff.current);
    typingOff.current = setTimeout(() => setPeerTyping(false), 4000);
  }), () => {}, { private: true });

  function onType(value: string) {
    setText(value);
    const now = Date.now();
    if (value.trim() && now - lastTypingSent.current > 2000) {
      lastTypingSent.current = now;
      typingChannel.current?.send({ type: "broadcast", event: "typing", payload: { user_id: staff.id } });
    }
  }

  async function deliver(temp: Message) {
    const { data, error } = await createClient().from("messages")
      .insert({ conversation_id: thread.id, sender_id: staff.id, body: temp.body })
      .select("id, sender_id, body, created_at, read_at").single();
    setMessages((prev) => {
      const rest = (prev ?? []).filter((m) => m.id !== temp.id && m.id !== data?.id);
      return error || !data ? [...rest, { ...temp, state: "failed" as const }] : [...rest, data as Message];
    });
    if (error) setError(`Not sent: ${error.message}`); else setError(null);
  }

  function send(e: React.FormEvent) {
    e.preventDefault();
    const body = text.trim();
    if (!body) return;
    setText("");
    const temp: Message = { id: `local-${Date.now()}`, sender_id: staff.id, body, created_at: new Date().toISOString(), read_at: null, state: "sending" };
    setMessages((prev) => [...(prev ?? []), temp]);
    deliver(temp);
  }

  function retry(m: Message) {
    setMessages((prev) => (prev ?? []).map((x) => (x.id === m.id ? { ...x, state: "sending" } : x)));
    deliver(m);
  }

  const name = thread.full_name || "Unnamed";
  return (
    <>
      <div className="flex items-center justify-between gap-3 border-b border-white/10 p-4">
        <div className="flex min-w-0 items-center gap-3">
          <Avatar name={thread.full_name} url={thread.avatar_url} size="md" />
          <div className="min-w-0"><p className="truncate font-semibold">{name}</p>
            <p className="muted truncate text-xs">{thread.role === "driver" ? "Driver" : "Rider"} · {thread.phone ?? "No phone"} · started {dateTime(thread.created_at)}</p></div>
        </div>
        <Badge tone={thread.kind === "safety" ? "bad" : "info"}>{titleCase(thread.kind)}</Badge>
      </div>
      <div className="min-h-0 flex-1 space-y-2 overflow-y-auto p-4" aria-live="polite">
        {!messages ? <Skeleton className="h-20" /> : messages.length === 0 ? <p className="muted text-center text-sm">No messages yet.</p>
          : messages.map((m) => {
            const fromUser = m.sender_id === thread.user_id;
            const meta = m.state === "sending" ? "Sending…" : m.state === "failed" ? "Not sent · click to retry"
              : `${dateTime(m.created_at)}${!fromUser && m.read_at ? " · Seen" : ""}`;
            const bubble = (
              <div className={`max-w-[75%] rounded-2xl px-4 py-2.5 text-left text-sm ${fromUser ? "rounded-bl-md bg-white/8"
                : m.state === "failed" ? "rounded-br-md bg-danger/80" : "rounded-br-md bg-royal"}`}>
                <p className="whitespace-pre-wrap">{m.body}</p>
                <p className="mt-1 text-right text-[10px] text-white/50">{meta}</p>
              </div>
            );
            return (
              <div key={m.id} className={`flex ${fromUser ? "justify-start" : "justify-end"}`}>
                {m.state === "failed" ? <button onClick={() => retry(m)} className="contents">{bubble}</button> : bubble}
              </div>
            );
          })}
        {peerTyping && (
          <div className="flex justify-start" role="status" aria-label={`${name} is typing`}>
            <div className="rounded-2xl rounded-bl-md bg-white/8 px-4 py-3">
              <span className="flex gap-1" aria-hidden>
                {[0, 150, 300].map((d) => (
                  <span key={d} className="h-2 w-2 animate-bounce rounded-full bg-white/60" style={{ animationDelay: `${d}ms` }} />
                ))}
              </span>
            </div>
            <span className="muted ml-2 self-end text-[11px]">{name.split(" ")[0]} is typing…</span>
          </div>
        )}
        <div ref={bottom} />
      </div>
      {error && <div className="px-4"><ErrorNote message={error} /></div>}
      <form onSubmit={send} className="flex gap-2 border-t border-white/10 p-3">
        <input value={text} onChange={(e) => onType(e.target.value)} placeholder="Write a reply…" maxLength={2000}
          aria-label="Reply" className="pill flex-1 bg-white/5 px-4 py-2.5 text-sm outline-none focus:border-cyan/60" />
        <button disabled={!text.trim()} aria-label="Send"
          className="grid h-11 w-11 place-items-center rounded-full bg-gradient-to-r from-royal to-cyan disabled:opacity-40"><Send size={16} /></button>
      </form>
    </>
  );
}
