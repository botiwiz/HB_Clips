import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../data/models/clip.dart';
import 'text_style_ranges.dart';

/// Pure geometry backing rounded-corner text highlights. `TextStyle
/// .backgroundColor` (the built-in way to paint a background behind a
/// `TextSpan`) only ever draws a plain rectangle - there's no way to round
/// its corners - so a highlighted run's background is instead painted as a
/// separate layer of [RRect]s, computed here by laying out an identical,
/// un-painted [TextPainter] purely to ask it where each highlighted range's
/// glyphs land (`getBoxesForSelection`), then rounding each box's corners.
/// Screen-space in, screen-space out, same convention as every other
/// geometry class that works in already-scaled coordinates at paint time
/// (not board-space).
class HighlightGeometry {
  HighlightGeometry._();

  /// One [RRect] (rounded by [cornerRadius]) per line a highlighted range
  /// spans, in the same coordinate space the caller's actual `Text.rich`/
  /// `TextField` paints its glyphs in - correct as long as [baseStyle] and
  /// [width] exactly match what that caller lays its own text out with
  /// (same font size/line height, same wrapping width).
  static List<RRect> rectsFor({
    required String text,
    required TextFormatting formatting,
    required TextStyle baseStyle,
    required double width,
    required double cornerRadius,
  }) {
    if (formatting.highlight.isEmpty || text.isEmpty) return [];
    final painter = TextPainter(
      text: TextSpan(
        children: TextStyleRanges.buildSpans(text, formatting, baseStyle),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width < 1 ? 1 : width);

    final rects = <RRect>[];
    for (final range in formatting.highlight) {
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      for (final box in boxes) {
        rects.add(
          RRect.fromRectAndRadius(box.toRect(), Radius.circular(cornerRadius)),
        );
      }
    }
    return rects;
  }
}
