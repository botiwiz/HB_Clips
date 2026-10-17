import 'package:drift/drift.dart';

import '../local/database.dart';

/// Local read/write API for kanban task links - created by the
/// right-click "Link to task..." flow. Many-to-many in both directions:
/// one task can link several clips/frames, one clip/frame can link
/// several tasks. On every row, exactly one of [clipId]/[frameId] is
/// non-null - validated here at the repository layer (this codebase has
/// no SQL CHECK constraint precedent anywhere else either).
class KanbanTaskLinksRepository {
  final AppDatabase _db;

  KanbanTaskLinksRepository(this._db);

  /// Watches every link belonging to any kanban element on [boardId], in
  /// one subscription (joined through `kanban_tasks` -> `kanban_columns`
  /// -> `kanban_elements`) - same "watch everything for the parent scope,
  /// filter/group in-memory" convention as `KanbanTasksRepository
  /// .watchTasksForElement`. `ClipWidget`/`FrameWidget` filter this by
  /// their own id to decide whether to render a link badge.
  Stream<List<KanbanTaskLinkRow>> watchLinksForBoard(String boardId) {
    final query = _db.select(_db.kanbanTaskLinks).join([
      innerJoin(
        _db.kanbanTasks,
        _db.kanbanTasks.id.equalsExp(_db.kanbanTaskLinks.taskId),
      ),
      innerJoin(
        _db.kanbanColumns,
        _db.kanbanColumns.id.equalsExp(_db.kanbanTasks.columnId),
      ),
      innerJoin(
        _db.kanbanElements,
        _db.kanbanElements.id.equalsExp(_db.kanbanColumns.kanbanElementId),
      ),
    ])..where(_db.kanbanElements.boardId.equals(boardId));
    return query.watch().map(
      (rows) =>
          rows.map((row) => row.readTable(_db.kanbanTaskLinks)).toList(),
    );
  }

  Future<void> _insertLink(
    String id,
    String taskId,
    String? clipId,
    String? frameId,
  ) {
    assert(
      (clipId == null) != (frameId == null),
      'exactly one of clipId/frameId must be set',
    );
    return _db
        .into(_db.kanbanTaskLinks)
        .insert(
          KanbanTaskLinksCompanion.insert(
            id: id,
            taskId: taskId,
            clipId: Value(clipId),
            frameId: Value(frameId),
          ),
        );
  }

  Future<void> addLink({
    required String id,
    required String taskId,
    String? clipId,
    String? frameId,
  }) {
    return _insertLink(id, taskId, clipId, frameId);
  }

  /// Creates several links at once in one transaction - the right-click
  /// "Link to task..." flow's bulk-link case (a multi-clip/frame
  /// selection linked to one task in a single gesture).
  Future<void> addLinks(
    List<({String id, String taskId, String? clipId, String? frameId})>
    links,
  ) {
    return _db.transaction(() async {
      for (final link in links) {
        await _insertLink(link.id, link.taskId, link.clipId, link.frameId);
      }
    });
  }

  Future<void> deleteLink(String id) {
    return (_db.delete(
      _db.kanbanTaskLinks,
    )..where((l) => l.id.equals(id))).go();
  }
}
