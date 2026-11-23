"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  LayoutDashboard, ShieldCheck, Users, Car, Wallet, Siren, MessagesSquare, UserCog, ScrollText, Settings, LogOut,
} from "lucide-react";
import { Logo } from "./logo";
import { useStaff } from "./staff-context";
import { can, type StaffRole } from "@/lib/roles";
import { createClient } from "@/lib/supabase/client";

type Item = { href: string; label: string; icon: React.ElementType; show?: (r: StaffRole) => boolean };

const MAIN: Item[] = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/drivers", label: "Driver verification", icon: ShieldCheck },
  { href: "/passengers", label: "Passengers", icon: Users },
  { href: "/rides", label: "Rides", icon: Car },
  { href: "/payments", label: "Payments", icon: Wallet, show: can.seeMoney },
  { href: "/safety", label: "Safety & SOS", icon: Siren },
  { href: "/support", label: "Support chats", icon: MessagesSquare },
];
const ADMIN: Item[] = [
  { href: "/staff", label: "Staff & access", icon: UserCog, show: can.manageStaff },
  { href: "/audit", label: "Audit log", icon: ScrollText, show: can.seeAudit },
];

export function Sidebar() {
  const staff = useStaff();
  const path = usePathname();
  const router = useRouter();

  async function signOut() {
    await createClient().auth.signOut();
    router.replace("/login");
    router.refresh();
  }

  const link = (i: Item) => {
    if (i.show && !i.show(staff.role)) return null;
    const active = i.href === "/" ? path === "/" : path.startsWith(i.href);
    const Icon = i.icon;
    return (
      <Link
        key={i.href}
        href={i.href}
        className={`flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm transition ${
          active
            ? "bg-gradient-to-r from-royal/80 to-royal/30 text-white shadow-md shadow-royal/20"
            : "text-white/65 hover:bg-white/5 hover:text-white"
        }`}
      >
        <Icon size={17} />
        {i.label}
      </Link>
    );
  };

  return (
    <aside className="card sticky top-4 hidden h-[calc(100vh-2rem)] w-60 shrink-0 flex-col bg-ink/80 p-4 lg:flex">
      <div className="mb-8 flex items-center gap-2.5 px-1">
        <Logo />
        <div>
          <p className="font-semibold leading-tight">Rent A Ride</p>
          <p className="text-[11px] text-cyan">Admin console</p>
        </div>
      </div>
      <nav className="space-y-1">{MAIN.map(link)}</nav>
      {ADMIN.some((i) => !i.show || i.show(staff.role)) && (
        <>
          <p className="mt-6 mb-2 px-3.5 text-[11px] uppercase tracking-wider text-white/35">Administration</p>
          <nav className="space-y-1">{ADMIN.map(link)}</nav>
        </>
      )}
      <div className="mt-auto space-y-1">
        {link({ href: "/settings", label: "Settings", icon: Settings })}
        <button
          onClick={signOut}
          className="flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm text-white/65 hover:bg-white/5 hover:text-white"
        >
          <LogOut size={17} /> Sign out
        </button>
      </div>
    </aside>
  );
}

/** Compact navigation for small screens. */
export function MobileNav() {
  const staff = useStaff();
  const path = usePathname();
  return (
    <nav className="mb-4 flex gap-2 overflow-x-auto pb-1 lg:hidden">
      {[...MAIN, ...ADMIN, { href: "/settings", label: "Settings", icon: Settings }]
        .filter((i) => !("show" in i) || !i.show || i.show(staff.role))
        .map((i) => {
          const active = i.href === "/" ? path === "/" : path.startsWith(i.href);
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
