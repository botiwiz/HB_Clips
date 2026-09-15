import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants.dart';
import 'tables/boards_table.dart';
import 'tables/clips_table.dart';
import 'tables/frames_table.dart';
import 'tables/local_blobs_table.dart';
import 'tables/strokes_table.dart';
import 'tables/sync_queue_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Clips, Strokes, SyncQueueEntries, Boards, LocalBlobs, Frames],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: an in-memory database that never touches disk.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

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
      if (from < 7) {
        await m.addColumn(boards, boards.dirty);
      }
      if (from < 8) {
        await m.createTable(localBlobs);
      }
      if (from < 9) {
        await m.createTable(frames);
      }
    },
  );
}

/// `driftDatabase()` picks the right backend per platform: a native SQLite
/// file (via `getApplicationDocumentsDirectory()`) on desktop/mobile, or a
/// WASM+IndexedDB-backed database in the browser on web - the same
/// offline-capable, fully-synced database either way, no separate code path
/// for web. The web backend needs `sqlite3.wasm` and `drift_worker.js`
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
