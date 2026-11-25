import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { StaffProvider, type Staff } from "@/components/staff-context";
import { Sidebar, MobileNav } from "@/components/sidebar";
import { Topbar } from "@/components/topbar";
import { NoAccess } from "@/components/no-access";
import { MustChangePassword } from "@/components/must-change-password";
import type { StaffRole } from "@/lib/roles";

export default async function DashLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  // A super admin set a temporary password: they pick their own before anything else.
  if (user.user_metadata?.must_change_password) return <MustChangePassword email={user.email ?? ""} />;

  // Only active staff members get in; the database enforces the same rule.
  const { data: role } = await supabase.rpc("my_staff_role");
  if (!role) return <NoAccess email={user.email ?? ""} userId={user.id} />;

  const { data: profile } = await supabase
    .from("profiles").select("full_name, avatar_url").eq("id", user.id).single();

  const staff: Staff = {
    id: user.id,
    email: user.email ?? "",
    name: profile?.full_name ?? "",
    avatarUrl: profile?.avatar_url ?? null,
    role: role as StaffRole,
  };

  return (
    <StaffProvider staff={staff}>
      <div className="mx-auto flex max-w-[1500px] gap-5 p-4">
        <Sidebar />
        <main className="min-w-0 flex-1 py-2">
          <MobileNav />
          <Topbar />
          {children}
        </main>
      </div>
    </StaffProvider>
  );
}
