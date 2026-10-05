import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart' show FrameRow;
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/frame_geometry.dart';

/// Inline rename `TextField` shown over a frame's title band while
/// [renamingFrameIdProvider] is set - started by double-clicking a
/// frame's title in `board_canvas.dart`'s frame-hit-test branch. Much
/// smaller than `TextClipEditOverlay` (no toolbar, no rich text) - just
/// one field that commits the new name on Enter or focus-loss, and
/// cancels without changing it on Escape. The existing toolbar
/// pencil-icon rename dialog (`board_screen.dart`'s `_renameFrame`)
/// stays as a second, unrelated way to do the same thing.
class FrameRenameOverlay extends ConsumerStatefulWidget {
  const FrameRenameOverlay({super.key});

  /// Screen-space bounds of the title band's `TextField` for [frame] at
  /// the current [view] - used by `board_canvas.dart` as a click-through
  /// guard so a click inside the field doesn't fall through to the
  /// canvas's own frame-selection/drag logic.
  static Rect screenRectFor(FrameRow frame, BoardViewState view) {
    final topLeft =
        Offset(frame.x, frame.y - FrameGeometry.titleBandHeight) * view.scale +
        view.panOffset;
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      frame.width * view.scale,
      FrameGeometry.titleBandHeight * view.scale,
    );
  }

  @override
  ConsumerState<FrameRenameOverlay> createState() => _FrameRenameOverlayState();
}

class _FrameRenameOverlayState extends ConsumerState<FrameRenameOverlay> {
  String? _boundFrameId;
  TextEditingController? _controller;
  FocusNode? _focusNode;
  String _before = '';

  void _bind(FrameRow frame) {
    _boundFrameId = frame.id;
    _before = frame.name;
    _controller = TextEditingController(text: frame.name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: frame.name.length,
      );
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _disposeBinding() {
    _focusNode?.removeListener(_onFocusChange);
    _focusNode?.dispose();
    _controller?.dispose();
    _boundFrameId = null;
    _controller = null;
    _focusNode = null;
  }

  void _onFocusChange() {
    if (_focusNode != null && !_focusNode!.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final id = _boundFrameId;
    final controller = _controller;
    if (id == null || controller == null) return;
    final trimmed = controller.text.trim();
    if (trimmed.isNotEmpty && trimmed != _before) {
      final framesRepo = ref.read(framesRepositoryProvider);
      final before = _before;
      framesRepo.renameFrame(id, trimmed);
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => framesRepo.renameFrame(id, before),
              redo: () => framesRepo.renameFrame(id, trimmed),
            ),
          );
    }
    ref.read(renamingFrameIdProvider.notifier).state = null;
  }

  void _cancel() {
    ref.read(renamingFrameIdProvider.notifier).state = null;
  }

  @override
  void dispose() {
    _disposeBinding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renamingFrameId = ref.watch(renamingFrameIdProvider);
    if (renamingFrameId == null) {
      if (_boundFrameId != null) _disposeBinding();
      return const SizedBox.shrink();
    }

    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    FrameRow? frame;
    for (final f in frames) {
      if (f.id == renamingFrameId) {
        frame = f;
        break;
      }
    }
    if (frame == null) {
      // The frame disappeared from under the rename (deleted, undo
      // race) - nothing left to rename.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(renamingFrameIdProvider.notifier).state = null;
      });
      return const SizedBox.shrink();
    }

    if (_boundFrameId != renamingFrameId) {
      _disposeBinding();
      _bind(frame);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode?.requestFocus();
      });
    }

    final view = ref.watch(boardViewProvider);
    final rect = FrameRenameOverlay.screenRectFor(frame, view);

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
