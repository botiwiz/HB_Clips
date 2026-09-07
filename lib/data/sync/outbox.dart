import '../local/database.dart';

/// Records a pending mutation in the local outbox (`SyncQueueEntries`),
/// drained later by `sync_queue_drainer.dart`. Callers wrap this together
/// with their actual Drift write in `db.transaction(...)` so the local
/// write and its outbox entry always land together, never one without the
/// other.
///
/// No payload snapshot is taken here for 'upsert' operations - the
/// drainer always re-reads the current row from Drift by [entityId]
/// immediately before pushing (see `sync_queue_drainer.dart`), so a stale
/// snapshot here would just be dead weight. 'delete' operations need no
/// payload either, since deleting only ever needs the id.
Future<void> enqueueOutbox(
  AppDatabase db, {
  required String entityType,
  required String entityId,
  required String operation,
}) {
  return db.into(db.syncQueueEntries).insert(
    SyncQueueEntriesCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payloadJson: '{}',
    ),
  );
}
