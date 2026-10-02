import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../data/models/clip.dart';

/// Pure logic for toggling bold/italic/strikethrough over character ranges
/// of a text clip's content, and flattening the result into paintable
/// spans - no widget imports, unit-tested directly (see
/// test/features/board/text_style_ranges_test.dart). Same
/// one-class-per-concern convention as `SnapGeometry`/`MasonryLayout`, even
/// though this is interval logic rather than 2D geometry.
class TextStyleRanges {
  TextStyleRanges._();

  static List<IntRange> _normalize(List<IntRange> ranges) {
    final sorted = ranges.where((r) => r.end > r.start).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final result = <IntRange>[];
    for (final r in sorted) {
      if (result.isNotEmpty && r.start <= result.last.end) {
        final last = result.removeLast();
        result.add((start: last.start, end: math.max(last.end, r.end)));
      } else {
        result.add(r);
      }
    }
    return result;
  }

  /// Whether every character in `[start, end)` is covered by some range in
  /// [ranges].
  static bool isFullyCovered(List<IntRange> ranges, int start, int end) {
    if (end <= start) return true;
    var pos = start;
    for (final r in _normalize(ranges)) {
      if (r.end <= pos) continue;
      if (r.start > pos) return false;
      pos = math.max(pos, r.end);
      if (pos >= end) return true;
    }
    return pos >= end;
  }

  static List<IntRange> _subtract(List<IntRange> ranges, int start, int end) {
    final result = <IntRange>[];
    for (final r in _normalize(ranges)) {
      if (r.end <= start || r.start >= end) {
        result.add(r);
        continue;
      }
      if (r.start < start) result.add((start: r.start, end: start));
      if (r.end > end) result.add((start: end, end: r.end));
    }
    return result;
  }

  /// Standard word-processor toggle: if `[start, end)` is already fully
  /// covered by [ranges], removes it (splitting a covering range into 0, 1,
  /// or 2 pieces as needed); otherwise adds it, merging with any
  /// overlapping/adjacent ranges. Returns a normalized (sorted, merged,
  /// non-overlapping) list either way.
  static List<IntRange> toggle(List<IntRange> ranges, int start, int end) {
    if (end <= start) return _normalize(ranges);
    if (isFullyCovered(ranges, start, end)) {
      return _subtract(ranges, start, end);
    }
    return _normalize([...ranges, (start: start, end: end)]);
  }

  /// Describes the edit that turns [oldText] into [newText] as a minimal
  /// (position, deletedLength, insertedLength) triple, found via common
  /// prefix/suffix - the standard "diff" a plain `TextEditingController`
  /// needs to track for a single edit (typing, backspacing, pasting,
  /// cutting, or a select-and-replace), without having to separately track
  /// the previous selection/cursor position.
  static ({int start, int deletedLength, int insertedLength}) diffText(
    String oldText,
    String newText,
  ) {
    final maxPrefix = math.min(oldText.length, newText.length);
    var prefix = 0;
    while (prefix < maxPrefix && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var oldEnd = oldText.length;
    var newEnd = newText.length;
    while (oldEnd > prefix &&
        newEnd > prefix &&
        oldText[oldEnd - 1] == newText[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    return (
      start: prefix,
      deletedLength: oldEnd - prefix,
      insertedLength: newEnd - prefix,
    );
  }

  /// Maps a single character offset through an edit at [editStart] that
  /// deletes [deletedLength] characters and inserts [insertedLength] new
  /// ones - the building block [shiftRanges] applies to both ends of every
  /// range. An offset before the edit is untouched; one at or after the
  /// deleted span shifts by the edit's net length change; one that fell
  /// strictly inside the deleted span collapses to the edit point. Using
  /// the same rule for both a range's start and its end (rather than
  /// special-casing which end "wins" a tie at the boundary) happens to
  /// give the intuitive behavior for free: typing right at the start of a
  /// formatted run shifts the run later (new text isn't prepended into
  /// it), while typing right at its end extends the run to include the
  /// new text (continuing to type stays bold) - both without this
  /// function needing to know it's looking at a "start" or an "end".
  static int _mapOffset(
    int x,
    int editStart,
    int deletedLength,
    int insertedLength,
  ) {
    final deleteEnd = editStart + deletedLength;
    if (x < editStart) return x;
    if (x >= deleteEnd) return x + (insertedLength - deletedLength);
    return editStart;
  }

  /// Re-maps every range in [ranges] through the same edit [diffText]
  /// describes, so formatting stays attached to the same characters after
  /// the user types/deletes/pastes anywhere in the text - without this,
  /// a range's stored indices go stale the moment any edit happens before
  /// or inside it, covering the wrong characters from then on (the bug
  /// this exists to fix). Ranges fully inside the deleted span collapse
  /// to zero length and are dropped; the rest come back normalized.
  static List<IntRange> shiftRanges(
    List<IntRange> ranges,
    int editStart,
    int deletedLength,
    int insertedLength,
  ) {
    final shifted = <IntRange>[];
    for (final r in ranges) {
      final start = _mapOffset(
        r.start,
        editStart,
        deletedLength,
        insertedLength,
      );
      final end = _mapOffset(r.end, editStart, deletedLength, insertedLength);
      if (end > start) shifted.add((start: start, end: end));
    }
    return _normalize(shifted);
  }

  /// [shiftRanges] applied to all 4 of [formatting]'s independent range
  /// lists at once - the whole-formatting counterpart callers reach for
  /// after a text edit.
  static TextFormatting shiftFormatting(
    TextFormatting formatting,
    int editStart,
    int deletedLength,
    int insertedLength,
  ) {
    List<IntRange> shift(List<IntRange> ranges) =>
        shiftRanges(ranges, editStart, deletedLength, insertedLength);
    return TextFormatting(
      bold: shift(formatting.bold),
      italic: shift(formatting.italic),
      underline: shift(formatting.underline),
      strikethrough: shift(formatting.strikethrough),
      highlight: shift(formatting.highlight),
    );
  }

  /// Flattens [formatting]'s 5 independent range lists into a sequence of
  /// non-overlapping [TextSpan]s over [text], each combining [base] with
  /// whichever of bold/italic/underline/strikethrough/highlight cover that
  /// run - underline and strikethrough combine via `TextDecoration.combine`
  /// when both apply to the same run; [highlightColor] paints behind any
  /// run covered by `formatting.highlight` via `TextStyle.backgroundColor`.
  static List<TextSpan> buildSpans(
    String text,
    TextFormatting formatting,
    TextStyle base, {
    Color? highlightColor,
  }) {
    if (text.isEmpty) return [TextSpan(text: text, style: base)];

    final boundaries = <int>{0, text.length};
    for (final r in [
      ...formatting.bold,
      ...formatting.italic,
      ...formatting.underline,
      ...formatting.strikethrough,
      ...formatting.highlight,
    ]) {
      boundaries.add(r.start.clamp(0, text.length));
      boundaries.add(r.end.clamp(0, text.length));
    }
    final sorted = boundaries.toList()..sort();

    final spans = <TextSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (a >= b) continue;
      final bold = isFullyCovered(formatting.bold, a, a + 1);
      final italic = isFullyCovered(formatting.italic, a, a + 1);
      final underline = isFullyCovered(formatting.underline, a, a + 1);
      final strike = isFullyCovered(formatting.strikethrough, a, a + 1);
      final highlighted = isFullyCovered(formatting.highlight, a, a + 1);
      spans.add(
        TextSpan(
          text: text.substring(a, b),
          style: base.copyWith(
            fontWeight: bold ? FontWeight.bold : null,
            fontStyle: italic ? FontStyle.italic : null,
            decoration: (underline || strike)
                ? TextDecoration.combine([
                    if (underline) TextDecoration.underline,
                    if (strike) TextDecoration.lineThrough,
                  ])
                : null,
            backgroundColor: highlighted ? highlightColor : null,
          ),
        ),
      );
    }
    return spans;
  }
}
