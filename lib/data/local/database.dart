import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import 'tables/boards_table.dart';
import 'tables/clips_table.dart';
import 'tables/strokes_table.dart';
import 'tables/sync_queue_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Clips, Strokes, SyncQueueEntries, Boards])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: an in-memory database that never touches disk.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

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
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'hb_clips.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
