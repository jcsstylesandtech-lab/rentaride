export type StaffRole = "super_admin" | "operations" | "verifier" | "support" | "finance";

export const ROLE_LABEL: Record<StaffRole, string> = {
  super_admin: "Super admin",
  operations: "Operations",
  verifier: "Verifier",
  support: "Support",
  finance: "Finance",
};

export const ROLE_HELP: Record<StaffRole, string> = {
  super_admin: "Everything, including adding and removing staff.",
  operations: "Rides, users (suspend / reactivate), driver approval, SOS, audit log.",
  verifier: "Review driver documents and vehicles; approve or reject drivers.",
  support: "Reply to support and safety chats; handle SOS alerts.",
  finance: "Payments, wallets and revenue.",
};

/** What each role may do. Mirrors the database rules (RLS), which are the real gate. */
export const can = {
  verifyDrivers: (r: StaffRole) => ["super_admin", "operations", "verifier"].includes(r),
  manageUsers: (r: StaffRole) => ["super_admin", "operations"].includes(r),
  manageRides: (r: StaffRole) => ["super_admin", "operations"].includes(r),
  handleSos: (r: StaffRole) => ["super_admin", "operations", "support"].includes(r),
  seeMoney: (r: StaffRole) => ["super_admin", "finance"].includes(r),
  manageStaff: (r: StaffRole) => r === "super_admin",
  seeAudit: (r: StaffRole) => ["super_admin", "operations"].includes(r),
};
