import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart' show hexToColor;
import '../controllers/board_controller.dart';
import '../geometry/selection_geometry.dart';

/// Renders an actively-focused, editable `TextField` directly over the
/// text-note clip named by [editingTextClipIdProvider], positioned/sized
/// exactly like the clip itself - same "separate overlay widget punches
/// through the board's blanket IgnorePointer" pattern
/// [panZoomClipIdProvider]'s pan/zoom drag already established, rather than
/// a prop threaded through `_positionedClip`. Its `Container` fully
/// occludes the clip's own static `Text` underneath (same rect, later in
/// the same `Stack`), so `ClipWidget` itself needs no changes.
///
/// Commits text live via `updateTextContent` on every keystroke - simpler
/// than tracking dirty state for a blur-only commit, and means losing
/// focus (click away) or Escape never loses typed text. Renders nothing
/// unless the named clip still exists and is a text clip, so a stale id
/// (clip binned mid-edit) can't crash this.
class TextClipEditOverlay extends ConsumerStatefulWidget {
  const TextClipEditOverlay({super.key});

  @override
  ConsumerState<TextClipEditOverlay> createState() =>
      _TextClipEditOverlayState();
}

class _TextClipEditOverlayState extends ConsumerState<TextClipEditOverlay> {
  TextEditingController? _controller;
  FocusNode? _focusNode;
  String? _boundClipId;

  void _bind(String clipId, String initialText) {
    _controller = TextEditingController(text: initialText);
    _focusNode = FocusNode(debugLabel: 'TextClipEdit-$clipId');
    _boundClipId = clipId;
    _focusNode!.addListener(() {
      if (!_focusNode!.hasFocus) _commitAndExit();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode?.requestFocus();
    });
  }

  void _commitAndExit() {
    final id = _boundClipId;
    if (id != null) {
      ref
          .read(clipsRepositoryProvider)
          .updateTextContent(id, _controller?.text ?? '');
    }
    if (mounted) {
      ref.read(editingTextClipIdProvider.notifier).state = null;
    }
  }

  void _disposeBinding() {
    _controller?.dispose();
    _focusNode?.dispose();
    _controller = null;
    _focusNode = null;
    _boundClipId = null;
  }

  @override
  void dispose() {
    _disposeBinding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editingId = ref.watch(editingTextClipIdProvider);
    if (editingId == null) {
      if (_boundClipId != null) _disposeBinding();
      return const SizedBox.shrink();
    }

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, editingId);
    if (clip == null || clip.type != ClipType.text) {
      return const SizedBox.shrink();
    }

    if (_boundClipId != editingId) {
      _disposeBinding();
      _bind(editingId, clip.textContent ?? '');
    }

    final view = ref.watch(boardViewProvider);
    final topLeft = Offset(clip.x, clip.y) * view.scale + view.panOffset;

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: clip.width * view.scale,
      height: clip.height * view.scale,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _commitAndExit,
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.red, width: 2.5),
            color: clip.backgroundColorHex != null
                ? hexToColor(clip.backgroundColorHex!)
                : AppTheme.textNoteSurface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                color: AppTheme.textNoteText,
                fontSize: 14,
                height: 1.3,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (text) => ref
                  .read(clipsRepositoryProvider)
                  .updateTextContent(editingId, text),
            ),
          ),
        ),
      ),
    );
  }
}
