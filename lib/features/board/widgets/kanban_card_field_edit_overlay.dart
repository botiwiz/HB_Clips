import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/kanban_card_geometry.dart';

/// Inline edit `TextField` for a kanban card's title or one checklist
/// item's label, shown over that row while [editingKanbanFieldProvider]
/// is set - started by double-clicking the title band or a checklist
/// row in `board_canvas.dart`, or automatically right after "+ Add item"
/// creates a fresh blank item. Much smaller than `TextClipEditOverlay`
/// (no toolbar, no rich text) - just one field that commits on Enter/
/// focus-loss and cancels without changing anything on Escape, same role
/// `FrameRenameOverlay` plays for frame titles.
class KanbanCardFieldEditOverlay extends ConsumerStatefulWidget {
  const KanbanCardFieldEditOverlay({super.key});

  /// Screen-space bounds of the active field - used by `board_canvas.dart`
  /// as a click-through guard, same role `FrameRenameOverlay.screenRectFor`
  /// plays.
  static Rect screenRectFor(
    BoardClip clip,
    int? itemIndex,
    BoardViewState view,
  ) {
    final local = itemIndex == null
        ? KanbanCardGeometry.titleRectLocal(clip)
        : KanbanCardGeometry.checklistRowRectLocal(clip, itemIndex);
    final boardRect = KanbanCardGeometry.toBoardRect(clip, local);
    final topLeft = boardRect.topLeft * view.scale + view.panOffset;
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      boardRect.width * view.scale,
      boardRect.height * view.scale,
    );
  }

  @override
  ConsumerState<KanbanCardFieldEditOverlay> createState() =>
      _KanbanCardFieldEditOverlayState();
}

class _KanbanCardFieldEditOverlayState
    extends ConsumerState<KanbanCardFieldEditOverlay> {
  String? _boundClipId;
  int? _boundItemIndex;
  TextEditingController? _controller;
  FocusNode? _focusNode;
  String _before = '';

  void _bind(BoardClip clip, int? itemIndex) {
    _boundClipId = clip.id;
    _boundItemIndex = itemIndex;
    _before = itemIndex == null
        ? (clip.textContent ?? '')
        : clip.checklist.items[itemIndex].label;
    _controller = TextEditingController(text: _before)
      ..selection = TextSelection(baseOffset: 0, extentOffset: _before.length);
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _disposeBinding() {
    _focusNode?.removeListener(_onFocusChange);
    _focusNode?.dispose();
    _controller?.dispose();
    _boundClipId = null;
    _boundItemIndex = null;
    _controller = null;
    _focusNode = null;
  }

  void _onFocusChange() {
    if (_focusNode != null && !_focusNode!.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final id = _boundClipId;
    final itemIndex = _boundItemIndex;
    final controller = _controller;
    if (id == null || controller == null) return;
    final trimmed = controller.text.trim();
    final clipsRepo = ref.read(clipsRepositoryProvider);
    if (itemIndex == null) {
      if (trimmed != _before) {
        final before = _before;
        clipsRepo.updateTextContent(id, trimmed);
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => clipsRepo.updateTextContent(id, before),
                redo: () => clipsRepo.updateTextContent(id, trimmed),
              ),
            );
      }
    } else if (trimmed != _before) {
      final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
      BoardClip? clip;
      for (final c in clips) {
        if (c.id == id) {
          clip = c;
          break;
        }
      }
      if (clip != null && itemIndex < clip.checklist.items.length) {
        final before = clip.checklist;
        final items = [...before.items];
        items[itemIndex] = items[itemIndex].copyWith(label: trimmed);
        final after = Checklist(items: items);
        clipsRepo.updateChecklist(id, after);
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => clipsRepo.updateChecklist(id, before),
                redo: () => clipsRepo.updateChecklist(id, after),
              ),
            );
      }
    }
    ref.read(editingKanbanFieldProvider.notifier).state = null;
  }

  void _cancel() {
    ref.read(editingKanbanFieldProvider.notifier).state = null;
  }

  @override
  void dispose() {
    _disposeBinding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = ref.watch(editingKanbanFieldProvider);
    if (editing == null) {
      if (_boundClipId != null) _disposeBinding();
      return const SizedBox.shrink();
    }

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    BoardClip? clip;
    for (final c in clips) {
      if (c.id == editing.clipId) {
        clip = c;
        break;
      }
    }
    if (clip == null ||
        (editing.itemIndex != null &&
            editing.itemIndex! >= clip.checklist.items.length)) {
      // The card (or checklist item) disappeared from under the edit
      // (deleted, undo race) - nothing left to edit.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(editingKanbanFieldProvider.notifier).state = null;
      });
      return const SizedBox.shrink();
    }

    if (_boundClipId != editing.clipId ||
        _boundItemIndex != editing.itemIndex) {
      _disposeBinding();
      _bind(clip, editing.itemIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode?.requestFocus();
      });
    }

    final view = ref.watch(boardViewProvider);
    final rect = KanbanCardFieldEditOverlay.screenRectFor(
      clip,
      editing.itemIndex,
      view,
    );

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: Material(
          color: Colors.transparent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      ),
    );
  }
}
