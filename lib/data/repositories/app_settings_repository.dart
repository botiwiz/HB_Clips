import 'package:drift/drift.dart';

import '../local/database.dart';
import '../local/tables/app_settings_table.dart';

/// Reads/writes the app's single settings row - today just the one
/// configured backup folder path. See `app_settings_table.dart`'s doc
/// comment for why this is one fixed-id row rather than a key/value table.
class AppSettingsRepository {
  final AppDatabase _db;

  AppSettingsRepository(this._db);

  Stream<String?> watchBackupFolderPath() {
    final query = _db.select(_db.appSettings)
      ..where((s) => s.id.equals(kAppSettingsRowId));
    return query.watchSingleOrNull().map((row) => row?.backupFolderPath);
  }

  /// One-shot read - used at startup (the first-run prompt) and anywhere
  /// else a `Future` is more convenient than watching the stream.
  Future<String?> getBackupFolderPath() async {
    final query = _db.select(_db.appSettings)
      ..where((s) => s.id.equals(kAppSettingsRowId));
    return (await query.getSingleOrNull())?.backupFolderPath;
  }

  Future<void> setBackupFolderPath(String? path) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            id: const Value(kAppSettingsRowId),
            backupFolderPath: Value(path),
          ),
        );
  }
}
