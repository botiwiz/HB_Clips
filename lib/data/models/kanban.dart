import 'dart:convert';

import '../local/database.dart';

/// One row of a kanban task's checklist - a short task label plus
/// whether it's been checked off. `id` is a client-generated uuid, needed
/// so toggle/rename/delete can target a stable row even as items are
/// added or removed around it - a bare index can't do that once the list
/// is mutated. Relocated verbatim from the old kanban-card clip's model
/// (same JSON shape, same convention) - a task's checklist now lives on
/// `kanban_tasks.checklistJson` instead of `clips.checklistJson`.
class ChecklistItem {
  final String id;
  final String label;
  final bool done;

  const ChecklistItem({required this.id, required this.label, this.done = false});

  ChecklistItem copyWith({String? label, bool? done}) =>
      ChecklistItem(id: id, label: label ?? this.label, done: done ?? this.done);

  factory ChecklistItem.fromJsonMap(Map<String, dynamic> map) => ChecklistItem(
    id: map['id'] as String,
    label: map['label'] as String,
    done: map['done'] as bool? ?? false,
  );

  Map<String, dynamic> toJsonMap() => {'id': id, 'label': label, 'done': done};
}

/// A kanban task's checklist - variable-length list of [ChecklistItem],
/// stored as ONE JSON TEXT column (`kanban_tasks.checklistJson`), same
/// "whole structured sub-document on one nullable TEXT column" convention
/// as `TextFormatting`/`textFormattingJson`.
class Checklist {
  final List<ChecklistItem> items;

  const Checklist({this.items = const []});

  static const empty = Checklist();

  factory Checklist.fromJson(String? json) {
    if (json == null || json.isEmpty) return empty;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final raw = decoded['items'] as List<dynamic>? ?? const [];
    return Checklist(
      items: raw
          .map((e) => ChecklistItem.fromJsonMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJson() =>
      jsonEncode({'items': items.map((i) => i.toJsonMap()).toList()});
}

/// Domain-level kanban task, wrapping [KanbanTaskRow] the same way
/// [BoardClip] wraps `ClipRow` - decodes [checklistJson] into a
/// [Checklist] once here instead of every call site doing it. Columns
/// and elements have no JSON-encoded fields needing this treatment, so
/// they're used as their raw Drift rows directly everywhere (same
/// no-wrapper convention `FrameRow` already follows).
class KanbanTask {
  final String id;
  final String columnId;
  final String title;
  final Checklist checklist;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KanbanTask({
    required this.id,
    required this.columnId,
    required this.title,
    this.checklist = Checklist.empty,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KanbanTask.fromRow(KanbanTaskRow row) => KanbanTask(
    id: row.id,
    columnId: row.columnId,
    title: row.title,
    checklist: Checklist.fromJson(row.checklistJson),
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  KanbanTask copyWith({
    String? columnId,
    String? title,
    Checklist? checklist,
    double? sortOrder,
  }) => KanbanTask(
    id: id,
    columnId: columnId ?? this.columnId,
    title: title ?? this.title,
    checklist: checklist ?? this.checklist,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
