import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../controllers/kanban_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/kanban_element_geometry.dart';

/// Inline rename `TextField` shown over a kanban element's own header
/// title (always "Kanban Board" until renamed) while
/// [renamingKanbanElementIdProvider] is set - started by double-clicking
/// the element's header in `board_canvas.dart`'s kanban element hit-test.
/// A direct structural copy of `KanbanColumnRenameOverlay`, one level up -
/// scoped to the element itself and
/// `KanbanElementsRepository.renameKanbanElement` instead of a column and
/// `renameColumn`.
class KanbanElementRenameOverlay extends ConsumerStatefulWidget {
  const KanbanElementRenameOverlay({super.key});

  /// Screen-space bounds of the open rename field for [elementId] - used
  /// by `board_canvas.dart` as a click-through guard, same role
  /// `KanbanColumnRenameOverlay.screenRectFor` plays. Returns null if
  /// [elementId] can't currently be resolved (deleted out from under the
  /// rename, undo race).
  static Rect? screenRectFor(
    WidgetRef ref,
    String elementId,
    BoardViewState view,
  ) {
    final elements = ref.read(boardKanbanElementsProvider).valueOrNull ?? [];
    KanbanElementRow? element;
    for (final e in elements) {
      if (e.id == elementId) {
        element = e;
        break;
      }
    }
    if (element == null) return null;

    // A pinned element's own x/y are already literal screen pixels and
    // renders at a frozen scale of 1.0 - same rule
    // `KanbanColumnRenameOverlay.screenRectFor` follows.
    final effectiveElement = element.screenPinned
        ? element.copyWith(
            x: element.pinnedScreenX ?? element.x,
            y: element.pinnedScreenY ?? element.y,
          )
        : element;
    final effectiveScale =
        (element.screenPinned ? 1.0 : view.scale) * element.scale;
    final localRect = KanbanElementGeometry.headerRect(effectiveElement);
    // See `KanbanColumnRenameOverlay.screenRectFor`'s own comment: the
    // rect's screen position is the element's own screen-space origin
    // plus its local offset from that origin, scaled - not a flat
    // board->screen transform of the rect's own coordinates.
    final elementOrigin = Offset(effectiveElement.x, effectiveElement.y);
    final boxTopLeft = element.screenPinned
        ? elementOrigin
        : elementOrigin * view.scale + view.panOffset;
    final topLeft =
        boxTopLeft + (localRect.topLeft - elementOrigin) * effectiveScale;
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      localRect.width * effectiveScale,
      localRect.height * effectiveScale,
    );
  }

  @override
  ConsumerState<KanbanElementRenameOverlay> createState() =>
      _KanbanElementRenameOverlayState();
}

class _KanbanElementRenameOverlayState
    extends ConsumerState<KanbanElementRenameOverlay> {
  String? _boundElementId;
  TextEditingController? _controller;
  FocusNode? _focusNode;
  String _before = '';

  void _bind(KanbanElementRow element) {
    _boundElementId = element.id;
    _before = element.name;
    _controller = TextEditingController(text: element.name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: element.name.length,
      );
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _disposeBinding() {
    _focusNode?.removeListener(_onFocusChange);
    _focusNode?.dispose();
    _controller?.dispose();
    _boundElementId = null;
    _controller = null;
    _focusNode = null;
  }

  void _onFocusChange() {
    if (_focusNode != null && !_focusNode!.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final id = _boundElementId;
    final controller = _controller;
    if (id == null || controller == null) return;
    final trimmed = controller.text.trim();
    if (trimmed.isNotEmpty && trimmed != _before) {
      final elementsRepo = ref.read(kanbanElementsRepositoryProvider);
      final before = _before;
      elementsRepo.renameKanbanElement(id, trimmed);
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => elementsRepo.renameKanbanElement(id, before),
              redo: () => elementsRepo.renameKanbanElement(id, trimmed),
            ),
          );
    }
    ref.read(renamingKanbanElementIdProvider.notifier).state = null;
  }

  void _cancel() {
    ref.read(renamingKanbanElementIdProvider.notifier).state = null;
  }

  @override
  void dispose() {
    _disposeBinding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renamingElementId = ref.watch(renamingKanbanElementIdProvider);
    if (renamingElementId == null) {
      if (_boundElementId != null) _disposeBinding();
      return const SizedBox.shrink();
    }

    final elements = ref.watch(boardKanbanElementsProvider).valueOrNull ?? [];
    KanbanElementRow? element;
    for (final e in elements) {
      if (e.id == renamingElementId) {
        element = e;
        break;
      }
    }
    if (element == null) {
      // The element disappeared from under the rename (deleted, undo
      // race) - nothing left to rename.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(renamingKanbanElementIdProvider.notifier).state = null;
        }
      });
      return const SizedBox.shrink();
    }

    if (_boundElementId != renamingElementId) {
      _disposeBinding();
      _bind(element);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode?.requestFocus();
      });
    }

    final view = ref.watch(boardViewProvider);
    final rect = KanbanElementRenameOverlay.screenRectFor(
      ref,
      renamingElementId,
      view,
    );
    if (rect == null) return const SizedBox.shrink();

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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
