-- Applied to Supabase project apebeihmocdomsrhefqs as "15_lowercase_withdrawal_reference".
-- Paystack transfer references must be lowercase: wd-<32 hex>.
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
            acct.recipient_code, 'wd-' || replace(gen_random_uuid()::text, '-', ''))
    returning * into w;
  perform public.wallet_post(me, 'payout', -p_amount_kobo, null, null, 'Withdrawal to ' || acct.bank_name);
  return w;
end $$;
