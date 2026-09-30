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

  /// Flattens [formatting]'s 3 independent range lists into a sequence of
  /// non-overlapping [TextSpan]s over [text], each combining [base] with
  /// whichever of bold/italic/strikethrough cover that run.
  static List<TextSpan> buildSpans(
    String text,
    TextFormatting formatting,
    TextStyle base,
  ) {
    if (text.isEmpty) return [TextSpan(text: text, style: base)];

    final boundaries = <int>{0, text.length};
    for (final r in [
      ...formatting.bold,
      ...formatting.italic,
      ...formatting.strikethrough,
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
      final strike = isFullyCovered(formatting.strikethrough, a, a + 1);
      spans.add(
        TextSpan(
          text: text.substring(a, b),
          style: base.copyWith(
            fontWeight: bold ? FontWeight.bold : null,
            fontStyle: italic ? FontStyle.italic : null,
            decoration: strike ? TextDecoration.lineThrough : null,
          ),
        ),
      );
    }
    return spans;
  }
}
