-- Frames: named, resizable rectangles drawn behind clips, used to visually
-- group and label a region of the board (Miro's Frame concept). Apply
-- after 0001_init.sql/0002_*.sql/0003_*.sql, via Studio's SQL editor or
-- psql, same as the earlier migrations. Same shape/policy pattern as
-- `boards`/`clips`/`strokes` in 0001_init.sql - frames sync through the
-- exact same outbox/realtime mechanism, nothing frame-specific about it.

create table if not exists frames (
  id uuid primary key,
  board_id uuid not null references boards (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null default 'Frame',
  x double precision not null default 0,
  y double precision not null default 0,
  width double precision not null default 320,
  height double precision not null default 240,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists frames_user_board_idx on frames (user_id, board_id);

drop trigger if exists frames_set_updated_at on frames;
create trigger frames_set_updated_at
  before update on frames
  for each row execute function set_updated_at();

alter table frames enable row level security;

drop policy if exists frames_owner on frames;
create policy frames_owner on frames
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter publication supabase_realtime add table frames;
