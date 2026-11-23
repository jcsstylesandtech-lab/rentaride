"use client";

import { useRouter } from "next/navigation";
import { Logo } from "./logo";
import { createClient } from "@/lib/supabase/client";

/** Signed in, but not (or no longer) an active staff member. */
export function NoAccess({ email, userId }: { email: string; userId: string }) {
  const router = useRouter();
  return (
    <div className="grid min-h-screen place-items-center p-6">
      <div className="card max-w-md p-8 text-center">
        <div className="mb-4 flex justify-center"><Logo size={44} /></div>
        <h1 className="text-xl font-semibold">No dashboard access yet</h1>
        <p className="muted mt-2 text-sm">
          {email} is signed in but isn&apos;t a Rent A Ride staff member. Ask a super admin to add you under
          <b className="text-white"> Staff &amp; access</b>.
        </p>
        <p className="muted mt-3 break-all text-xs">Your user ID: {userId}</p>
        <button
          onClick={async () => { await createClient().auth.signOut(); router.replace("/login"); router.refresh(); }}
          className="pill mt-6 px-5 py-2 text-sm hover:bg-white/5"
        >
          Sign out
        </button>
      </div>
    </div>
  );
}
