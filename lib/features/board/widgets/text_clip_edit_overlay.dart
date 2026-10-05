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
  /// The toolbar's own screen-space width - also the highlight-color
  /// picker bar's width (see [highlightPickerRectFor]), so the two stay
  /// left-aligned and identically sized rather than two independent
  /// guesses that could drift apart. 300 comfortably covers the toolbar
  /// row's content (font-size label + compact chevron column + 5 standard
  /// 40x40 PillIconButtons + 2 dividers); below that, the note's own
  /// (narrower) width would make the toolbar look cramped, so 300 is a
  /// floor, not just a fallback.
  static double toolbarWidthFor(BoardClip clip, BoardViewState view) {
    final effectiveScale = clip.sizeLockScale ?? view.scale;
    final boxWidth = clip.width * effectiveScale;
    return boxWidth < 300 ? 300.0 : boxWidth;
  }

  static Rect screenRectFor(BoardClip clip, BoardViewState view) {
    final topLeft = Offset(clip.x, clip.y) * view.scale + view.panOffset;
    final top = topFor(topLeft.dy);
    // Width is generous (the toolbar's Row sizes to its content, which can
    // be wider than the note itself) - matching board_canvas.dart's other
    // guards, an approximate-but-safe rect is fine here since a miss only
    // means a click just outside the toolbar's edge falls through to
    // normal canvas handling, same as clicking genuinely elsewhere.
    return Rect.fromLTWH(
      topLeft.dx,
      top,
      toolbarWidthFor(clip, view),
      toolbarHeight,
    );
  }

  /// The highlight-color picker bar's fixed height - same role
  /// [toolbarHeight] plays for the toolbar.
  static const double highlightPickerHeight = 44;

  /// The picker bar's clamped screen-space `top`, anchored directly above
  /// the toolbar - same clamp-to-the-window-top idiom [topFor] uses, so a
  /// note near the top of the viewport doesn't push the picker bar
  /// off-screen.
  static double highlightPickerTopFor(double topLeftDy) {
    final top = topFor(topLeftDy) - 8 - highlightPickerHeight;
    return top < 8 ? 8 : top;
  }

  /// Screen-space bounds of the anchored highlight-color picker bar for
  /// [clip] at the current [view] - same click-through-guard role
  /// [screenRectFor] plays for the toolbar (see `board_canvas.dart`'s use
  /// of this, gated on [highlightPickerOpenProvider] since the bar only
  /// exists while open).
  static Rect highlightPickerRectFor(BoardClip clip, BoardViewState view) {
    final topLeft = Offset(clip.x, clip.y) * view.scale + view.panOffset;
    final top = highlightPickerTopFor(topLeft.dy);
    return Rect.fromLTWH(
      topLeft.dx,
      top,
      toolbarWidthFor(clip, view),
      highlightPickerHeight,
    );
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
  // Stable across rebuilds of the same edit session (recreated only when
  // _bind binds a different clip) - identifies the outer Container whose
  // real, Flutter-measured size _scheduleHeightSync reads back after
  // every frame. A fresh GlobalKey() created inline in build() would
  // force an unnecessary element remount on every keystroke.
  GlobalKey? _boxKey;
  // The last height value _scheduleHeightSync actually persisted (or the
  // clip's starting height, seeded in _bind) - compared against on each
  // sync so a rebuild unrelated to this note's content (e.g. the board
  // panning/zooming) is a cheap no-op instead of a redundant repository
  // write.
  double? _lastSyncedHeight;
  // The highlight color in effect when the anchored picker bar was last
  // opened - captured so closing it (Done, or any exit path) can push a
  // single undo step for the whole picker session, comparing against
  // whatever the color ended up at, rather than one step per slider-drag
  // tick (each tick writes live via _applyHighlightColorLive, with no
  // undo push of its own).
  String? _highlightColorBeforePicker;

  void _bind(BoardClip clip) {
    _controller = _RichTextEditingController(
      text: clip.textContent ?? '',
      formatting: clip.textFormatting,
    );
    _textBeforeEdit = clip.textContent ?? '';
    _formattingBeforeEdit = clip.textFormatting;
    _boxKey = GlobalKey(debugLabel: 'TextClipEditBox-${clip.id}');
    _lastSyncedHeight = clip.height;
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
        double heightFor(String text, TextFormatting formatting) {
          return TextNoteGeometry.requiredHeight(
            text: text,
            formatting: formatting,
            fontSize: fontSize,
            width: width,
          );
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
    _boxKey = null;
    _lastSyncedHeight = null;
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

  /// Opens or closes the anchored highlight-color picker bar (tapped from
  /// the toolbar's swatch button). Opening captures the note's current
  /// highlight color as the undo-restore point (see _closeHighlightPicker,
  /// which also handles the Done button and every other exit path).
  void _toggleHighlightPicker(BoardClip clip) {
    if (ref.read(highlightPickerOpenProvider)) {
      _closeHighlightPicker(clip.id);
    } else {
      _highlightColorBeforePicker = clip.highlightColorHex;
      ref.read(highlightPickerOpenProvider.notifier).state = true;
    }
  }

  /// Writes the highlight color directly with no undo push of its own -
  /// called on every slider-drag tick while the picker bar is open, so
  /// the note's highlighted text updates live as the user drags. One
  /// undo step for the whole picker session is pushed when it closes
  /// (see _closeHighlightPicker), not per tick.
  void _applyHighlightColorLive(BoardClip clip, Color color) {
    ref
        .read(clipsRepositoryProvider)
        .updateHighlightColor(clip.id, colorToHex(color));
  }

  void _adjustFontSize(BoardClip clip, double delta) {
    final beforeRaw = clip.fontSize;
    final current = beforeRaw ?? kTextNoteFontSize;
    final next = (current + delta).clamp(_minFontSize, _maxFontSize);
    final repo = ref.read(clipsRepositoryProvider);
    // A bigger font needs a taller box for the same text - fold a height
    // recompute into the same undo step as the font-size change itself,
    // same "height is a derived value" principle as everywhere else.
    // clip.height already exactly fits the current font size (kept
    // accurate by _scheduleHeightSync, which reads it back from
    // Flutter's own layout after every frame), so it doubles as the
    // "before" value with no separate recompute needed. No live
    // TextField exists yet for the "after" (not-yet-applied) font size,
    // so afterHeight still has to be predicted here for the undo/redo
    // closures below - but no immediate write is needed alongside
    // updateFontSize: that triggers the same rebuild -> _scheduleHeightSync
    // path every other change goes through, which will pick up and
    // persist the real post-layout height on its own.
    final text = _controller?.text ?? clip.textContent ?? '';
    final formatting = _controller?.formatting ?? clip.textFormatting;
    final beforeHeight = clip.height;
    final afterHeight = TextNoteGeometry.requiredHeight(
      text: text,
      formatting: formatting,
      fontSize: next,
      width: clip.width,
    );
    repo.updateFontSize(clip.id, next);
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

  /// Reads back the real height Flutter's own layout produced for the
  /// note box (border + padding + content) and persists it to
  /// `clip.height` if it has genuinely changed. This is the single
  /// source of truth for this app's "no scrollbar, no clipping"
  /// auto-grow behavior: the `TextField` in `build()` is given an
  /// unbounded height and sizes itself to exactly fit its content (see
  /// that method's doc comment), so there is nothing left to predict -
  /// this just measures the real answer after each frame instead of
  /// guessing it before the frame, which is what made the box
  /// occasionally one line too short and clipped the last line.
  /// Scheduled unconditionally at the end of every `build()` - cheap to
  /// call even when nothing changed, since `_lastSyncedHeight` (not
  /// `clip.height` directly, which can itself be mid-round-trip) turns a
  /// rebuild from unrelated board activity (panning, another clip
  /// moving) into a single key lookup and comparison, not a write.
  void _scheduleHeightSync(String id, double effectiveScale) {
    final key = _boxKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _boundClipId != id) return;
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final measured = box.size.height / effectiveScale;
      final last = _lastSyncedHeight;
      if (last != null && (measured - last).abs() <= 0.5) return;
      _lastSyncedHeight = measured;
      ref.read(clipsRepositoryProvider).updateTransform(id, height: measured);
    });
  }

  /// Closes the anchored highlight-color picker bar if it's open,
  /// pushing one undo step for the whole picker session (comparing the
  /// color captured when it was opened against [id]'s current color -
  /// every slider-drag tick in between wrote live via
  /// _applyHighlightColorLive with no undo push of its own). A no-op if
  /// the picker isn't open. Called from every path that ends this
  /// widget's edit session (both branches below, before _disposeBinding)
  /// so a pending color change is never silently lost regardless of how
  /// editing ends - deliberately NOT called from dispose() itself (ref
  /// reads aren't safe there).
  void _closeHighlightPicker(String id) {
    if (!ref.read(highlightPickerOpenProvider)) return;
    final before = _highlightColorBeforePicker;
    _highlightColorBeforePicker = null;
    ref.read(highlightPickerOpenProvider.notifier).state = false;
    final liveClip = ClipGeometry.findById(
      ref.read(activeClipsProvider).valueOrNull ?? [],
      id,
    );
    final after = liveClip?.highlightColorHex;
    if (before != after) {
      final repo = ref.read(clipsRepositoryProvider);
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => repo.updateHighlightColor(id, before),
              redo: () => repo.updateHighlightColor(id, after),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editingId = ref.watch(editingTextClipIdProvider);
    if (editingId == null) {
      if (_boundClipId != null) {
        _closeHighlightPicker(_boundClipId!);
        _disposeBinding();
      }
      return const SizedBox.shrink();
    }

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, editingId);
    if (clip == null || clip.type != ClipType.text) {
      return const SizedBox.shrink();
    }

    if (_boundClipId != editingId) {
      if (_boundClipId != null) _closeHighlightPicker(_boundClipId!);
      _disposeBinding();
      _bind(clip);
    } else if (clip.textContent == _controller!.text) {
      // Keep the live controller's formatting in sync if it was mutated
      // elsewhere (e.g. a toggle just landed and activeClipsProvider's
      // stream re-emitted) - a no-op rebuild otherwise. Gated on the
      // text already matching: `clip.textContent` lags the
      // controller's own text by at least one async round-trip through
      // ClipsRepository.updateTextContent/activeClipsProvider's stream
      // (onChanged below fires both writes without awaiting them), so
      // while they differ, `clip.textFormatting` is a stale snapshot
      // that must not overwrite the controller's own already-correct,
      // locally-shifted formatting (see _RichTextEditingController
      // .value) - doing this unconditionally was the actual cause of
      // the edit-mode highlight/formatting offset bug: the live view's
      // highlighted ranges stayed the correct length but got clobbered
      // back to a stale, too-early start index on the very next
      // keystroke's rebuild, compounding with each further edit before
      // the stream caught up.
      _controller!.formatting = clip.textFormatting;
    }

    final view = ref.watch(boardViewProvider);
    final effectiveScale = clip.sizeLockScale ?? view.scale;
    final topLeft = Offset(clip.x, clip.y) * view.scale + view.panOffset;
    final boxWidth = clip.width * effectiveScale;
    final locked = clip.sizeLockScale != null;
    final toolbarWidth = TextClipEditOverlay.toolbarWidthFor(clip, view);
    final highlightPickerOpen = ref.watch(highlightPickerOpenProvider);
    final textStyle = TextNoteGeometry.baseStyle(
      fontSize: (clip.fontSize ?? kTextNoteFontSize) * effectiveScale,
      color: AppTheme.textNoteText,
    );
    final innerWidth =
        boxWidth - 2 * kTextNoteHorizontalPadding * effectiveScale;
    // The live TextField's real RenderEditable lays text out
    // kTextCaretReservedWidth narrower than innerWidth (reserved for the
    // cursor - see that constant's doc comment) - HighlightGeometry's
    // bare TextPainter must match that same narrower width, or its rects
    // land where the (wider, uncorrected) layout would have wrapped
    // instead of where the real TextField actually does.
    final highlightRects = HighlightGeometry.rectsFor(
      text: _controller!.text,
      formatting: _controller!.formatting,
      baseStyle: textStyle,
      width: innerWidth - kTextCaretReservedWidth,
      cornerRadius: kHighlightCornerRadius * effectiveScale,
    );

    _scheduleHeightSync(editingId, effectiveScale);

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: topLeft.dx,
            top: topLeft.dy,
            width: boxWidth,
            // No height - the TextField below sizes itself intrinsically
            // to exactly fit its content (see build()'s class-level doc
            // comment / Part 36), so this box's height is never a
            // prediction, only ever whatever Flutter's own layout
            // actually produces.
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
                key: _boxKey,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kCornerRadius),
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
                    // passthrough, not loose: the incoming constraints
                    // here are tight-width (from the outer Positioned's
                    // `width:`) and loose-height (from that Positioned's
                    // now-absent `height:`) - passthrough forwards both
                    // unmodified to the TextField below, so it keeps
                    // filling the box horizontally while sizing itself
                    // intrinsically to its content vertically. StackFit
                    // .loose would loosen the width too, shrink-wrapping
                    // the field to its longest line instead of filling
                    // the box; StackFit.expand would force an infinite
                    // height (the incoming max is now unbounded) and
                    // crash.
                    fit: StackFit.passthrough,
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
                      MediaQuery.withNoTextScaling(
                        // TextField has no textScaler constructor param of
                        // its own (unlike EditableText/Text) - it always
                        // resolves scaling from the ambient MediaQuery, so
                        // forcing it here is the only way to keep this in
                        // step with TextNoteGeometry.requiredHeight's bare,
                        // context-free TextPainter (which already defaults
                        // to no scaling) regardless of the device's OS-level
                        // accessibility text-scale setting.
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          minLines: 1,
                          // Pinned explicitly (not relying on the
                          // framework default, even though it happens to
                          // already be 2.0) so kTextCaretReservedWidth has
                          // a concrete, documented value to match - see
                          // that constant's doc comment.
                          cursorWidth: 2.0,
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
                            // No height recompute here - the TextField above
                            // has an unbounded height and sizes itself to
                            // exactly fit its own content on its own, with
                            // zero help from this callback (see build()'s
                            // doc comment / Part 36). _scheduleHeightSync
                            // (called at the end of every build()) reads
                            // back whatever Flutter's own layout produced
                            // after this frame and persists it if it
                            // changed. setState is still needed, though not
                            // for layout: it refreshes highlightRects and
                            // the toolbar's bold/italic/underline "active"
                            // indicators, both computed fresh in build()
                            // from the controller's current text/formatting.
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (highlightPickerOpen)
            Positioned(
              left: topLeft.dx,
              top: TextClipEditOverlay.highlightPickerTopFor(topLeft.dy),
              width: toolbarWidth,
              height: TextClipEditOverlay.highlightPickerHeight,
              child: Material(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(kCornerRadius),
                elevation: 6,
                shadowColor: Colors.black54,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: InlineHsvPickerBar(
                    initialColor: hexToColor(
                      clip.highlightColorHex ?? kDefaultHighlightColorHex,
                    ),
                    onChanged: (color) => _applyHighlightColorLive(clip, color),
                    onDone: () => _toggleHighlightPicker(clip),
                  ),
                ),
              ),
            ),
          Positioned(
            left: topLeft.dx,
            top: TextClipEditOverlay.topFor(topLeft.dy),
            width: toolbarWidth,
            height: TextClipEditOverlay.toolbarHeight,
            child: Material(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(kCornerRadius),
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
                      GestureDetector(
                        onTap: () => _toggleHighlightPicker(clip),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: hexToColor(
                                clip.highlightColorHex ??
                                    kDefaultHighlightColorHex,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.border,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
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
