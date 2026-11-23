import type { SupabaseClient } from "@supabase/supabase-js";

/** Records a staff action. The database only accepts entries for the caller. */
export async function logAudit(
  supabase: SupabaseClient, actorId: string, action: string,
  targetTable: string, targetId: string, details: Record<string, unknown> = {},
) {
  await supabase.from("audit_log").insert({
    actor_id: actorId, action, target_table: targetTable, target_id: targetId, details,
  });
}
