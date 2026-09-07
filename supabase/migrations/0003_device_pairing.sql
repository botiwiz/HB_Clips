-- Device pairing: lets a second device adopt the same anonymous account as
-- the first, since `signInAnonymously()` otherwise mints a brand-new,
-- disjoint identity per install. Apply after 0001_init.sql/0002_*.sql, via
-- Studio's SQL editor or psql, same as the earlier migrations.
--
-- Flow: device A calls `create_pairing_code()`, shows the returned short
-- code. Device B enters it and calls `redeem_pairing_code(code)`, which
-- returns device A's current refresh token; device B then calls
-- `client.auth.setSession(refreshToken)` client-side to adopt device A's
-- session. See `../selfhost/README.md` for the known GoTrue
-- refresh-token-rotation risk this carries for concurrent multi-device use.

create table if not exists public.device_pairing_codes (
  code text primary key,
  refresh_token text not null,
  created_at timestamptz not null default now()
);

-- RLS is enabled with zero policies, and no grants are given on the table
-- itself to anon/authenticated below - the only way in or out is through
-- the two SECURITY DEFINER functions, so a caller can never enumerate
-- pending codes or read another device's refresh token directly.
alter table public.device_pairing_codes enable row level security;
revoke all on public.device_pairing_codes from public, anon, authenticated;

-- Codes expire quickly since redeeming one hands over a live session.
create or replace function public._generate_pairing_code()
returns text
language plpgsql
as $$
declare
  -- Excludes 0/O/1/I/L to avoid ambiguous characters in a hand-typed code.
  chars text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return result;
end;
$$;

create or replace function public.create_pairing_code()
returns text
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_code text;
  v_refresh_token text;
  v_session_id uuid;
  v_attempt int := 0;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  v_session_id := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  if v_session_id is null then
    raise exception 'no session id on the current token';
  end if;

  select rt.token into v_refresh_token
  from auth.refresh_tokens rt
  where rt.session_id = v_session_id
    and rt.revoked = false
  order by rt.created_at desc
  limit 1;

  if v_refresh_token is null then
    raise exception 'no active refresh token found for this session';
  end if;

  delete from public.device_pairing_codes where created_at < now() - interval '5 minutes';

  loop
    v_code := public._generate_pairing_code();
    begin
      insert into public.device_pairing_codes (code, refresh_token)
      values (v_code, v_refresh_token);
      exit;
    exception when unique_violation then
      v_attempt := v_attempt + 1;
      if v_attempt >= 10 then
        raise exception 'could not generate a unique pairing code, try again';
      end if;
    end;
  end loop;

  return v_code;
end;
$$;

create or replace function public.redeem_pairing_code(p_code text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_refresh_token text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  delete from public.device_pairing_codes
  where code = upper(trim(p_code))
    and created_at >= now() - interval '5 minutes'
  returning refresh_token into v_refresh_token;

  if v_refresh_token is null then
    raise exception 'invalid or expired pairing code';
  end if;

  return v_refresh_token;
end;
$$;

grant execute on function public.create_pairing_code() to authenticated;
grant execute on function public.redeem_pairing_code(text) to authenticated;
