-- Adds the frame color customization column (local Drift schemaVersion 10).
-- Mirrors `lib/data/local/tables/frames_table.dart` exactly. Deliberately
-- NOT added here: `dirty`, which is local-only sync bookkeeping.

alter table frames add column if not exists background_color_hex text;
