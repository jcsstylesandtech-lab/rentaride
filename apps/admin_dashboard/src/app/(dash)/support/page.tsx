"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Send } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { dateTime, initials, titleCase } from "@/lib/format";
import { useStaff } from "@/components/staff-context";
import { Badge, Empty, ErrorNote, PageHeader, Skeleton, Tabs } from "@/components/ui";

type Conversation = { id: string; kind: string; created_at: string; user: { full_name: string; phone: string | null } | null };
type Message = { id: string; sender_id: string; body: string; created_at: string; read_at: string | null };
type Kind = "support" | "safety";

export default function SupportPage() {
  const staff = useStaff();
  const [kind, setKind] = useState<Kind>("support");
  const [list, setList] = useState<Conversation[] | null>(null);
  const [active, setActive] = useState<Conversation | null>(null);

  useEffect(() => {
    setList(null); setActive(null);
    createClient().from("conversations").select("id, kind, created_at, user:profiles!conversations_user_id_fkey(full_name, phone)")
      .eq("kind", kind).order("created_at", { ascending: false }).limit(200)
      .then(({ data }) => setList((data as unknown as Conversation[]) ?? []));
  }, [kind]);

  return (
    <>
      <PageHeader title="Support chats" subtitle="Reply to passengers and drivers. Your replies appear in their Messages tab." />
      <div className="mb-4"><Tabs value={kind} onChange={setKind} options={[{ value: "support", label: "Support" }, { value: "safety", label: "Safety team" }]} /></div>
      <div className="grid h-[calc(100vh-16rem)] min-h-[480px] gap-4 lg:grid-cols-[320px_1fr]">
        <div className="card overflow-y-auto p-2">
          {!list ? <div className="space-y-2 p-2">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-14" />)}</div>
            : list.length === 0 ? <Empty title="No conversations yet" hint="Chats start when someone messages from the app." />
            : list.map((c) => (
              <button key={c.id} onClick={() => setActive(c)}
                className={`flex w-full items-center gap-3 rounded-xl p-3 text-left ${active?.id === c.id ? "bg-royal/30" : "hover:bg-white/5"}`}>
                <div className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-white/10 text-xs font-semibold">{initials(c.user?.full_name)}</div>
                <div className="min-w-0"><p className="truncate text-sm font-medium">{c.user?.full_name || "Unnamed"}</p>
                  <p className="muted truncate text-xs">{c.user?.phone ?? "No phone"}</p></div>
              </button>
            ))}
        </div>
        <div className="card flex min-h-0 flex-col">
          {active ? <Thread key={active.id} conversation={active} staffId={staff.id} /> : (
            <div className="grid flex-1 place-items-center"><Empty title="Pick a conversation" /></div>
          )}
        </div>
      </div>
    </>
  );
}

function Thread({ conversation, staffId }: { conversation: Conversation; staffId: string }) {
  const [messages, setMessages] = useState<Message[] | null>(null);
  const [text, setText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const bottom = useRef<HTMLDivElement>(null);

  const load = useCallback(async () => {
    const supabase = createClient();
    const { data } = await supabase.from("messages").select("id, sender_id, body, created_at, read_at")
      .eq("conversation_id", conversation.id).order("created_at").limit(500);
    setMessages(data ?? []);
    await supabase.rpc("mark_conversation_read", { p_conversation: conversation.id });
  }, [conversation.id]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { bottom.current?.scrollIntoView({ behavior: "smooth" }); }, [messages]);
  useEffect(() => {
    const supabase = createClient();
    const ch = supabase.channel(`thread-${conversation.id}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `conversation_id=eq.${conversation.id}` }, load)
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [conversation.id, load]);

  async function send(e: React.FormEvent) {
    e.preventDefault();
    const body = text.trim();
    if (!body) return;
    setText("");
    const { error } = await createClient().from("messages").insert({ conversation_id: conversation.id, sender_id: staffId, body });
    if (error) { setError(error.message); setText(body); } else load();
  }

  return (
    <>
      <div className="flex items-center justify-between border-b border-white/10 p-4">
        <div><p className="font-semibold">{conversation.user?.full_name || "Unnamed"}</p>
          <p className="muted text-xs">Started {dateTime(conversation.created_at)}</p></div>
        <Badge tone={conversation.kind === "safety" ? "bad" : "info"}>{titleCase(conversation.kind)}</Badge>
      </div>
      <div className="min-h-0 flex-1 space-y-2 overflow-y-auto p-4">
        {!messages ? <Skeleton className="h-20" /> : messages.length === 0 ? <p className="muted text-center text-sm">No messages yet.</p>
          : messages.map((m) => {
            const fromUser = m.sender_id !== staffId;
            return (
              <div key={m.id} className={`flex ${fromUser ? "justify-start" : "justify-end"}`}>
                <div className={`max-w-[75%] rounded-2xl px-4 py-2.5 text-sm ${fromUser ? "rounded-bl-md bg-white/8" : "rounded-br-md bg-royal"}`}>
                  <p className="whitespace-pre-wrap">{m.body}</p>
                  <p className="mt-1 text-right text-[10px] text-white/50">{dateTime(m.created_at)}</p>
                </div>
              </div>
            );
          })}
        <div ref={bottom} />
      </div>
      {error && <div className="px-4"><ErrorNote message={error} /></div>}
      <form onSubmit={send} className="flex gap-2 border-t border-white/10 p-3">
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder="Write a reply…" maxLength={2000}
          className="pill flex-1 bg-white/5 px-4 py-2.5 text-sm outline-none focus:border-cyan/60" />
        <button disabled={!text.trim()} aria-label="Send"
          className="grid h-11 w-11 place-items-center rounded-full bg-gradient-to-r from-royal to-cyan disabled:opacity-40"><Send size={16} /></button>
      </form>
    </>
  );
}
