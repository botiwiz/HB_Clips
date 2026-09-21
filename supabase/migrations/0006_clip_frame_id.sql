-- Adds the clip-to-frame nesting column (local Drift schemaVersion 11).
-- Mirrors `lib/data/local/tables/clips_table.dart` exactly. Deliberately
-- NOT added here: `dirty`, which is local-only sync bookkeeping.

alter table clips add column if not exists frame_id text;
