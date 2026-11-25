"use client";

import Link from "next/link";
import { Suspense, useEffect, useRef, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import {
  LayoutDashboard, ShieldCheck, Users, Car, Wallet, Siren, MessagesSquare, UserCog, ScrollText, Settings, LogOut,
  PanelLeft, Pin, MousePointer2, Sparkles, Check,
} from "lucide-react";
import { Logo } from "./logo";
import { useStaff } from "./staff-context";
import { can, type StaffRole } from "@/lib/roles";
import { SERVICES, type ServiceType } from "@/lib/services";
import { createClient } from "@/lib/supabase/client";

type Item = {
  href: string; label: string; icon: React.ElementType; show?: (r: StaffRole) => boolean;
  /** For driver links: which service the link filters to ("all" = no filter). */
  service?: ServiceType | "all";
};

const MAIN: Item[] = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/passengers", label: "Passengers", icon: Users },
  { href: "/rides", label: "Rides", icon: Car },
  { href: "/payments", label: "Payments", icon: Wallet, show: can.seeMoney },
  { href: "/safety", label: "Safety & SOS", icon: Siren },
  { href: "/support", label: "Support chats", icon: MessagesSquare },
];
const DRIVERS: Item[] = [
  { href: "/drivers", label: "All drivers", icon: ShieldCheck, service: "all" },
  ...SERVICES.map((s) => ({ href: `/drivers?service=${s.value}`, label: s.label, icon: s.icon, service: s.value })),
];
const ADMIN: Item[] = [
  { href: "/staff", label: "Staff & access", icon: UserCog, show: can.manageStaff },
  { href: "/audit", label: "Audit log", icon: ScrollText, show: can.seeAudit },
];

/** auto: open on wide screens, icons + hover on smaller ones. pinned: always open. hover: icons, opens on hover. */
type Mode = "auto" | "pinned" | "hover";
const MODES: { value: Mode; label: string; hint: string; icon: React.ElementType }[] = [
  { value: "auto", label: "Auto", hint: "Open on wide screens, hover on smaller ones", icon: Sparkles },
  { value: "pinned", label: "Pinned", hint: "Always open", icon: Pin },
  { value: "hover", label: "Hover", hint: "Icons only — opens when you point at it", icon: MousePointer2 },
];
const MODE_KEY = "rar.sidebar.mode";

export function Sidebar() {
  return (
    <Suspense fallback={<div className="hidden w-[72px] shrink-0 lg:block" />}>
      <SidebarInner />
    </Suspense>
  );
}

function SidebarInner() {
  const staff = useStaff();
  const path = usePathname();
  const params = useSearchParams();
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("auto");
  const [wide, setWide] = useState(true);
  const [hovering, setHovering] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [pending, setPending] = useState<Record<ServiceType, number>>({ ride: 0, dispatch: 0, delivery: 0 });
  const menuRef = useRef<HTMLDivElement>(null);

  // Remembered per browser; storage can be unavailable (private mode), so stay on "auto" then.
  useEffect(() => {
    try {
      const saved = localStorage.getItem(MODE_KEY);
      if (saved === "auto" || saved === "pinned" || saved === "hover") setMode(saved);
    } catch {}
    const mq = window.matchMedia("(min-width: 1280px)");
    const update = () => setWide(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);

  function chooseMode(m: Mode) {
    setMode(m);
    setMenuOpen(false);
    setHovering(false);
    try { localStorage.setItem(MODE_KEY, m); } catch {}
  }

  useEffect(() => {
    if (!menuOpen) return;
    const close = (e: MouseEvent) => { if (!menuRef.current?.contains(e.target as Node)) setMenuOpen(false); };
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, [menuOpen]);

  // Applications waiting for review, per service (refreshed on navigation).
  useEffect(() => {
    const supabase = createClient();
    Promise.all(SERVICES.map((s) => supabase.from("drivers").select("id", { count: "exact", head: true })
      .eq("status", "pending").eq("service_type", s.value)))
      .then((res) => setPending(Object.fromEntries(SERVICES.map((s, i) => [s.value, res[i].count ?? 0])) as Record<ServiceType, number>));
  }, [path, params]);

  const docked = mode === "pinned" || (mode === "auto" && wide); // takes its full width in the layout
  const open = docked || hovering || menuOpen;

  async function signOut() {
    await createClient().auth.signOut();
    router.replace("/login");
    router.refresh();
  }

  const isActive = (i: Item) => {
    if (i.service) {
      if (!path.startsWith("/drivers")) return false;
      const s = params.get("service");
      return i.service === "all" ? !s : s === i.service;
    }
    return i.href === "/" ? path === "/" : path.startsWith(i.href);
  };

  const link = (i: Item) => {
    if (i.show && !i.show(staff.role)) return null;
    const active = isActive(i);
    const Icon = i.icon;
    const count = i.service && i.service !== "all" ? pending[i.service] : 0;
    return (
      <Link
        key={i.href}
        href={i.href}
        title={open ? undefined : i.label}
        aria-label={i.label}
        className={`relative flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm transition ${
          active
            ? "bg-gradient-to-r from-royal/80 to-royal/30 text-white shadow-md shadow-royal/20"
            : "text-white/65 hover:bg-white/5 hover:text-white"
        }`}
      >
        <Icon size={17} className="shrink-0" />
        <span className={`truncate ${open ? "" : "sr-only"}`}>{i.label}</span>
        {count > 0 && (open ? (
          <span className="ml-auto rounded-full bg-warning/20 px-2 py-0.5 text-[11px] font-semibold text-warning"
            title={`${count} waiting for review`}>{count}</span>
        ) : (
          <span className="absolute right-2 top-2 h-2 w-2 rounded-full bg-warning" />
        ))}
      </Link>
    );
  };

  const heading = (text: string) => open
    ? <p className="mt-6 mb-2 px-3.5 text-[11px] uppercase tracking-wider text-white/35">{text}</p>
    : <div className="mx-3 mt-5 mb-3 border-t border-white/10" />;

  return (
    <div className={`relative z-40 hidden shrink-0 transition-[width] duration-200 lg:block ${docked ? "w-60" : "w-[72px]"}`}>
      <aside
        onMouseEnter={() => !docked && setHovering(true)}
        onMouseLeave={() => setHovering(false)}
        onFocus={() => !docked && setHovering(true)}
        onBlur={(e) => { if (!e.currentTarget.contains(e.relatedTarget as Node)) setHovering(false); }}
        className={`card sticky top-4 flex h-[calc(100vh-2rem)] flex-col overflow-y-auto overflow-x-hidden bg-ink/95 p-3 transition-[width] duration-200 ${
          open ? "w-60" : "w-[72px]"} ${open && !docked ? "shadow-2xl shadow-black/50" : ""}`}
      >
        <div className="mb-6 flex items-center gap-2.5 px-1.5 pt-1">
          <div className="shrink-0"><Logo /></div>
          {open && (
            <div className="min-w-0">
              <p className="truncate font-semibold leading-tight">Rent A Ride</p>
              <p className="text-[11px] text-cyan">Admin console</p>
            </div>
          )}
        </div>
        <nav className="space-y-1">{MAIN.slice(0, 1).map(link)}</nav>
        {heading("Drivers & riders")}
        <nav className="space-y-1">{DRIVERS.map(link)}</nav>
        {heading("Operations")}
        <nav className="space-y-1">{MAIN.slice(1).map(link)}</nav>
        {ADMIN.some((i) => !i.show || i.show(staff.role)) && (
          <>
            {heading("Administration")}
            <nav className="space-y-1">{ADMIN.map(link)}</nav>
          </>
        )}
        <div className="mt-auto space-y-1 pt-6">
          {link({ href: "/settings", label: "Settings", icon: Settings })}
          <button
            onClick={signOut}
            title={open ? undefined : "Sign out"}
            className="flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm text-white/65 hover:bg-white/5 hover:text-white"
          >
            <LogOut size={17} className="shrink-0" /><span className={open ? "" : "sr-only"}>Sign out</span>
          </button>
          <div ref={menuRef} className="relative">
            <button
              onClick={() => setMenuOpen((v) => !v)}
              aria-haspopup="menu"
              aria-expanded={menuOpen}
              title={open ? undefined : "Sidebar control"}
              className="flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm text-white/65 hover:bg-white/5 hover:text-white"
            >
              <PanelLeft size={17} className="shrink-0" />
              <span className={open ? "" : "sr-only"}>Sidebar: {MODES.find((m) => m.value === mode)!.label}</span>
            </button>
            {menuOpen && (
              <div role="menu" className="absolute bottom-full left-0 mb-2 w-56 rounded-2xl border border-white/10 bg-ink p-1.5 shadow-2xl shadow-black/60">
                <p className="px-3 pt-1.5 pb-1 text-[11px] uppercase tracking-wider text-white/35">Sidebar control</p>
                {MODES.map((m) => {
                  const Icon = m.icon;
                  return (
                    <button key={m.value} role="menuitemradio" aria-checked={mode === m.value} onClick={() => chooseMode(m.value)}
                      className="flex w-full items-start gap-3 rounded-xl px-3 py-2 text-left hover:bg-white/5">
                      <Icon size={16} className="mt-0.5 shrink-0 text-cyan" />
                      <span className="min-w-0 flex-1">
                        <span className="block text-sm">{m.label}</span>
                        <span className="muted block text-xs">{m.hint}</span>
                      </span>
                      {mode === m.value && <Check size={15} className="mt-0.5 shrink-0 text-cyan" />}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </aside>
    </div>
  );
}

/** Compact navigation for small screens. */
export function MobileNav() {
  return <Suspense><MobileNavInner /></Suspense>;
}

function MobileNavInner() {
  const staff = useStaff();
  const path = usePathname();
  const params = useSearchParams();
  return (
    <nav className="mb-4 flex gap-2 overflow-x-auto pb-1 lg:hidden">
      {[...MAIN.slice(0, 1), ...DRIVERS, ...MAIN.slice(1), ...ADMIN, { href: "/settings", label: "Settings", icon: Settings } as Item]
        .filter((i) => !i.show || i.show(staff.role))
        .map((i) => {
          const active = i.service
            ? path.startsWith("/drivers") && (i.service === "all" ? !params.get("service") : params.get("service") === i.service)
            : i.href === "/" ? path === "/" : path.startsWith(i.href);
          return (
            <Link key={i.href} href={i.href}
              className={`pill whitespace-nowrap px-3.5 py-1.5 text-sm ${active ? "border-transparent bg-royal" : "text-white/70"}`}>
              {i.label}
            </Link>
          );
        })}
    </nav>
  );
}
