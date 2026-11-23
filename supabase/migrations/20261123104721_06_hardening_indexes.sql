-- Applied to Supabase project apebeihmocdomsrhefqs as "06_hardening_indexes".
-- Event-trigger helper (auto-enables RLS); never meant to be called via the API.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- Indexes for foreign keys flagged by the performance advisor.
create index driver_documents_reviewed_by_idx on public.driver_documents (reviewed_by);
create index fare_offers_driver_idx on public.fare_offers (driver_id);
create index messages_sender_idx on public.messages (sender_id);
create index ratings_rater_idx on public.ratings (rater_id);
create index ride_events_actor_idx on public.ride_events (actor_id);
create index rides_cancelled_by_idx on public.rides (cancelled_by);
create index rides_vehicle_idx on public.rides (vehicle_id);
create index sos_alerts_handled_by_idx on public.sos_alerts (handled_by);
create index sos_alerts_ride_idx on public.sos_alerts (ride_id);
create index sos_alerts_user_idx on public.sos_alerts (user_id);
create index wallet_tx_payment_idx on public.wallet_transactions (payment_id);
create index wallet_tx_ride_idx on public.wallet_transactions (ride_id);
