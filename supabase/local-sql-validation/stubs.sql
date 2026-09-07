-- Minimal stand-in for the primitives the real Supabase Postgres image
-- provides out of the box, so 0001_init.sql / 0002_*.sql / 0003_*.sql can be
-- applied and exercised against a plain local Postgres for SQL/RLS-logic
-- validation. NOT a substitute for testing against the real image - GoTrue's
-- actual behavior, Storage's RLS wiring, and Realtime are not represented
-- here, only the parts the migrations themselves reference directly.

create extension if not exists pgcrypto;

-- The real image predefines 'anon' and 'authenticated' roles. Only 'anon'
-- is created here - 'authenticated' is created by the smoke tests
-- themselves (rls_smoke_test.sql / pairing_smoke_test.sql), matching how
-- this file was already split before this change.
do $$ begin
  if not exists (select from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
end $$;

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  is_anonymous boolean not null default false
);

-- Real implementation reads the 'sub' claim out of the PostgREST-set
-- request.jwt.claims GUC. Tests simulate a request by setting this GUC
-- directly via `set local request.jwt.claims = '...'`.
create or replace function auth.uid() returns uuid
language sql stable
as $$
  select
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid
$$;

-- Real implementation returns the full decoded JWT as jsonb (same GUC as
-- auth.uid() above). 0003_device_pairing.sql reads the 'session_id' claim
-- out of this.
create or replace function auth.jwt() returns jsonb
language sql stable
as $$
  select
    coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

-- GoTrue's real session/refresh-token tables, trimmed to the columns
-- 0003_device_pairing.sql actually reads: a session belongs to a user, and
-- a still-valid (not revoked) refresh token belongs to a session.
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists auth.refresh_tokens (
  id bigint generated always as identity primary key,
  token text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  session_id uuid references auth.sessions (id) on delete cascade,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);

create schema if not exists storage;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text,
  owner uuid
);

alter table storage.objects enable row level security;

create or replace function storage.foldername(name text) returns text[]
language sql immutable
as $$
  select string_to_array(name, '/')
$$;

-- The real image sets up a `supabase_realtime` publication; the migration's
-- `alter publication supabase_realtime add table ...` statements need it to
-- exist to apply cleanly.
create publication supabase_realtime;
