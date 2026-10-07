import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants.dart';
import 'tables/boards_table.dart';
import 'tables/clips_table.dart';
import 'tables/connectors_table.dart';
import 'tables/frames_table.dart';
import 'tables/local_blobs_table.dart';
import 'tables/strokes_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Clips, Strokes, Boards, LocalBlobs, Frames, Connectors])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: an in-memory database that never touches disk.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 22;

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
        await m.addColumn(clips, clips.opacity);
      }
      if (from < 3) {
        await m.addColumn(clips, clips.backgroundColorHex);
      }
      if (from < 4) {
        await m.addColumn(clips, clips.groupId);
      }
      if (from < 5) {
        await m.addColumn(strokes, strokes.dashed);
        await m.addColumn(strokes, strokes.arrowEnd);
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
        await m.addColumn(frames, frames.backgroundColorHex);
      }
      if (from < 11) {
        await m.addColumn(clips, clips.frameId);
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
        await m.addColumn(clips, clips.imagePanX);
        await m.addColumn(clips, clips.imagePanY);
        await m.addColumn(clips, clips.imageZoom);
        await m.addColumn(clips, clips.imageAspectRatio);
      }
      if (from < 14) {
        await m.createTable(connectors);
      }
      if (from < 15) {
        await m.addColumn(clips, clips.textFormattingJson);
        await m.addColumn(clips, clips.fontSize);
        await m.addColumn(clips, clips.sizeLockScale);
      }
      if (from < 16) {
        await m.addColumn(connectors, connectors.toRelX);
        await m.addColumn(connectors, connectors.toRelY);
      }
      if (from < 17) {
        await m.addColumn(clips, clips.shapeKind);
        await m.addColumn(clips, clips.shapeFillColorHex);
        await m.addColumn(clips, clips.shapeStrokeColorHex);
        await m.addColumn(clips, clips.shapeStrokeWidth);
      }
      if (from < 18) {
        // Every connector originates from a text clip and, until now,
        // defaulted to gray (`#9B9BA1`) with no UI ever letting a user
        // recolor one individually - safe to blanket-update every
        // existing row to the new white default, not just future ones.
        await customStatement("UPDATE connectors SET color = '#FFFFFF'");
      }
      if (from < 19) {
        await m.addColumn(clips, clips.highlightColorHex);
      }
      if (from < 20) {
        await m.addColumn(boards, boards.backupFilePath);
      }
      if (from < 21) {
        await m.addColumn(boards, boards.colorHex);
        await m.addColumn(boards, boards.sortOrder);
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
        await m.addColumn(boards, boards.viewPanX);
        await m.addColumn(boards, boards.viewPanY);
        await m.addColumn(boards, boards.viewScale);
      }
    },
  );
}

/// `driftDatabase()` picks the right backend per platform: a native SQLite
/// file (via `getApplicationDocumentsDirectory()`) on desktop/mobile, or a
/// WASM+IndexedDB-backed database in the browser on web - the same local
/// database either way, no separate code path for web. The web backend
/// needs `sqlite3.wasm` and `drift_worker.js`
/// present in `web/`, downloaded from the `sqlite3`/`drift` GitHub releases
/// matching this project's installed package versions - re-download and
/// replace both if those package versions are ever bumped.
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'hb_clips',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
