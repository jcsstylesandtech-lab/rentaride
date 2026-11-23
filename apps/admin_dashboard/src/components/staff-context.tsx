"use client";

import { createContext, useContext } from "react";
import type { StaffRole } from "@/lib/roles";

export type Staff = { id: string; name: string; email: string; role: StaffRole; avatarUrl: string | null };

const StaffContext = createContext<Staff | null>(null);

export function StaffProvider({ staff, children }: { staff: Staff; children: React.ReactNode }) {
  return <StaffContext.Provider value={staff}>{children}</StaffContext.Provider>;
}

/** The signed-in staff member (always set inside the dashboard). */
export function useStaff() {
  const s = useContext(StaffContext);
  if (!s) throw new Error("useStaff must be used inside the dashboard");
  return s;
}
