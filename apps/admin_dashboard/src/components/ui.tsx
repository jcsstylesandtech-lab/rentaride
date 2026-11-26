"use client";

import { X } from "lucide-react";
import { titleCase } from "@/lib/format";

const TONES: Record<string, string> = {
  good: "bg-success/15 text-success",
  warn: "bg-warning/15 text-warning",
  bad: "bg-danger/15 text-danger",
  info: "bg-cyan/15 text-cyan",
  plain: "bg-white/10 text-white/70",
};

const STATUS_TONE: Record<string, keyof typeof TONES> = {
  approved: "good", active: "good", completed: "good", succeeded: "good", resolved: "good",
  pending: "warn", requested: "warn", acknowledged: "warn", driver_arrived: "info",
  accepted: "info", in_progress: "info", open: "bad",
  rejected: "bad", suspended: "bad", cancelled: "bad", failed: "bad", deleted: "bad",
  expired: "plain", refunded: "plain", paid: "good", processing: "info",
};

export function StatusBadge({ status }: { status: string }) {
  return <Badge tone={STATUS_TONE[status] ?? "plain"}>{titleCase(status)}</Badge>;
}

export function Badge({ tone = "plain", children }: { tone?: keyof typeof TONES; children: React.ReactNode }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${TONES[tone]}`}>
      {children}
    </span>
  );
}

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: React.ReactNode }) {
  return (
    <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-2xl font-semibold">{title}</h1>
        {subtitle && <p className="muted mt-1 text-sm">{subtitle}</p>}
      </div>
      {actions}
    </div>
  );
}

export function Tabs<T extends string>({ value, options, onChange }: {
  value: T; options: { value: T; label: string; count?: number }[]; onChange: (v: T) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {options.map((o) => (
        <button
          key={o.value}
          onClick={() => onChange(o.value)}
          className={`pill px-4 py-1.5 text-sm transition ${
            value === o.value ? "border-transparent bg-royal/90 text-white" : "text-white/70 hover:bg-white/5"
          }`}
        >
          {o.label}
          {o.count !== undefined && <span className="ml-1.5 text-white/60">{o.count}</span>}
        </button>
      ))}
    </div>
  );
}

export function Button({ variant = "primary", className = "", ...props }:
  React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "ghost" | "danger" | "success" }) {
  const styles = {
    primary: "bg-gradient-to-r from-royal to-cyan text-white shadow-lg shadow-royal/25",
    ghost: "pill text-white/80 hover:bg-white/5",
    danger: "bg-danger/15 text-danger hover:bg-danger/25",
    success: "bg-success/15 text-success hover:bg-success/25",
  }[variant];
  return (
    <button
      {...props}
      className={`rounded-full px-4 py-2 text-sm font-medium transition disabled:cursor-not-allowed disabled:opacity-40 ${styles} ${className}`}
    />
  );
}

export function SearchInput({ value, onChange, placeholder }: { value: string; onChange: (v: string) => void; placeholder: string }) {
  return (
    <input
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="pill w-full bg-white/5 px-4 py-2 text-sm outline-none placeholder:text-white/40 focus:border-cyan/60 sm:w-72"
    />
  );
}

export function Empty({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="py-14 text-center">
      <p className="font-medium">{title}</p>
      {hint && <p className="muted mt-1 text-sm">{hint}</p>}
    </div>
  );
}

export function Skeleton({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded-lg bg-white/8 ${className}`} />;
}

export function TableSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="space-y-3 p-5">
      {Array.from({ length: rows }).map((_, i) => <Skeleton key={i} className="h-10 w-full" />)}
    </div>
  );
}

export function ErrorNote({ message }: { message: string }) {
  return <div className="rounded-xl bg-danger/10 px-4 py-3 text-sm text-danger">{message}</div>;
}

export function Drawer({ open, title, onClose, children }: {
  open: boolean; title: string; onClose: () => void; children: React.ReactNode;
}) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <aside
        className="h-full w-full max-w-xl overflow-y-auto border-l border-white/10 bg-ink p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-5 flex items-center justify-between">
          <h2 className="text-lg font-semibold">{title}</h2>
          <button onClick={onClose} aria-label="Close" className="pill p-2 hover:bg-white/5"><X size={16} /></button>
        </div>
        {children}
      </aside>
    </div>
  );
}

export const th = "px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-white/45";
export const td = "px-5 py-3.5 text-sm";
