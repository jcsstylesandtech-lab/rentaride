"use client";

import { useEffect, useRef, useSyncExternalStore } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";

export type LiveStatus = "connecting" | "live" | "reconnecting";

// ---- Connection health, shared by every live channel (for the top bar) ----
const statuses = new Map<string, LiveStatus>();
const listeners = new Set<() => void>();
function setStatus(name: string, status: LiveStatus | null) {
  if (status === null) statuses.delete(name); else statuses.set(name, status);
  listeners.forEach((l) => l());
}
function overall(): LiveStatus {
  const all = [...statuses.values()];
  if (all.includes("reconnecting")) return "reconnecting";
  if (all.includes("connecting")) return "connecting";
  return "live";
}

/** "live" when every channel on the page is connected. */
export function useLiveStatus(): LiveStatus {
  return useSyncExternalStore(
    (l) => { listeners.add(l); return () => { listeners.delete(l); }; },
    overall,
    () => "connecting",
  );
}

/**
 * Keeps a Supabase Realtime channel connected for as long as the component
 * is on screen.
 *
 * - Reconnects by itself (1 s, 2 s, 4 s … up to 30 s) when the socket errors,
 *   times out or closes, e.g. after a laptop sleeps or Wi-Fi drops.
 * - Calls `onSync` every time the channel (re)joins, when the tab becomes
 *   visible again and when the network comes back, so nothing that happened
 *   while disconnected is missed.
 *
 * `setup` adds the listeners; `name` must be unique on the page. Returns a ref
 * to the current channel (for sending broadcasts).
 */
export function useLiveChannel(
  name: string,
  setup: (channel: RealtimeChannel) => RealtimeChannel,
  onSync: () => void,
  options: { private?: boolean } = {},
) {
  const setupRef = useRef(setup);
  const syncRef = useRef(onSync);
  const channelRef = useRef<RealtimeChannel | null>(null);
  useEffect(() => { setupRef.current = setup; syncRef.current = onSync; });
  const isPrivate = options.private ?? false;

  useEffect(() => {
    const supabase = createClient();
    let stopped = false;
    let attempt = 0;
    let timer: ReturnType<typeof setTimeout> | undefined;

    const connect = () => {
      if (stopped) return;
      setStatus(name, attempt === 0 ? "connecting" : "reconnecting");
      const channel = setupRef.current(supabase.channel(name, isPrivate ? { config: { private: true } } : undefined));
      channelRef.current = channel;
      channel.subscribe((status) => {
        if (stopped || channelRef.current !== channel) return; // an old channel closing
        if (status === "SUBSCRIBED") {
          attempt = 0;
          setStatus(name, "live");
          syncRef.current();
        } else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") {
          scheduleRetry();
        }
      });
    };

    const reconnectNow = async () => {
      if (timer) { clearTimeout(timer); timer = undefined; }
      const old = channelRef.current;
      channelRef.current = null;
      if (old) await supabase.removeChannel(old);
      connect();
    };

    const scheduleRetry = () => {
      if (timer || stopped) return;
      setStatus(name, "reconnecting");
      const delay = Math.min(30_000, 1000 * 2 ** Math.min(attempt, 5));
      attempt++;
      timer = setTimeout(() => { timer = undefined; reconnectNow(); }, delay);
    };

    // Back on the tab, or back online: catch up now, reconnect if needed.
    const wake = () => {
      if (stopped || document.visibilityState === "hidden") return;
      if (timer) reconnectNow(); else syncRef.current();
    };
    window.addEventListener("focus", wake);
    window.addEventListener("online", wake);
    document.addEventListener("visibilitychange", wake);

    connect();
    return () => {
      stopped = true;
      if (timer) clearTimeout(timer);
      window.removeEventListener("focus", wake);
      window.removeEventListener("online", wake);
      document.removeEventListener("visibilitychange", wake);
      setStatus(name, null);
      const ch = channelRef.current;
      channelRef.current = null;
      if (ch) supabase.removeChannel(ch);
    };
  }, [name, isPrivate]);

  return channelRef;
}
