-- Applied to Supabase project apebeihmocdomsrhefqs as "10_conversation_owner_read".
-- Let owners read their own threads directly, so `insert ... returning`
-- works (the helper can't see a row inserted in the same statement).
alter policy "Participants read conversations" on public.conversations
  using (user_id = (select auth.uid()) or public.in_conversation(id));
