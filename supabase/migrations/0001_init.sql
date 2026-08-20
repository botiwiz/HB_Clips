-- HB_Clips initial schema.
--
-- Apply this to your own Supabase project (SQL Editor, or `supabase db push`
-- if you use the Supabase CLI locally). Claude cannot provision or reach a
-- cloud Supabase project directly, so this migration is authored ahead of
-- Phase 6 (sync integration) and is not yet consumed by the app.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- boards
-- ---------------------------------------------------------------------------
create table if not exists boards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null default 'My Board',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- clips: image/screenshot clips (capped at 30 per user) and text notes
-- (unlimited). id is client-generated so offline creation works.
-- ---------------------------------------------------------------------------
create table if not exists clips (
  id uuid primary key,
  board_id uuid not null references boards (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('image', 'text')),
  x double precision not null default 0,
  y double precision not null default 0,
  width double precision not null default 200,
  height double precision not null default 200,
  rotation double precision not null default 0,
  z_index integer not null default 0,
  text_content text,
  storage_path text,
  is_binned boolean not null default false,
  binned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists clips_user_board_idx on clips (user_id, board_id);

-- Server-side backstop for the 30-image cap (the client also enforces this
-- locally before ever reaching the network). Binned images still count,
-- since the cap is otherwise trivially bypassed by binning everything -
-- only a hard delete frees a slot.
create or replace function enforce_image_clip_cap()
returns trigger as $$
declare
  current_count integer;
begin
  if new.type = 'image' then
    select count(*) into current_count
    from clips
    where user_id = new.user_id
      and type = 'image'
      and id <> new.id;

    if current_count >= 30 then
      raise exception 'HB_Clips: 30 image clip limit reached for this account';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists clips_image_cap on clips;
create trigger clips_image_cap
  before insert on clips
  for each row
  execute function enforce_image_clip_cap();

-- ---------------------------------------------------------------------------
-- strokes: vector annotation strokes, either attached to a clip or
-- freestanding on the board. Unlimited.
-- ---------------------------------------------------------------------------
create table if not exists strokes (
  id uuid primary key,
  board_id uuid not null references boards (id) on delete cascade,
  clip_id uuid references clips (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  color text not null default '#FF3B30',
  stroke_width double precision not null default 3,
  points jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists strokes_user_board_idx on strokes (user_id, board_id);

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists boards_set_updated_at on boards;
create trigger boards_set_updated_at
  before update on boards
  for each row execute function set_updated_at();

drop trigger if exists clips_set_updated_at on clips;
create trigger clips_set_updated_at
  before update on clips
  for each row execute function set_updated_at();

drop trigger if exists strokes_set_updated_at on strokes;
create trigger strokes_set_updated_at
  before update on strokes
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security: every row is only visible/writable by its owner.
-- ---------------------------------------------------------------------------
alter table boards enable row level security;
alter table clips enable row level security;
alter table strokes enable row level security;

drop policy if exists boards_owner on boards;
create policy boards_owner on boards
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists clips_owner on clips;
create policy clips_owner on clips
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists strokes_owner on strokes;
create policy strokes_owner on strokes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Realtime: let clients subscribe to changes for cross-device sync.
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table boards;
alter publication supabase_realtime add table clips;
alter publication supabase_realtime add table strokes;

-- ---------------------------------------------------------------------------
-- Storage: private bucket for image clip originals, path
-- {user_id}/{clip_id}/original.jpg, keyed by folder = auth.uid().
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('clip-images', 'clip-images', false)
on conflict (id) do nothing;

drop policy if exists "clip-images owner read" on storage.objects;
create policy "clip-images owner read" on storage.objects
  for select using (
    bucket_id = 'clip-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "clip-images owner write" on storage.objects;
create policy "clip-images owner write" on storage.objects
  for insert with check (
    bucket_id = 'clip-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "clip-images owner update" on storage.objects;
create policy "clip-images owner update" on storage.objects
  for update using (
    bucket_id = 'clip-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "clip-images owner delete" on storage.objects;
create policy "clip-images owner delete" on storage.objects
  for delete using (
    bucket_id = 'clip-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
