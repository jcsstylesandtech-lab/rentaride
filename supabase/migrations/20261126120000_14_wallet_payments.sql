-- Applied to Supabase project apebeihmocdomsrhefqs as "14_wallet_payments".
--
-- Money movement: wallet ledger, Paystack top-ups, ride settlement with the
-- platform commission, driver payout accounts and withdrawals.
--
-- Rules
--  * Every balance change goes through public.wallet_post (one ledger row
--    per change, wallet row locked, never below zero).
--  * Apps never write money tables. Top-ups and payouts are confirmed by the
--    Paystack Edge Functions (service role) after verifying with Paystack.
--  * Amounts are kobo (₦1 = 100 kobo).

-- ── Settings ──────────────────────────────────────────────────────────────
create table public.platform_settings (
  id boolean primary key default true check (id),
  commission_bps integer not null default 1500 check (commission_bps between 0 and 5000),
  min_withdrawal_kobo bigint not null default 100000 check (min_withdrawal_kobo > 0),
  min_top_up_kobo bigint not null default 50000 check (min_top_up_kobo > 0),
  max_top_up_kobo bigint not null default 50000000 check (max_top_up_kobo > 0),
  updated_by uuid references public.profiles (id),
  updated_at timestamptz not null default now()
);
insert into public.platform_settings default values;
create trigger platform_settings_updated_at before update on public.platform_settings
  for each row execute function public.set_updated_at();

alter table public.platform_settings enable row level security;
create policy "Signed-in users read platform settings" on public.platform_settings
  for select to authenticated using (true);
create policy "Finance staff update platform settings" on public.platform_settings
  for update to authenticated using (public.has_staff_role('{finance}'))
  with check (public.has_staff_role('{finance}'));

-- Commission from cash trips that a driver's balance could not cover yet;
-- it is taken from their next earnings.
alter table public.wallets
  add column commission_due_kobo bigint not null default 0 check (commission_due_kobo >= 0);

alter table public.payments
  add column channel text check (char_length(channel) <= 40),
  add column paid_at timestamptz;

-- ── Ledger ────────────────────────────────────────────────────────────────
create or replace function public.wallet_post(
  p_user uuid, p_type public.wallet_tx_type, p_amount bigint,
  p_ride uuid default null, p_payment uuid default null, p_note text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  bal bigint;
begin
  if p_amount = 0 then
    select balance_kobo into bal from public.wallets where user_id = p_user;
    return bal;
  end if;
  insert into public.wallets (user_id) values (p_user) on conflict do nothing;
  select balance_kobo into bal from public.wallets where user_id = p_user for update;
  if bal + p_amount < 0 then
    raise exception 'Insufficient wallet balance' using errcode = 'P0001';
  end if;
  update public.wallets set balance_kobo = bal + p_amount, updated_at = now()
    where user_id = p_user;
  insert into public.wallet_transactions (user_id, type, amount_kobo, balance_after_kobo, ride_id, payment_id, note)
    values (p_user, p_type, p_amount, bal + p_amount, p_ride, p_payment, p_note);
  return bal + p_amount;
end $$;

-- Takes outstanding cash-trip commission from the balance, as far as it goes.
create or replace function public.collect_commission_due(p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  w public.wallets;
  take bigint;
begin
  select * into w from public.wallets where user_id = p_user for update;
  if w.user_id is null or w.commission_due_kobo = 0 or w.balance_kobo = 0 then return; end if;
  take := least(w.balance_kobo, w.commission_due_kobo);
  perform public.wallet_post(p_user, 'commission', -take, null, null, 'Commission owed from cash trips');
  update public.wallets set commission_due_kobo = commission_due_kobo - take where user_id = p_user;
end $$;

-- ── Top-ups (called by the Paystack Edge Functions) ───────────────────────
create or replace function public.start_top_up(p_user uuid, p_amount_kobo bigint, p_reference text)
returns public.payments language plpgsql security definer set search_path = '' as $$
declare
  s public.platform_settings;
  p public.payments;
begin
  select * into s from public.platform_settings;
  if p_amount_kobo < s.min_top_up_kobo or p_amount_kobo > s.max_top_up_kobo then
    raise exception 'Top up between ₦% and ₦%.', s.min_top_up_kobo / 100, s.max_top_up_kobo / 100
      using errcode = 'P0001';
  end if;
  insert into public.payments (user_id, provider, reference, amount_kobo)
    values (p_user, 'paystack', p_reference, p_amount_kobo) returning * into p;
  return p;
end $$;

-- Idempotent: safe to call from both the webhook and the app's "verify".
create or replace function public.complete_top_up(
  p_reference text, p_amount_kobo bigint, p_channel text default null)
returns public.payments language plpgsql security definer set search_path = '' as $$
declare
  p public.payments;
begin
  select * into p from public.payments where reference = p_reference for update;
  if p.id is null then
    raise exception 'Unknown payment reference' using errcode = 'P0002';
  end if;
  if p.status <> 'pending' then return p; end if;
  if p_amount_kobo <> p.amount_kobo then
    update public.payments set status = 'failed', failure_reason = 'Amount paid does not match'
      where id = p.id returning * into p;
    return p;
  end if;
  update public.payments set status = 'succeeded', channel = p_channel, paid_at = now()
    where id = p.id returning * into p;
  perform public.wallet_post(p.user_id, 'top_up', p.amount_kobo, null, p.id, 'Wallet top-up');
  perform public.collect_commission_due(p.user_id);
  return p;
end $$;

create or replace function public.fail_top_up(p_reference text, p_reason text)
returns void language sql security definer set search_path = '' as $$
  update public.payments set status = 'failed', failure_reason = left(p_reason, 200)
  where reference = p_reference and status = 'pending';
$$;

-- ── Booking checks ────────────────────────────────────────────────────────
create or replace function public.check_ride_payment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  bal bigint;
  fare bigint := coalesce(new.offered_fare_kobo, new.estimated_fare_kobo);
begin
  if new.payment_method = 'card' then
    raise exception 'Card payment at the end of a trip is not available yet. Pay with your wallet or cash.'
      using errcode = 'P0001';
  end if;
  if new.payment_method = 'wallet' then
    select balance_kobo into bal from public.wallets where user_id = new.passenger_id;
    if coalesce(bal, 0) < fare then
      raise exception 'Your wallet balance is too low for this trip. Add money or pay with cash.'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
create trigger rides_check_payment before insert on public.rides
  for each row execute function public.check_ride_payment();

-- ── Settlement when a trip completes ──────────────────────────────────────
-- Wallet trips: passenger pays the fare from their wallet; the driver is
-- credited the fare and charged the commission. If the passenger's balance
-- is short by then (e.g. a higher negotiated fare), the trip becomes cash.
-- Cash trips: the driver collected the fare; the commission comes from
-- their balance, and anything not covered is owed from future earnings.
create or replace function public.settle_completed_ride()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  fare bigint := coalesce(new.final_fare_kobo, new.agreed_fare_kobo);
  bps integer;
  commission bigint;
  bal bigint;
  pay public.payments;
begin
  if new.status <> 'completed' or old.status = 'completed'
     or new.driver_id is null or coalesce(fare, 0) <= 0 then
    return new;
  end if;
  select commission_bps into bps from public.platform_settings;
  commission := round(fare * bps / 10000.0);

  if new.payment_method = 'wallet' then
    select balance_kobo into bal from public.wallets where user_id = new.passenger_id for update;
    if coalesce(bal, 0) < fare then
      new.payment_method := 'cash';
    end if;
  end if;

  if new.payment_method = 'wallet' then
    insert into public.payments (user_id, ride_id, provider, reference, amount_kobo, status, paid_at)
      values (new.passenger_id, new.id, 'wallet', 'RIDE-' || new.id, fare, 'succeeded', now())
      returning * into pay;
    perform public.wallet_post(new.passenger_id, 'ride_payment', -fare, new.id, pay.id, 'Trip payment');
    perform public.wallet_post(new.driver_id, 'ride_earning', fare, new.id, pay.id, 'Trip fare (wallet)');
    perform public.wallet_post(new.driver_id, 'commission', -commission, new.id, pay.id, 'Platform commission');
    perform public.collect_commission_due(new.driver_id);
  else
    update public.wallets set commission_due_kobo = commission_due_kobo + commission
      where user_id = new.driver_id;
    perform public.collect_commission_due(new.driver_id);
  end if;
  return new;
end $$;
create trigger rides_settle_on_complete before update of status on public.rides
  for each row execute function public.settle_completed_ride();

-- ── Payout accounts and withdrawals ───────────────────────────────────────
-- Written only by the payout-account Edge Function after Paystack confirms
-- the account name and creates a transfer recipient.
create table public.payout_accounts (
  driver_id uuid primary key references public.drivers (id) on delete cascade,
  bank_code text not null check (char_length(bank_code) <= 20),
  bank_name text not null check (char_length(bank_name) <= 120),
  account_number text not null check (account_number ~ '^[0-9]{10}$'),
  account_name text not null check (char_length(account_name) <= 120),
  recipient_code text not null check (char_length(recipient_code) <= 60),
  updated_at timestamptz not null default now()
);
alter table public.payout_accounts enable row level security;
create policy "Drivers read their payout account; finance reads all" on public.payout_accounts
  for select to authenticated
  using (driver_id = (select auth.uid()) or public.has_staff_role('{finance}'));

create type public.withdrawal_status as enum ('requested', 'processing', 'paid', 'failed', 'rejected');

create table public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers (id),
  amount_kobo bigint not null check (amount_kobo > 0),
  status public.withdrawal_status not null default 'requested',
  bank_name text not null,
  account_number text not null,
  account_name text not null,
  recipient_code text not null,
  reference text not null unique,
  transfer_code text,
  failure_reason text,
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index withdrawals_driver_idx on public.withdrawals (driver_id, created_at desc);
create index withdrawals_open_idx on public.withdrawals (created_at) where status in ('requested', 'processing');
create index withdrawals_reviewed_by_idx on public.withdrawals (reviewed_by);
create trigger withdrawals_updated_at before update on public.withdrawals
  for each row execute function public.set_updated_at();
alter table public.withdrawals enable row level security;
create policy "Drivers read their withdrawals; finance reads all" on public.withdrawals
  for select to authenticated
  using (driver_id = (select auth.uid()) or public.has_staff_role('{finance}'));

-- Driver asks to withdraw: the amount leaves the wallet immediately and is
-- returned if the withdrawal is rejected or the transfer fails.
create or replace function public.request_withdrawal(p_amount_kobo bigint)
returns public.withdrawals language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  acct public.payout_accounts;
  s public.platform_settings;
  w public.withdrawals;
begin
  if not exists (select 1 from public.drivers where id = me and status = 'approved') then
    raise exception 'Only approved drivers can withdraw.' using errcode = '42501';
  end if;
  select * into acct from public.payout_accounts where driver_id = me;
  if acct.driver_id is null then
    raise exception 'Add your bank account first.' using errcode = 'P0001';
  end if;
  select * into s from public.platform_settings;
  if p_amount_kobo < s.min_withdrawal_kobo then
    raise exception 'The minimum withdrawal is ₦%.', s.min_withdrawal_kobo / 100 using errcode = 'P0001';
  end if;
  insert into public.withdrawals (driver_id, amount_kobo, bank_name, account_number, account_name,
                                  recipient_code, reference)
    values (me, p_amount_kobo, acct.bank_name, acct.account_number, acct.account_name,
            acct.recipient_code, 'WD-' || replace(gen_random_uuid()::text, '-', ''))
    returning * into w;
  perform public.wallet_post(me, 'payout', -p_amount_kobo, null, null, 'Withdrawal to ' || acct.bank_name);
  return w;
end $$;

-- Finance staff take a request into processing (the Edge Function then
-- sends the Paystack transfer) or reject it (money returns to the wallet).
create or replace function public.begin_withdrawal(p_id uuid)
returns public.withdrawals language plpgsql security definer set search_path = '' as $$
declare
  w public.withdrawals;
begin
  if not public.has_staff_role('{finance}') then
    raise exception 'Only finance staff can approve withdrawals.' using errcode = '42501';
  end if;
  update public.withdrawals set status = 'processing', reviewed_by = (select auth.uid()), reviewed_at = now()
    where id = p_id and status = 'requested' returning * into w;
  if w.id is null then
    raise exception 'This withdrawal is no longer waiting for review.' using errcode = 'P0001';
  end if;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
    values ((select auth.uid()), 'withdrawal.approve', 'withdrawals', w.id::text,
            jsonb_build_object('amount_kobo', w.amount_kobo));
  return w;
end $$;

create or replace function public.reject_withdrawal(p_id uuid, p_reason text)
returns public.withdrawals language plpgsql security definer set search_path = '' as $$
declare
  w public.withdrawals;
begin
  if not public.has_staff_role('{finance}') then
    raise exception 'Only finance staff can reject withdrawals.' using errcode = '42501';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Give the driver a reason.' using errcode = 'P0001';
  end if;
  update public.withdrawals set status = 'rejected', failure_reason = left(p_reason, 200),
    reviewed_by = (select auth.uid()), reviewed_at = now(), completed_at = now()
    where id = p_id and status = 'requested' returning * into w;
  if w.id is null then
    raise exception 'This withdrawal is no longer waiting for review.' using errcode = 'P0001';
  end if;
  perform public.wallet_post(w.driver_id, 'refund', w.amount_kobo, null, null, 'Withdrawal rejected');
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
    values ((select auth.uid()), 'withdrawal.reject', 'withdrawals', w.id::text,
            jsonb_build_object('amount_kobo', w.amount_kobo, 'reason', p_reason));
  return w;
end $$;

-- Transfer outcome (service role: Edge Functions and the Paystack webhook).
create or replace function public.finish_withdrawal(
  p_reference text, p_success boolean, p_transfer_code text default null, p_reason text default null)
returns public.withdrawals language plpgsql security definer set search_path = '' as $$
declare
  w public.withdrawals;
begin
  select * into w from public.withdrawals where reference = p_reference for update;
  if w.id is null then
    raise exception 'Unknown withdrawal reference' using errcode = 'P0002';
  end if;
  if w.status <> 'processing' then return w; end if;
  if p_success then
    update public.withdrawals set status = 'paid', completed_at = now(),
      transfer_code = coalesce(p_transfer_code, transfer_code)
      where id = w.id returning * into w;
  else
    update public.withdrawals set status = 'failed', completed_at = now(),
      transfer_code = coalesce(p_transfer_code, transfer_code),
      failure_reason = left(coalesce(p_reason, 'Transfer failed'), 200)
      where id = w.id returning * into w;
    perform public.wallet_post(w.driver_id, 'refund', w.amount_kobo, null, null, 'Withdrawal failed, money returned');
  end if;
  return w;
end $$;

create or replace function public.set_withdrawal_transfer(p_reference text, p_transfer_code text)
returns void language sql security definer set search_path = '' as $$
  update public.withdrawals set transfer_code = p_transfer_code where reference = p_reference;
$$;

-- ── Access ────────────────────────────────────────────────────────────────
revoke execute on function public.wallet_post, public.collect_commission_due,
  public.start_top_up, public.complete_top_up, public.fail_top_up,
  public.check_ride_payment, public.settle_completed_ride,
  public.finish_withdrawal, public.set_withdrawal_transfer
  from public, anon, authenticated;
grant execute on function public.start_top_up, public.complete_top_up, public.fail_top_up,
  public.finish_withdrawal, public.set_withdrawal_transfer to service_role;
revoke execute on function public.request_withdrawal, public.begin_withdrawal, public.reject_withdrawal
  from public, anon;
grant execute on function public.request_withdrawal, public.begin_withdrawal, public.reject_withdrawal
  to authenticated;

-- Live balance updates in the apps.
alter publication supabase_realtime add table public.wallets, public.withdrawals;
