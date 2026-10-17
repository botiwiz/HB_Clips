import 'package:drift/drift.dart';

/// Links a kanban task to a board clip or frame, created by the
/// right-click "Link to task..." flow. Many-to-many in both directions -
/// one task can link several objects, one object can link several tasks.
/// Exactly one of [clipId]/[frameId] is non-null on any row, enforced at
/// the repository layer (this codebase has no SQL CHECK constraint
/// precedent anywhere else either).
@DataClassName('KanbanTaskLinkRow')
class KanbanTaskLinks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get clipId => text().nullable()();
  TextColumn get frameId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
