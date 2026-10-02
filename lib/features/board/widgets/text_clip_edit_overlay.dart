import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hsv_color_picker.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart' show colorToHex, hexToColor;
import '../controllers/board_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/highlight_geometry.dart';
import '../geometry/selection_geometry.dart';
import '../geometry/text_note_geometry.dart';
import '../geometry/text_style_ranges.dart';
import 'board_toolbar.dart';
import 'highlight_painter.dart';

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

  /// Intercepts every text change (typed, backspaced, pasted, cut, or a
  /// select-and-replace) - the single choke point every one of those goes
  /// through - and re-maps [formatting]'s ranges through whatever edit
  /// just happened, via `TextStyleRanges.diffText`/`shiftFormatting`.
  /// Without this, a range's stored character indices stay fixed while
  /// the text around them moves: deleting a word before a bold range
  /// left it pointing at the wrong characters from then on (half a
  /// different word, part of whatever reflowed into that position) -
  /// this keeps formatting attached to the actual characters it was
  /// applied to, not to a position that drifts out from under it.
  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != text) {
      final diff = TextStyleRanges.diffText(text, newValue.text);
      formatting = TextStyleRanges.shiftFormatting(
        formatting,
        diff.start,
        diff.deletedLength,
        diff.insertedLength,
      );
    }
    super.value = newValue;
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

  /// The toolbar's fixed height - its row's tallest child is a 40x40
  /// format-toggle `PillIconButton` (the font-size chevrons are
  /// deliberately kept smaller - see `_chevron`'s doc comment), plus the
  /// `Material`'s own 2px top/bottom padding. A known constant (not a
  /// guess) so `screenRectFor` and the widget's own positioning always
  /// agree exactly.
  static const double toolbarHeight = 44;

  /// The toolbar's clamped screen-space `top`, given the note box's own
  /// screen-space `topLeftDy` - shared by [screenRectFor] and the
  /// widget's own `Positioned` in [build] so they never drift apart.
  /// Clamped to never go negative (same idiom the now-deleted
  /// `ClipStylePopover.screenRectFor` used): a note near the top of the
  /// viewport pins the toolbar to the window's top edge instead of
  /// pushing it off-screen entirely, where it would be completely
  /// invisible regardless of anything else about its rendering.
  static double topFor(double topLeftDy) {
    final top = topLeftDy - 8 - toolbarHeight;
    return top < 8 ? 8 : top;
  }

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
    final top = topFor(topLeft.dy);
    // Width is generous (the toolbar's Row sizes to its content, which can
    // be wider than the note itself) - matching board_canvas.dart's other
    // guards, an approximate-but-safe rect is fine here since a miss only
    // means a click just outside the toolbar's edge falls through to
    // normal canvas handling, same as clicking genuinely elsewhere. 300
    // comfortably covers the row's content (font-size label + compact
    // chevron column + 5 standard 40x40 PillIconButtons + 2 dividers).
    final width = boxWidth < 300 ? 300.0 : boxWidth;
    return Rect.fromLTWH(topLeft.dx, top, width, toolbarHeight);
  }

  /// Screen-space bounds of the note's own box for [clip] at the current
  /// [view] - lets `board_canvas.dart` recognize a click/drag landing on
  /// the actively-edited note itself, before it ever touches focus (see
  /// the guard in `_handlePointerDown` that uses this, right alongside the
  /// one using [screenRectFor] for the toolbar) - otherwise the canvas's
  /// own `_focusNode.requestFocus()` steals focus away from the TextField
  /// before the TextField's own tap/drag handling (caret placement,
  /// click-drag-to-select) gets a chance to claim it for itself.
  static Rect noteRectFor(BoardClip clip, BoardViewState view) {
    final effectiveScale = clip.sizeLockScale ?? view.scale;
    final topLeft = Offset(clip.x, clip.y) * view.scale + view.panOffset;
    final boxWidth = clip.width * effectiveScale;
    final boxHeight = clip.height * effectiveScale;
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, boxWidth, boxHeight);
  }

  @override
  ConsumerState<TextClipEditOverlay> createState() =>
      _TextClipEditOverlayState();
}

class _TextClipEditOverlayState extends ConsumerState<TextClipEditOverlay> {
  _RichTextEditingController? _controller;
  FocusNode? _focusNode;
  String? _boundClipId;
  // The note's text (and formatting - see below) as of the moment this
  // edit session started - lets _commitAndExit push a single undo step
  // for the whole session (undo restores the pre-edit text) instead of
  // one per keystroke, since updateTextContent already writes live on
  // every keystroke for responsiveness.
  String? _textBeforeEdit;
  // Formatting ranges shift during the session as a side effect of
  // typing/deleting (see _RichTextEditingController.value - they stay
  // attached to the same characters as the text around them moves).
  // Captured here so undoing the whole session can restore the ranges
  // that actually matched the pre-edit text, not the post-edit ranges
  // misapplied to reverted text.
  TextFormatting? _formattingBeforeEdit;
  // The height floor in effect when this edit session started (see
  // board_canvas.dart's manual-resize handling and _liveHeight above) -
  // undoing/redoing this session's text change should land on whatever
  // this floor was, not a pure content-fit that ignores a manual resize
  // made before the session began.
  double? _heightBeforeEdit;

  void _bind(BoardClip clip) {
    _controller = _RichTextEditingController(
      text: clip.textContent ?? '',
      formatting: clip.textFormatting,
    );
    _textBeforeEdit = clip.textContent ?? '';
    _formattingBeforeEdit = clip.textFormatting;
    _heightBeforeEdit = clip.height;
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
      final finalText = _controller?.text ?? '';
      final finalFormatting = _controller?.formatting ?? TextFormatting.empty;
      final repo = ref.read(clipsRepositoryProvider);
      repo.updateTextContent(id, finalText);
      repo.updateTextFormatting(id, finalFormatting);
      final before = _textBeforeEdit ?? '';
      final beforeFormatting = _formattingBeforeEdit ?? TextFormatting.empty;
      if (before != finalText) {
        // Width/fontSize can't have changed mid-session (resize handles
        // are hidden while editing; a font-size change pushes its own
        // undo step - see _adjustFontSize), so the live clip's current
        // values are also what they were throughout this whole session.
        final liveClip = ClipGeometry.findById(
          ref.read(activeClipsProvider).valueOrNull ?? [],
          id,
        );
        final width = liveClip?.width ?? kDefaultTextNoteWidth;
        final fontSize = liveClip?.fontSize ?? kTextNoteFontSize;
        // Same one-way floor _liveHeight/onChanged use - undoing/redoing
        // this session's edit shouldn't shrink the box below whatever
        // manual resize was in effect when the session started.
        final floor = _heightBeforeEdit ?? liveClip?.height ?? 0;
        double heightFor(String text, TextFormatting formatting) {
          final contentFit = TextNoteGeometry.requiredHeight(
            text: text,
            formatting: formatting,
            fontSize: fontSize,
            width: width,
          );
          return contentFit > floor ? contentFit : floor;
        }

        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => Future.wait([
                  repo.updateTextContent(id, before),
                  repo.updateTextFormatting(id, beforeFormatting),
                  repo.updateTransform(
                    id,
                    height: heightFor(before, beforeFormatting),
                  ),
                ]),
                redo: () => Future.wait([
                  repo.updateTextContent(id, finalText),
                  repo.updateTextFormatting(id, finalFormatting),
                  repo.updateTransform(
                    id,
                    height: heightFor(finalText, finalFormatting),
                  ),
                ]),
              ),
            );
      }
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
    _textBeforeEdit = null;
    _formattingBeforeEdit = null;
    _heightBeforeEdit = null;
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

    final before = controller.formatting;
    final toggled = TextStyleRanges.toggle(select(before), sel.start, sel.end);
    final next = update(before, toggled);
    controller.setFormatting(next);
    final repo = ref.read(clipsRepositoryProvider);
    repo.updateTextFormatting(id, next);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => repo.updateTextFormatting(id, before),
            redo: () => repo.updateTextFormatting(id, next),
          ),
        );
  }

  void _toggleBold() => _toggleAttribute(
    select: (f) => f.bold,
    update: (f, r) => TextFormatting(
      bold: r,
      italic: f.italic,
      underline: f.underline,
      strikethrough: f.strikethrough,
      highlight: f.highlight,
    ),
  );

  void _toggleItalic() => _toggleAttribute(
    select: (f) => f.italic,
    update: (f, r) => TextFormatting(
      bold: f.bold,
      italic: r,
      underline: f.underline,
      strikethrough: f.strikethrough,
      highlight: f.highlight,
    ),
  );

  void _toggleUnderline() => _toggleAttribute(
    select: (f) => f.underline,
    update: (f, r) => TextFormatting(
      bold: f.bold,
      italic: f.italic,
      underline: r,
      strikethrough: f.strikethrough,
      highlight: f.highlight,
    ),
  );

  void _toggleStrikethrough() => _toggleAttribute(
    select: (f) => f.strikethrough,
    update: (f, r) => TextFormatting(
      bold: f.bold,
      italic: f.italic,
      underline: f.underline,
      strikethrough: r,
      highlight: f.highlight,
    ),
  );

  void _toggleHighlight() => _toggleAttribute(
    select: (f) => f.highlight,
    update: (f, r) => TextFormatting(
      bold: f.bold,
      italic: f.italic,
      underline: f.underline,
      strikethrough: f.strikethrough,
      highlight: r,
    ),
  );

  /// Mirrors `shape_style_popover.dart`'s `ColorPickerSwatch.onColorSelected`
  /// pattern exactly: capture the before hex, write the after hex, push one
  /// undo step - applies to the whole note (one highlight color per note,
  /// not per-range), not gated on a text selection.
  void _setHighlightColor(BoardClip clip, Color color) {
    final before = clip.highlightColorHex;
    final after = colorToHex(color);
    if (before == after) return;
    final repo = ref.read(clipsRepositoryProvider);
    repo.updateHighlightColor(clip.id, after);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => repo.updateHighlightColor(clip.id, before),
            redo: () => repo.updateHighlightColor(clip.id, after),
          ),
        );
  }

  void _adjustFontSize(BoardClip clip, double delta) {
    final beforeRaw = clip.fontSize;
    final current = beforeRaw ?? kTextNoteFontSize;
    final next = (current + delta).clamp(_minFontSize, _maxFontSize);
    final repo = ref.read(clipsRepositoryProvider);
    // A bigger font needs a taller box for the same text - fold a height
    // recompute into the same undo step as the font-size change itself,
    // same "height is a derived value" principle as everywhere else.
    // clip.height is already the floor currently in effect (manual
    // resize or prior growth) - beforeHeight is just that value; after
    // only grows past it if the new font size needs more room, never
    // shrinks it.
    final text = _controller?.text ?? clip.textContent ?? '';
    final formatting = _controller?.formatting ?? clip.textFormatting;
    final beforeHeight = clip.height;
    final contentFitAfter = TextNoteGeometry.requiredHeight(
      text: text,
      formatting: formatting,
      fontSize: next,
      width: clip.width,
    );
    final afterHeight = contentFitAfter > beforeHeight
        ? contentFitAfter
        : beforeHeight;
    repo.updateFontSize(clip.id, next);
    repo.updateTransform(clip.id, height: afterHeight);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([
              repo.updateFontSize(clip.id, beforeRaw),
              repo.updateTransform(clip.id, height: beforeHeight),
            ]),
            redo: () => Future.wait([
              repo.updateFontSize(clip.id, next),
              repo.updateTransform(clip.id, height: afterHeight),
            ]),
          ),
        );
  }

  void _toggleSizeLock(BoardClip clip, double viewScale) {
    final before = clip.sizeLockScale;
    final locked = before != null;
    final next = locked ? null : viewScale;
    final repo = ref.read(clipsRepositoryProvider);
    repo.updateSizeLockScale(clip.id, next);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => repo.updateSizeLockScale(clip.id, before),
            redo: () => repo.updateSizeLockScale(clip.id, next),
          ),
        );
  }

  bool _selectionHasStyle(List<IntRange> ranges) {
    final controller = _controller;
    if (controller == null) return false;
    final sel = controller.selection;
    if (!sel.isValid || sel.isCollapsed) return false;
    return TextStyleRanges.isFullyCovered(ranges, sel.start, sel.end);
  }

  /// The box height needed for the controller's *current* text, computed
  /// synchronously from local state rather than read from `clip.height`
  /// (which lags behind by at least one async round-trip through
  /// `ClipsRepository.updateTransform` and `activeClipsProvider`'s
  /// stream). Used for the live edit box's own size so it's always
  /// correct by the time `TextField` lays out for this frame - without
  /// this, a keystroke that wraps to a new line briefly overflows a box
  /// still sized for the old height, and `TextField`'s internal
  /// scrollable viewport kicks in (a scrollbar, and an inconsistent
  /// scroll-to-caret position) until the round-trip catches up.
  /// `clip.height` is also the current manually-set floor (see
  /// `onChanged` below) - never returns less than it, so typing never
  /// visibly shrinks the box below what was last dragged.
  double _liveHeight(BoardClip clip) {
    final controller = _controller;
    if (controller == null) return clip.height;
    final contentFit = TextNoteGeometry.requiredHeight(
      text: controller.text,
      formatting: controller.formatting,
      fontSize: clip.fontSize ?? kTextNoteFontSize,
      width: clip.width,
    );
    return contentFit > clip.height ? contentFit : clip.height;
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
    final boxHeight = _liveHeight(clip) * effectiveScale;
    final locked = clip.sizeLockScale != null;
    final textStyle = TextStyle(
      color: AppTheme.textNoteText,
      fontSize: (clip.fontSize ?? kTextNoteFontSize) * effectiveScale,
      height: 1.3,
    );
    final innerWidth =
        boxWidth - 2 * kTextNoteHorizontalPadding * effectiveScale;
    final highlightRects = HighlightGeometry.rectsFor(
      text: _controller!.text,
      formatting: _controller!.formatting,
      baseStyle: textStyle,
      width: innerWidth,
      cornerRadius: kHighlightCornerRadius * effectiveScale,
    );

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
                // Deliberately NOT bound here: bare Backspace/Delete.
                // CallbackShortcuts always marks a matched binding
                // "handled" - even a no-op one - which stops the raw key
                // event from propagating any further up the focus chain.
                // Character deletion isn't handled by EditableText
                // locally; it's translated from the raw key into a
                // DeleteCharacterIntent by DefaultTextEditingShortcuts,
                // which Flutter mounts once at the very root of the app
                // (WidgetsApp.build()) - far above this widget. A no-op
                // binding here previously swallowed the event before it
                // could ever reach that root-level translation, silently
                // breaking deletion. board_screen.dart's own
                // Backspace/Delete handling (bin the selection) is now a
                // Focus.onKeyEvent wrapper instead of a CallbackShortcuts
                // binding, specifically so it can conditionally ignore
                // the event while a note is being edited (letting it keep
                // bubbling to the root) rather than unconditionally
                // claiming it.
                // Same reasoning applies to the 4 arrow keys - also not
                // bound here. Caret movement is translated from the raw
                // key the same way deletion is (DefaultTextEditingShortcuts,
                // mounted at the app root), so a no-op binding here would
                // equally have swallowed it before it could reach that
                // root-level translation. board_screen.dart's arrow-key
                // nudge bindings are a Focus.onKeyEvent wrapper that
                // ignores the event while a note is being edited, same as
                // its Backspace/Delete handling.
                const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                    _toggleBold,
                const SingleActivator(LogicalKeyboardKey.keyI, control: true):
                    _toggleItalic,
                const SingleActivator(LogicalKeyboardKey.keyU, control: true):
                    _toggleUnderline,
                const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                    _toggleStrikethrough,
                const SingleActivator(LogicalKeyboardKey.keyH, control: true):
                    _toggleHighlight,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: kTextNoteHorizontalPadding * effectiveScale,
                    vertical: kTextNoteVerticalPadding * effectiveScale,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (highlightRects.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: HighlightPainter(
                              rects: highlightRects,
                              color: hexToColor(
                                clip.highlightColorHex ??
                                    kDefaultHighlightColorHex,
                              ),
                            ),
                          ),
                        ),
                      TextField(
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
                        style: textStyle,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: (text) {
                          final repo = ref.read(clipsRepositoryProvider);
                          repo.updateTextContent(editingId, text);
                          // The controller's `value` setter already re-mapped
                          // formatting through this exact edit - persist it
                          // alongside the text so it isn't lost (and doesn't
                          // get overwritten back to its stale pre-edit value
                          // by the `_controller!.formatting = clip.textFormatting`
                          // sync a few lines up, next time this rebuilds).
                          final formatting = _controller?.formatting;
                          if (formatting != null) {
                            repo.updateTextFormatting(editingId, formatting);
                          }
                          // Auto-grow: height is a pure function of
                          // (text, formatting, fontSize, width) - recompute it
                          // on every keystroke and grow the box when content
                          // needs more room than it currently has. One-way:
                          // clip.height also doubles as the current
                          // manually-set floor (see board_canvas.dart's resize
                          // handling), so typing never auto-shrinks the box
                          // below whatever was last dragged - only another
                          // manual resize can make it shorter.
                          final fontSize = clip.fontSize ?? kTextNoteFontSize;
                          final newHeight = TextNoteGeometry.requiredHeight(
                            text: text,
                            formatting: formatting ?? clip.textFormatting,
                            fontSize: fontSize,
                            width: clip.width,
                          );
                          if (newHeight > clip.height + 0.5) {
                            repo.updateTransform(editingId, height: newHeight);
                          }
                          // Rebuild immediately so boxHeight (driven by
                          // _liveHeight, reading the controller's text we
                          // just updated) is correct before TextField lays
                          // out this frame - without this, the box stays
                          // sized for the stale clip.height until the write
                          // above round-trips back through activeClipsProvider,
                          // and TextField's expanding field briefly overflows
                          // its own bounds, becoming internally scrollable.
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: topLeft.dx,
            top: TextClipEditOverlay.topFor(topLeft.dy),
            height: TextClipEditOverlay.toolbarHeight,
            child: Material(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              elevation: 6,
              shadowColor: Colors.black54,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                // A Positioned child that only specifies left/top (no
                // right/width, as this toolbar does) isn't given
                // unbounded width by RenderStack - it's bounded by the
                // Stack's own size minus the left offset, so this Row's
                // content can run out of room and silently clip past a
                // point. SingleChildScrollView absorbs that overflow by
                // scrolling instead - the same fix PillGroup already
                // uses for every other toolbar in this app (see
                // board_toolbar.dart's own doc comment on this exact
                // problem).
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
                          _chevron(
                            Icons.expand_less,
                            () => _adjustFontSize(clip, _fontSizeStep),
                          ),
                          _chevron(
                            Icons.expand_more,
                            () => _adjustFontSize(clip, -_fontSizeStep),
                          ),
                        ],
                      ),
                      _divider(),
                      PillIconButton(
                        tooltip: 'Bold',
                        icon: Icons.format_bold,
                        color:
                            _selectionHasStyle(
                              _controller?.formatting.bold ?? const [],
                            )
                            ? AppTheme.red
                            : null,
                        onPressed: _toggleBold,
                      ),
                      PillIconButton(
                        tooltip: 'Italic',
                        icon: Icons.format_italic,
                        color:
                            _selectionHasStyle(
                              _controller?.formatting.italic ?? const [],
                            )
                            ? AppTheme.red
                            : null,
                        onPressed: _toggleItalic,
                      ),
                      PillIconButton(
                        tooltip: 'Underline',
                        icon: Icons.format_underlined,
                        color:
                            _selectionHasStyle(
                              _controller?.formatting.underline ?? const [],
                            )
                            ? AppTheme.red
                            : null,
                        onPressed: _toggleUnderline,
                      ),
                      PillIconButton(
                        tooltip: 'Strikethrough',
                        icon: Icons.format_strikethrough,
                        color:
                            _selectionHasStyle(
                              _controller?.formatting.strikethrough ?? const [],
                            )
                            ? AppTheme.red
                            : null,
                        onPressed: _toggleStrikethrough,
                      ),
                      PillIconButton(
                        tooltip: 'Highlight',
                        icon: Icons.format_color_fill,
                        color:
                            _selectionHasStyle(
                              _controller?.formatting.highlight ?? const [],
                            )
                            ? AppTheme.red
                            : null,
                        onPressed: _toggleHighlight,
                      ),
                      ColorPickerSwatch(
                        color: hexToColor(
                          clip.highlightColorHex ?? kDefaultHighlightColorHex,
                        ),
                        onColorSelected: (color) =>
                            _setHighlightColor(clip, color),
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

  /// A compact font-size stepper arrow - deliberately kept smaller than
  /// the app-wide 40x40 `PillIconButton` standard (per explicit user
  /// feedback that the standard size read as oversized for this specific
  /// stacked-pair control), not meant to be reused elsewhere.
  Widget _chevron(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Icon(icon, size: 14, color: AppTheme.textPrimary),
    );
  }
}
