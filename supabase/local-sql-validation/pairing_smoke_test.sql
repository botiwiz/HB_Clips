-- Exercises 0003_device_pairing.sql's two SECURITY DEFINER functions the
-- same way PostgREST's RPC endpoint would: as the 'authenticated' role,
-- with a per-request request.jwt.claims GUC carrying 'sub' and
-- 'session_id'. Run after stubs.sql + every migration file, same as
-- rls_smoke_test.sql.
--
-- The generated code is threaded through a temporary table rather than a
-- psql `\gset` variable, since `:'var'` substitution inside a dollar-quoted
-- `do $$ ... $$` block doesn't reliably fire (same unresolved psql quirk
-- already documented in rls_smoke_test.sql) - this pattern is simpler and
-- known to work everywhere it's needed below.

do $$ begin
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

grant usage on schema public to authenticated;
grant usage on schema auth to authenticated;

insert into auth.users (id, is_anonymous) values
  ('11111111-1111-1111-1111-111111111111', true),
  ('22222222-2222-2222-2222-222222222222', true)
on conflict (id) do nothing;

insert into auth.sessions (id, user_id) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111')
on conflict (id) do nothing;

insert into auth.refresh_tokens (token, user_id, session_id, revoked) values
  ('device-a-refresh-token', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', false)
on conflict do nothing;

create temporary table _t_code (code text);
grant insert, select on _t_code to authenticated;

\echo '--- Device A (device 1) creates a pairing code ---'
set role authenticated;
set request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "session_id": "aaaaaaaa-0000-0000-0000-000000000001", "role": "authenticated"}';
insert into _t_code select public.create_pairing_code();
select code as generated_code from _t_code;

\echo '--- Nobody, not even device A itself, can read device_pairing_codes directly (expect: ERROR, permission denied) ---'
do $$
begin
  perform 1 from public.device_pairing_codes limit 1;
  raise notice 'FAIL: direct select succeeded (table should be unreachable except via the functions)';
exception when others then
  raise notice 'PASS: direct select blocked (%)', sqlerrm;
end $$;
reset role;

\echo '--- Device B redeems the code (expect: returns device A''s refresh token) ---'
set role authenticated;
set request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "session_id": "bbbbbbbb-0000-0000-0000-000000000002", "role": "authenticated"}';
select public.redeem_pairing_code((select code from _t_code)) as redeemed_token;
reset role;

\echo '--- Redeeming the same code again fails (single-use, expect: ERROR) ---'
set role authenticated;
set request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "session_id": "bbbbbbbb-0000-0000-0000-000000000002", "role": "authenticated"}';
do $$
begin
  perform public.redeem_pairing_code((select code from _t_code));
  raise notice 'FAIL: second redeem succeeded (should be single-use)';
exception when others then
  raise notice 'PASS: second redeem blocked (%)', sqlerrm;
end $$;
reset role;

\echo '--- An unknown/garbage code fails cleanly (expect: ERROR) ---'
set role authenticated;
set request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "session_id": "bbbbbbbb-0000-0000-0000-000000000002", "role": "authenticated"}';
do $$
begin
  perform public.redeem_pairing_code('ZZZZZZ');
  raise notice 'FAIL: bogus code succeeded';
exception when others then
  raise notice 'PASS: bogus code blocked (%)', sqlerrm;
end $$;
reset role;

drop table if exists _t_code;
