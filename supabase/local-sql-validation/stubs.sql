-- Minimal stand-in for the primitives the real Supabase Postgres image
-- provides out of the box, so 0001_init.sql / 0002_*.sql / 0003_*.sql can be
-- applied and exercised against a plain local Postgres for SQL/RLS-logic
-- validation. NOT a substitute for testing against the real image - GoTrue's
-- actual behavior, Storage's RLS wiring, and Realtime are not represented
-- here, only the parts the migrations themselves reference directly.

create extension if not exists pgcrypto;

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
