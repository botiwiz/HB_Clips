import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants.dart';
import '../../core/portable_data_root.dart';
import 'tables/app_settings_table.dart';
import 'tables/boards_table.dart';
import 'tables/clips_table.dart';
import 'tables/connectors_table.dart';
import 'tables/frames_table.dart';
import 'tables/kanban_columns_table.dart';
import 'tables/kanban_elements_table.dart';
import 'tables/kanban_task_links_table.dart';
import 'tables/kanban_tasks_table.dart';
import 'tables/local_blobs_table.dart';
import 'tables/strokes_table.dart';
import 'tables/themes_table.dart';

part 'database.g.dart';

/// Adds [column] to [table] only if it isn't already physically present -
/// guards against a desync between a database's tracked `PRAGMA user_version`
/// and its real on-disk schema (e.g. from an interrupted earlier migration
/// run), which otherwise makes `m.addColumn` throw "duplicate column name"
/// and permanently fail `beforeOpen`, wedging the whole database open forever.
/// Every onUpgrade step below that adds a column goes through this instead of
/// calling `m.addColumn` directly, so the migration chain self-heals
/// regardless of which specific step a given database happens to be
/// desynced on. A no-op (one extra PRAGMA query) for an already-consistent
/// database - functionally identical to a direct `m.addColumn` call.
Future<void> _addColumnIfMissing(
  Migrator m,
  TableInfo table,
  GeneratedColumn column,
) async {
  final rows = await m.database
      .customSelect('PRAGMA table_info(${table.actualTableName})')
      .get();
  final exists = rows.any((row) => row.read<String>('name') == column.name);
  if (!exists) {
    await m.addColumn(table, column);
  }
}

@DriftDatabase(
  tables: [
    Clips,
    Strokes,
    Boards,
    LocalBlobs,
    Frames,
    Connectors,
    AppSettings,
    Themes,
    KanbanElements,
    KanbanColumns,
    KanbanTasks,
    KanbanTaskLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: an in-memory database that never touches disk.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 29;

  Future<void> _seedDefaultBoard(Migrator m) {
    return into(boards).insert(
      BoardsCompanion.insert(id: kLocalBoardId, name: const Value('My Board')),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultBoard(m);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _addColumnIfMissing(m, clips, clips.opacity);
      }
      if (from < 3) {
        await _addColumnIfMissing(m, clips, clips.backgroundColorHex);
      }
      if (from < 4) {
        await _addColumnIfMissing(m, clips, clips.groupId);
      }
      if (from < 5) {
        await _addColumnIfMissing(m, strokes, strokes.dashed);
        await _addColumnIfMissing(m, strokes, strokes.arrowEnd);
      }
      if (from < 6) {
        await m.createTable(boards);
        await _seedDefaultBoard(m);
      }
      if (from < 8) {
        await m.createTable(localBlobs);
      }
      if (from < 9) {
        await m.createTable(frames);
      }
      if (from < 10) {
        await _addColumnIfMissing(m, frames, frames.backgroundColorHex);
      }
      if (from < 11) {
        await _addColumnIfMissing(m, clips, clips.frameId);
      }
      if (from < 12) {
        // Drops the cloud-sync-only columns/table this version removes
        // (`dirty` on clips/boards/frames/strokes, `storagePath` on
        // clips, and the whole `sync_queue_entries` table) - TableMigration
        // rebuilds each table from its current (sync-free) Dart definition
        // and copies over only the columns that still exist, rather than
        // relying on `ALTER TABLE ... DROP COLUMN` support.
        await m.alterTable(TableMigration(clips));
        await m.alterTable(TableMigration(boards));
        await m.alterTable(TableMigration(frames));
        await m.alterTable(TableMigration(strokes));
        await m.deleteTable('sync_queue_entries');
      }
      if (from < 13) {
        await _addColumnIfMissing(m, clips, clips.imagePanX);
        await _addColumnIfMissing(m, clips, clips.imagePanY);
        await _addColumnIfMissing(m, clips, clips.imageZoom);
        await _addColumnIfMissing(m, clips, clips.imageAspectRatio);
      }
      if (from < 14) {
        await m.createTable(connectors);
      }
      if (from < 15) {
        await _addColumnIfMissing(m, clips, clips.textFormattingJson);
        await _addColumnIfMissing(m, clips, clips.fontSize);
        await _addColumnIfMissing(m, clips, clips.sizeLockScale);
      }
      if (from < 16) {
        await _addColumnIfMissing(m, connectors, connectors.toRelX);
        await _addColumnIfMissing(m, connectors, connectors.toRelY);
      }
      if (from < 17) {
        await _addColumnIfMissing(m, clips, clips.shapeKind);
        await _addColumnIfMissing(m, clips, clips.shapeFillColorHex);
        await _addColumnIfMissing(m, clips, clips.shapeStrokeColorHex);
        await _addColumnIfMissing(m, clips, clips.shapeStrokeWidth);
      }
      if (from < 18) {
        // Every connector originates from a text clip and, until now,
        // defaulted to gray (`#9B9BA1`) with no UI ever letting a user
        // recolor one individually - safe to blanket-update every
        // existing row to the new white default, not just future ones.
        await customStatement("UPDATE connectors SET color = '#FFFFFF'");
      }
      if (from < 19) {
        await _addColumnIfMissing(m, clips, clips.highlightColorHex);
      }
      if (from < 20) {
        await _addColumnIfMissing(m, boards, boards.backupFilePath);
      }
      if (from < 21) {
        await _addColumnIfMissing(m, boards, boards.colorHex);
        await _addColumnIfMissing(m, boards, boards.sortOrder);
        // Every pre-existing board just got sortOrder=0 (the column's
        // default) - backfill each one's real rank in today's createdAt
        // order, or they'd all tie and the visible order could scramble
        // the instant this ships.
        final existing = await (m.database.select(
          boards,
        )..orderBy([(b) => OrderingTerm.asc(b.createdAt)])).get();
        for (var i = 0; i < existing.length; i++) {
          await (m.database.update(boards)
                ..where((b) => b.id.equals(existing[i].id)))
              .write(BoardsCompanion(sortOrder: Value(i)));
        }
      }
      if (from < 22) {
        await _addColumnIfMissing(m, boards, boards.viewPanX);
        await _addColumnIfMissing(m, boards, boards.viewPanY);
        await _addColumnIfMissing(m, boards, boards.viewScale);
      }
      if (from < 23) {
        await _addColumnIfMissing(m, frames, frames.sortOrder);
        // Every pre-existing frame just got sortOrder=0 (the column's
        // default) - backfill each one's real rank in today's createdAt
        // order, or they'd all tie and the visible/stacking order could
        // scramble the instant this ships. Frames are scoped per board,
        // so each board's frames are ranked independently.
        final existing = await (m.database.select(
          frames,
        )..orderBy([(f) => OrderingTerm.asc(f.createdAt)])).get();
        final byBoardInsertOrder = <String, List<FrameRow>>{};
        for (final frame in existing) {
          (byBoardInsertOrder[frame.boardId] ??= []).add(frame);
        }
        for (final boardFrames in byBoardInsertOrder.values) {
          for (var i = 0; i < boardFrames.length; i++) {
            await (m.database.update(frames)
                  ..where((f) => f.id.equals(boardFrames[i].id)))
                .write(FramesCompanion(sortOrder: Value(i)));
          }
        }
      }
      if (from < 24) {
        await m.createTable(appSettings);
      }
      if (from < 25) {
        await m.createTable(themes);
        await _addColumnIfMissing(m, appSettings, appSettings.activeThemeId);
      }
      if (from < 26) {
        await _addColumnIfMissing(m, clips, clips.linkUrl);
        await _addColumnIfMissing(m, clips, clips.linkTitle);
        await _addColumnIfMissing(m, themes, themes.gridCrossInterval);
        await _addColumnIfMissing(m, themes, themes.gridCrossScale);
      }
      // `from < 27` used to add `clips.checklistJson`/`clips.swimlaneId`,
      // `frames.kanbanBoardId`, and create the `kanban_boards`/`swimlanes`
      // tables - all belonging to the Miro-style free-floating kanban
      // feature now fully replaced (not migrated) by the `from < 28` step
      // below. That step's `TableMigration` calls rebuild `clips`/`frames`
      // from their CURRENT Dart definitions regardless of which columns
      // existed before, and `deleteTable` is `DROP TABLE IF EXISTS`, so
      // jumping straight from a pre-27 database to 28 is already handled
      // correctly without this step - it's removed outright rather than
      // kept as a dead no-op referencing columns/tables that no longer
      // exist in the Dart schema.
      if (from < 28) {
        // Clean break per the Kanban-to-Trello rebuild: the old
        // free-floating Miro-style kanban board/swimlane feature is fully
        // replaced, not migrated (confirmed no production board data
        // depends on the old format). Delete any kanban-card clips
        // outright first so they don't trip ClipTypeStorage.fromStorage
        // on a now-unknown type value, then rebuild clips/frames from
        // their current (kanban-card/swimlane-free) Dart definitions -
        // same TableMigration column-drop precedent as the `from < 12`
        // step above - and drop the old tables entirely.
        await (m.database.delete(
          clips,
        )..where((c) => c.type.equals('kanban_card'))).go();
        await m.alterTable(TableMigration(clips));
        await m.alterTable(TableMigration(frames));
        await m.deleteTable('swimlanes');
        await m.deleteTable('kanban_boards');
        await m.createTable(kanbanElements);
        await m.createTable(kanbanColumns);
        await m.createTable(kanbanTasks);
        await m.createTable(kanbanTaskLinks);
      }
      if (from < 29) {
        await _addColumnIfMissing(
          m,
          kanbanElements,
          kanbanElements.screenPinned,
        );
        await _addColumnIfMissing(
          m,
          kanbanElements,
          kanbanElements.pinnedScreenX,
        );
        await _addColumnIfMissing(
          m,
          kanbanElements,
          kanbanElements.pinnedScreenY,
        );
      }
    },
  );
}

/// `driftDatabase()` picks the right backend per platform: a native SQLite
/// file (in [portableDataRoot], a `boards/` folder next to the running
/// `.exe`) on desktop/mobile, or a WASM+IndexedDB-backed database in the
/// browser on web - the same local database either way, no separate code
/// path for web. The web backend needs `sqlite3.wasm` and `drift_worker.js`
/// present in `web/`, downloaded from the `sqlite3`/`drift` GitHub releases
/// matching this project's installed package versions - re-download and
/// replace both if those package versions are ever bumped.
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'hb_clips',
    native: DriftNativeOptions(databaseDirectory: portableDataRoot),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
