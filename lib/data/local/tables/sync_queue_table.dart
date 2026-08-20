import 'package:drift/drift.dart';

/// Durable outbox of local mutations still waiting to be pushed to Supabase.
/// Populated by repositories as they write; drained by the sync engine
/// (Phase 6). Not consumed by anything yet in Phase 1 - the table exists now
/// so the local schema doesn't need a breaking migration later.
class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'clip' or 'stroke'.
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// 'upsert' or 'delete'.
  TextColumn get operation => text()();

  /// JSON snapshot of the row at enqueue time.
  TextColumn get payloadJson => text()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
