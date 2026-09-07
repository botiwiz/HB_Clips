import 'package:drift/drift.dart';

/// Durable outbox of local mutations still waiting to be pushed to
/// Supabase. Populated by `ClipsRepository`/`StrokesRepository`/
/// `BoardsRepository` (via `lib/data/sync/outbox.dart`) as they write;
/// drained by `lib/data/sync/sync_queue_drainer.dart`.
class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'clip', 'stroke', or 'board'.
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// 'upsert' or 'delete'.
  TextColumn get operation => text()();

  /// Unused for 'upsert' (the drainer always re-reads the current row from
  /// Drift by [entityId] instead) and for 'delete' (only the id matters).
  /// Kept as a required column since it's cheap and may be useful for
  /// debugging a stuck queue entry later.
  TextColumn get payloadJson => text()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
