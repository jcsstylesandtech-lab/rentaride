"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { Bell, MessageSquare, Settings } from "lucide-react";
import { useStaff } from "./staff-context";
import { ROLE_LABEL } from "@/lib/roles";
import { Avatar } from "./avatar";
import { createClient } from "@/lib/supabase/client";
import { useLiveChannel, useLiveStatus } from "@/lib/realtime";

export function Topbar() {
  const staff = useStaff();
  const [openSos, setOpenSos] = useState(0);
  const [unread, setUnread] = useState(0);
  const status = useLiveStatus();
  const first = staff.name.split(" ")[0] || "there";

  // Live counts: open SOS alerts (bell) and unanswered support messages.
  const load = useCallback(() => {
    const supabase = createClient();
    supabase.from("sos_alerts").select("id", { count: "exact", head: true }).neq("status", "resolved")
      .then(({ count }) => setOpenSos(count ?? 0));
    supabase.rpc("unread_support_messages").then(({ data }) => setUnread(typeof data === "number" ? data : 0));
  }, []);
  useEffect(() => { load(); }, [load]);
  useLiveChannel("topbar", (ch) => ch
    .on("postgres_changes", { event: "*", schema: "public", table: "sos_alerts" }, load)
    .on("postgres_changes", { event: "*", schema: "public", table: "messages" }, load), load);

  return (
    <header className="mb-6 flex flex-wrap items-center justify-between gap-4">
      <div>
        <h1 className="text-2xl font-semibold">
          Welcome, <span className="bg-gradient-to-r from-royal to-cyan bg-clip-text text-transparent">{first}</span>
        </h1>
        <p className="muted text-sm">Oversight and control for the passenger and driver apps</p>
      </div>
      <div className="flex items-center gap-3">
        <span role="status" title={status === "live" ? "Connected: updates appear instantly" : "Reconnecting to live updates…"}
          className={`pill flex items-center gap-2 px-3 py-1.5 text-xs ${status === "live" ? "text-success" : "text-warning"}`}>
          <span className={`h-2 w-2 rounded-full ${status === "live" ? "bg-success" : "animate-pulse bg-warning"}`} aria-hidden />
          {status === "live" ? "Live" : status === "connecting" ? "Connecting…" : "Reconnecting…"}
        </span>
        <Link href="/support" aria-label={`${unread} unread support messages`}
          className="pill relative grid h-10 w-10 place-items-center bg-white/5 hover:bg-white/10">
          <MessageSquare size={17} />
          {unread > 0 && (
            <span className="absolute -right-1 -top-1 grid h-5 min-w-5 place-items-center rounded-full bg-royal px-1 text-[10px] font-semibold">
              {unread > 99 ? "99+" : unread}
            </span>
          )}
        </Link>
        <Link href="/safety" aria-label={`${openSos} open SOS alerts`}
          className="pill relative grid h-10 w-10 place-items-center bg-white/5 hover:bg-white/10">
          <Bell size={17} />
          {openSos > 0 && (
            <span className="absolute -right-1 -top-1 grid h-5 min-w-5 place-items-center rounded-full bg-danger px-1 text-[10px] font-semibold">
              {openSos}
            </span>
          )}
        </Link>
        <Link href="/settings" aria-label="Settings" className="pill grid h-10 w-10 place-items-center bg-white/5 hover:bg-white/10">
          <Settings size={17} />
        </Link>
        <div className="flex items-center gap-3 pl-1">
          <Avatar name={staff.name} url={staff.avatarUrl} size="md" accent />
          <div className="hidden text-sm sm:block">
            <p className="font-medium leading-tight">{staff.name || staff.email}</p>
            <p className="text-xs text-cyan">{ROLE_LABEL[staff.role]}</p>
          </div>
        </div>
      </div>
    </header>
  );
}
