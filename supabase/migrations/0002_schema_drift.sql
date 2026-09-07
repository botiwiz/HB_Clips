-- Brings the remote schema in line with the local Drift schema (currently
-- schemaVersion 7), which has grown columns since 0001_init.sql was
-- authored: multi-board support and the PureRef-parity feature work added
-- per-clip opacity/background color/grouping and per-stroke dashed/arrow
-- styling. Types and defaults mirror `lib/data/local/tables/clips_table.dart`
-- and `strokes_table.dart` exactly.
--
-- Deliberately NOT added here: `dirty`/`local_file_path` on any table -
-- those are local-only sync bookkeeping (Drift's outbox-dirty flag and the
-- on-device file cache path), not part of the remote row shape.

alter table clips add column if not exists opacity double precision not null default 1.0;
alter table clips add column if not exists background_color_hex text;
alter table clips add column if not exists group_id uuid;

alter table strokes add column if not exists dashed boolean not null default false;
alter table strokes add column if not exists arrow_end boolean not null default false;
