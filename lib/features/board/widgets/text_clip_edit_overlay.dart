import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart' show hexToColor;
import '../controllers/board_controller.dart';
import '../geometry/selection_geometry.dart';
import '../geometry/text_style_ranges.dart';
import 'board_toolbar.dart';

/// A minimum/maximum for the whole-note font-size stepper in the edit
/// toolbar - keeps a note readable without letting it grow/shrink to
/// absurd sizes.
const double _minFontSize = 8;
const double _maxFontSize = 72;
const double _fontSizeStep = 2;

/// A [TextEditingController] that paints bold/italic/underline/
/// strikethrough ranges live (via [buildTextSpan]) while keeping the
/// underlying value a single plain string - so typing/cursor/selection
/// behave exactly like a normal `TextField`, and only the *painting*
/// reflects rich formatting. This is the standard, officially-supported
/// extension point for exactly this: no invisible marker characters
/// embedded in the text, no custom cursor-offset math.
class _RichTextEditingController extends TextEditingController {
  TextFormatting formatting;

  _RichTextEditingController({required super.text, required this.formatting});

  void setFormatting(TextFormatting next) {
    formatting = next;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(
      children: TextStyleRanges.buildSpans(
        text,
        formatting,
        style ?? const TextStyle(),
      ),
    );
  }
}

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
/// focus (click away) or Escape never loses typed text. Bold/italic/
/// underline/strikethrough toggles (Ctrl+B/I/U/S, or the toolbar buttons)
/// and the font-size stepper write through the same "just write it"
/// convention. Renders nothing unless the named clip still exists and is
/// a text clip, so a stale id (clip binned mid-edit) can't crash this.
class TextClipEditOverlay extends ConsumerStatefulWidget {
  const TextClipEditOverlay({super.key});

  /// The toolbar's fixed height - its row's tallest child is the stacked
  /// font-size chevron column (two 40x40 `PillIconButton`s, the same
  /// footprint every other icon button in the app now uses), plus the
  /// `Material`'s own 2px top/bottom padding. A known constant (not a
  /// guess) so `screenRectFor` and the widget's own positioning always
  /// agree exactly.
  static const double toolbarHeight = 84;

  /// Screen-space bounds of the edit-mode toolbar for [clip] at the
  /// current [view] - lets `board_canvas.dart` recognize a click landing
  /// on the toolbar as "not an empty-canvas/board click" (the same
  /// click-through-guard pattern used elsewhere for other floating
  /// overlays, e.g. `ArrangeSelectionButton.screenRectFor`), so it doesn't
  /// steal focus away from the TextField and exit edit mode before the
  /// toolbar's own button gets a chance to handle the tap.
  static Rect screenRectFor(BoardClip clip, BoardViewState view) {
    final effectiveScale = clip.sizeLockScale ?? view.scale;
    final topLeft = Offset(clip.x, clip.y) * view.scale + view.panOffset;
    final boxWidth = clip.width * effectiveScale;
    final top = topLeft.dy - 8 - toolbarHeight;
    // Width is generous (the toolbar's Row sizes to its content, which can
    // be wider than the note itself) - matching board_canvas.dart's other
    // guards, an approximate-but-safe rect is fine here since a miss only
    // means a click just outside the toolbar's edge falls through to
    // normal canvas handling, same as clicking genuinely elsewhere. 300
    // comfortably covers the row's content now that every button is a
    // 40x40 PillIconButton (font-size label + chevron column + 6 format
    // buttons + 2 dividers).
    final width = boxWidth < 300 ? 300.0 : boxWidth;
    return Rect.fromLTWH(topLeft.dx, top, width, toolbarHeight);
  }

  @override
  ConsumerState<TextClipEditOverlay> createState() =>
      _TextClipEditOverlayState();
}

class _TextClipEditOverlayState extends ConsumerState<TextClipEditOverlay> {
  _RichTextEditingController? _controller;
  FocusNode? _focusNode;
  String? _boundClipId;

  void _bind(BoardClip clip) {
    _controller = _RichTextEditingController(
      text: clip.textContent ?? '',
      formatting: clip.textFormatting,
    );
    _focusNode = FocusNode(debugLabel: 'TextClipEdit-${clip.id}');
    _boundClipId = clip.id;
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

  void _toggleAttribute({
    required List<IntRange> Function(TextFormatting) select,
    required TextFormatting Function(TextFormatting, List<IntRange>) update,
  }) {
    final controller = _controller;
    final id = _boundClipId;
    if (controller == null || id == null) return;
    final sel = controller.selection;
    if (!sel.isValid || sel.isCollapsed) return;

    final toggled = TextStyleRanges.toggle(
      select(controller.formatting),
      sel.start,
      sel.end,
    );
    final next = update(controller.formatting, toggled);
    controller.setFormatting(next);
    ref.read(clipsRepositoryProvider).updateTextFormatting(id, next);
  }

  void _toggleBold() => _toggleAttribute(
    select: (f) => f.bold,
    update: (f, r) => TextFormatting(
      bold: r,
      italic: f.italic,
      underline: f.underline,
      strikethrough: f.strikethrough,
    ),
  );

  void _toggleItalic() => _toggleAttribute(
    select: (f) => f.italic,
    update: (f, r) => TextFormatting(
      bold: f.bold,
      italic: r,
      underline: f.underline,
      strikethrough: f.strikethrough,
    ),
  );

  void _toggleUnderline() => _toggleAttribute(
    select: (f) => f.underline,
    update: (f, r) => TextFormatting(
      bold: f.bold,
      italic: f.italic,
      underline: r,
      strikethrough: f.strikethrough,
    ),
  );

  void _toggleStrikethrough() => _toggleAttribute(
    select: (f) => f.strikethrough,
    update: (f, r) => TextFormatting(
      bold: f.bold,
      italic: f.italic,
      underline: f.underline,
      strikethrough: r,
    ),
  );

  void _adjustFontSize(BoardClip clip, double delta) {
    final current = clip.fontSize ?? kTextNoteFontSize;
    final next = (current + delta).clamp(_minFontSize, _maxFontSize);
    ref.read(clipsRepositoryProvider).updateFontSize(clip.id, next);
  }

  void _toggleSizeLock(BoardClip clip, double viewScale) {
    final locked = clip.sizeLockScale != null;
    ref
        .read(clipsRepositoryProvider)
        .updateSizeLockScale(clip.id, locked ? null : viewScale);
  }

  bool _selectionHasStyle(List<IntRange> ranges) {
    final controller = _controller;
    if (controller == null) return false;
    final sel = controller.selection;
    if (!sel.isValid || sel.isCollapsed) return false;
    return TextStyleRanges.isFullyCovered(ranges, sel.start, sel.end);
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
      _bind(clip);
    } else {
      // Keep the live controller's formatting in sync if it was mutated
      // elsewhere (e.g. a toggle just landed and activeClipsProvider's
      // stream re-emitted) - a no-op rebuild otherwise.
      _controller!.formatting = clip.textFormatting;
    }

    final view = ref.watch(boardViewProvider);
    final effectiveScale = clip.sizeLockScale ?? view.scale;
    final topLeft = Offset(clip.x, clip.y) * view.scale + view.panOffset;
    final boxWidth = clip.width * effectiveScale;
    final boxHeight = clip.height * effectiveScale;
    final locked = clip.sizeLockScale != null;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: topLeft.dx,
            top: topLeft.dy,
            width: boxWidth,
            height: boxHeight,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape):
                    _commitAndExit,
                // Swallows bare Backspace/Delete so they don't bubble up
                // to board_screen.dart's ancestor CallbackShortcuts
                // (which bins the whole board selection on those keys) -
                // without this, backspacing while editing a note also
                // binned everything on the board. Deletion of the
                // character itself is unaffected - that's handled by
                // EditableText's own internal Actions, a descendant of
                // this CallbackShortcuts, so it already ran before the
                // event bubbles up here.
                const SingleActivator(LogicalKeyboardKey.backspace): () {},
                const SingleActivator(LogicalKeyboardKey.delete): () {},
                // Same reasoning for the 4 arrow keys - board_screen.dart
                // binds all of them to nudge the selected clip's
                // position, and with no matching binding here they used
                // to bubble all the way up uncontested, moving the note
                // instead of the text caret. Caret movement itself is,
                // like Backspace/Delete, a descendant EditableText Action
                // that already ran by the time this fires.
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () {},
                const SingleActivator(LogicalKeyboardKey.arrowRight): () {},
                const SingleActivator(LogicalKeyboardKey.arrowUp): () {},
                const SingleActivator(LogicalKeyboardKey.arrowDown): () {},
                const SingleActivator(
                  LogicalKeyboardKey.keyB,
                  control: true,
                ): _toggleBold,
                const SingleActivator(
                  LogicalKeyboardKey.keyI,
                  control: true,
                ): _toggleItalic,
                const SingleActivator(
                  LogicalKeyboardKey.keyU,
                  control: true,
                ): _toggleUnderline,
                const SingleActivator(
                  LogicalKeyboardKey.keyS,
                  control: true,
                ): _toggleStrikethrough,
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.red, width: 2.5),
                  // Opaque even when the note has no custom background
                  // color - AppTheme.textNoteSurface (the static, non-
                  // editing look) is fully transparent by design, and
                  // reusing it here let the clip's own static Text
                  // (rendered underneath, earlier in the same Stack) show
                  // through and overlap with the live TextField's text,
                  // each frame drifting further out of alignment as the
                  // two independent layouts diverged - the "ghosting" bug.
                  // This Container is meant to fully occlude that static
                  // text while editing (see the class doc comment), which
                  // requires actual opacity, not just paint order.
                  color: clip.backgroundColorHex != null
                      ? hexToColor(clip.backgroundColorHex!)
                      : AppTheme.canvasBackground,
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    // Overrides EditableText's default "auto-unfocus on
                    // any tap outside this field" behavior with a no-op -
                    // board_canvas.dart's own explicit
                    // editingTextClipIdProvider clearing (at each point a
                    // click resolves onto a different clip/frame/
                    // connector/empty canvas) is what deliberately ends
                    // edit mode now, not Flutter's internal tap-region
                    // mechanism, which proved unreliable in this heavily
                    // custom-transformed board (wrapping in
                    // TextFieldTapRegion previously caused new regressions
                    // - dropped character insertion and a text-rendering
                    // artifact - without even fixing the original bug).
                    onTapOutside: (event) {},
                    style: TextStyle(
                      color: AppTheme.textNoteText,
                      fontSize:
                          (clip.fontSize ?? kTextNoteFontSize) *
                          effectiveScale,
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
          ),
          Positioned(
            left: topLeft.dx,
            top: topLeft.dy - 8 - TextClipEditOverlay.toolbarHeight,
            height: TextClipEditOverlay.toolbarHeight,
            child: Material(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              elevation: 6,
              shadowColor: Colors.black54,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '${(clip.fontSize ?? kTextNoteFontSize).round()}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PillIconButton(
                          tooltip: 'Increase font size',
                          icon: Icons.keyboard_arrow_up,
                          onPressed: () =>
                              _adjustFontSize(clip, _fontSizeStep),
                        ),
                        PillIconButton(
                          tooltip: 'Decrease font size',
                          icon: Icons.keyboard_arrow_down,
                          onPressed: () =>
                              _adjustFontSize(clip, -_fontSizeStep),
                        ),
                      ],
                    ),
                    _divider(),
                    PillIconButton(
                      tooltip: 'Bold',
                      icon: Icons.format_bold,
                      color: _selectionHasStyle(
                            _controller?.formatting.bold ?? const [],
                          )
                          ? AppTheme.red
                          : null,
                      onPressed: _toggleBold,
                    ),
                    PillIconButton(
                      tooltip: 'Italic',
                      icon: Icons.format_italic,
                      color: _selectionHasStyle(
                            _controller?.formatting.italic ?? const [],
                          )
                          ? AppTheme.red
                          : null,
                      onPressed: _toggleItalic,
                    ),
                    PillIconButton(
                      tooltip: 'Underline',
                      icon: Icons.format_underlined,
                      color: _selectionHasStyle(
                            _controller?.formatting.underline ?? const [],
                          )
                          ? AppTheme.red
                          : null,
                      onPressed: _toggleUnderline,
                    ),
                    PillIconButton(
                      tooltip: 'Strikethrough',
                      icon: Icons.format_strikethrough,
                      color: _selectionHasStyle(
                            _controller?.formatting.strikethrough ?? const [],
                          )
                          ? AppTheme.red
                          : null,
                      onPressed: _toggleStrikethrough,
                    ),
                    _divider(),
                    PillIconButton(
                      tooltip: locked ? 'Unlock size' : 'Lock size',
                      icon: Icons.push_pin_outlined,
                      color: locked ? AppTheme.red : null,
                      onPressed: () => _toggleSizeLock(clip, view.scale),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.border,
    );
  }
}
