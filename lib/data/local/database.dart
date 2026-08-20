import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/clips_table.dart';
import 'tables/strokes_table.dart';
import 'tables/sync_queue_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Clips, Strokes, SyncQueueEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: an in-memory database that never touches disk.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'hb_clips.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
