-- Applied to Supabase project apebeihmocdomsrhefqs as "05_payments_chat_safety".
create type public.payment_provider as enum ('paystack', 'flutterwave', 'cash', 'wallet');
create type public.payment_status as enum ('pending', 'succeeded', 'failed', 'refunded');
create type public.wallet_tx_type as enum ('top_up', 'ride_payment', 'ride_earning', 'commission', 'payout', 'refund', 'adjustment');
create type public.conversation_kind as enum ('support', 'safety', 'ride');
create type public.sos_status as enum ('open', 'acknowledged', 'resolved');

-- Payments are written only by the backend after verifying with the
-- provider (webhooks). Apps can read their own.
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id),
  ride_id uuid references public.rides (id),
  provider public.payment_provider not null,
  reference text not null unique,
  amount_kobo bigint not null check (amount_kobo > 0),
  currency char(3) not null default 'NGN',
  status public.payment_status not null default 'pending',
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index payments_user_idx on public.payments (user_id, created_at desc);
create index payments_ride_idx on public.payments (ride_id);
create trigger payments_updated_at before update on public.payments
  for each row execute function public.set_updated_at();

create table public.wallets (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  balance_kobo bigint not null default 0 check (balance_kobo >= 0),
  currency char(3) not null default 'NGN',
  updated_at timestamptz not null default now()
);

-- Ledger: every balance change has a row. Backend only.
create table public.wallet_transactions (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.wallets (user_id) on delete cascade,
  type public.wallet_tx_type not null,
  amount_kobo bigint not null check (amount_kobo <> 0),
  balance_after_kobo bigint not null check (balance_after_kobo >= 0),
  ride_id uuid references public.rides (id),
  payment_id uuid references public.payments (id),
  note text,
  created_at timestamptz not null default now()
);
create index wallet_tx_user_idx on public.wallet_transactions (user_id, created_at desc);

-- New users get an empty wallet.
create or replace function public.create_wallet()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.wallets (user_id) values (new.id) on conflict do nothing;
  return new;
end $$;
create trigger profiles_create_wallet after insert on public.profiles
  for each row execute function public.create_wallet();

-- Chat: support and safety threads, and passenger↔driver during a ride.
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind public.conversation_kind not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  ride_id uuid references public.rides (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint ride_chat_has_ride check (kind <> 'ride' or ride_id is not null)
);
create unique index conversations_one_support_safety on public.conversations (user_id, kind)
  where kind in ('support', 'safety');
create unique index conversations_one_per_ride on public.conversations (ride_id) where kind = 'ride';

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id),
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index messages_conversation_idx on public.messages (conversation_id, created_at);

-- Who may take part in a conversation.
create or replace function public.in_conversation(p_conversation uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversations c
    left join public.rides r on r.id = c.ride_id
    where c.id = p_conversation and (
      public.is_admin()
      or (c.kind in ('support', 'safety') and c.user_id = (select auth.uid()))
      or (c.kind = 'ride' and (r.passenger_id = (select auth.uid()) or r.driver_id = (select auth.uid()))
          and r.status in ('accepted', 'driver_arrived', 'in_progress', 'completed'))));
$$;

create table public.sos_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id),
  ride_id uuid references public.rides (id),
  location extensions.geography (point, 4326),
  note text check (char_length(note) <= 500),
  status public.sos_status not null default 'open',
  handled_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index sos_open_idx on public.sos_alerts (created_at desc) where status <> 'resolved';

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(title) <= 120),
  body text not null default '' check (char_length(body) <= 500),
  data jsonb not null default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

-- Row level security
alter table public.payments enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.sos_alerts enable row level security;
alter table public.notifications enable row level security;

create policy "Users read own payments" on public.payments for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());
create policy "Users read own wallet" on public.wallets for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());
create policy "Users read own wallet history" on public.wallet_transactions for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());

create policy "Participants read conversations" on public.conversations for select to authenticated
  using (public.in_conversation(id));
create policy "Users open their support or safety thread" on public.conversations for insert to authenticated
  with check (user_id = (select auth.uid()) and kind in ('support', 'safety') and ride_id is null);
create policy "Ride parties open the ride chat" on public.conversations for insert to authenticated
  with check (kind = 'ride' and user_id = (select auth.uid()) and exists (
    select 1 from public.rides r where r.id = ride_id
      and (r.passenger_id = (select auth.uid()) or r.driver_id = (select auth.uid()))
      and r.status in ('accepted', 'driver_arrived', 'in_progress')));

create policy "Participants read messages" on public.messages for select to authenticated
  using (public.in_conversation(conversation_id));
create policy "Participants send messages" on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid()) and read_at is null and public.in_conversation(conversation_id));

create policy "Users raise and read own SOS; admins all" on public.sos_alerts for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());
create policy "Users raise SOS" on public.sos_alerts for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'open' and handled_by is null
    and (ride_id is null or exists (select 1 from public.rides r where r.id = ride_id
      and (r.passenger_id = (select auth.uid()) or r.driver_id = (select auth.uid())))));
create policy "Admins handle SOS" on public.sos_alerts for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "Users read own notifications" on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

-- Mark a message or notification read without opening up other columns.
create or replace function public.mark_conversation_read(p_conversation uuid)
returns void language sql security definer set search_path = '' as $$
  update public.messages set read_at = now()
  where conversation_id = p_conversation and read_at is null
    and sender_id <> (select auth.uid()) and public.in_conversation(p_conversation);
$$;
create or replace function public.mark_notifications_read()
returns void language sql security definer set search_path = '' as $$
  update public.notifications set read_at = now()
  where user_id = (select auth.uid()) and read_at is null;
$$;

revoke execute on function public.in_conversation, public.mark_conversation_read,
  public.mark_notifications_read from public, anon;
grant execute on function public.in_conversation, public.mark_conversation_read,
  public.mark_notifications_read to authenticated;
revoke execute on function public.create_wallet from public, anon, authenticated;

-- Live updates for the apps (trip status, offers, chat, driver positions).
alter publication supabase_realtime add table public.rides, public.fare_offers, public.messages, public.notifications;
