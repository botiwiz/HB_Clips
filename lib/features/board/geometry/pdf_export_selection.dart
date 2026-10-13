import 'package:flutter/rendering.dart';

import '../../../data/local/database.dart' show FrameRow;
import '../../../data/models/clip.dart';
import '../../../data/models/connector.dart';
import '../../../data/models/stroke.dart';
import 'frame_geometry.dart';
import 'selection_geometry.dart';

/// The exact subset of the board to hand to `writePdfFile` for a
/// selection-only export - see [resolveExportSelection]'s doc comment
/// for the inclusion rule.
class PdfExportSelection {
  final List<FrameRow> frames;
  final List<BoardClip> clips;
  final List<Stroke> strokes;
  final List<Connector> connectors;

  const PdfExportSelection({
    required this.frames,
    required this.clips,
    required this.strokes,
    required this.connectors,
  });

  bool get isEmpty => frames.isEmpty && clips.isEmpty;
}

/// Filters the full board down to exactly what a selection-only PDF
/// export should contain, by SCREEN AREA rather than parentage:
/// - A selected frame (`selectedFrameIds`) contributes its own board rect
///   as one "target rect" of the export.
/// - Any explicitly multi-selected clips (`selectedClipIds`) together
///   contribute one more target rect - the bounding box of just those
///   clips - regardless of whether any of them happen to have a
///   `frameId` or not.
/// - A clip is included in the export if its own board rect overlaps
///   ANY target rect (`ClipGeometry.marqueeIntersects` - the same
///   AABB-overlap test live marquee selection already uses) - whether or
///   not that clip was itself selected, and whether or not it's parented
///   to a selected frame. This is what lets a clip that was never grouped
///   into a frame (e.g. a callout text note just placed near it, not
///   dragged into it) still export as part of that frame's area, exactly
///   as it appears on the live board - the direct fix for a real report
///   where such a clip, and its connector to a real frame child, were
///   both silently dropped from the export.
/// - A clip explicitly selected but sitting inside an UNselected frame is
///   now included too (its own rect still counts as part of "the
///   selection's screen area") - a deliberate change from this
///   function's old frameId-membership-only rule, which used to drop it
///   silently.
/// - `strokes`/`connectors` are NOT filtered here - `writePdfFile`/
///   `_buildPage` already derives which strokes/connectors are
///   "relevant" per page from that page's own clip set (and, for
///   strokes, board rect), so both full lists are passed through
///   unfiltered and that existing logic does the rest.
PdfExportSelection resolveExportSelection({
  required Set<String> selectedFrameIds,
  required Set<String> selectedClipIds,
  required List<FrameRow> frames,
  required List<BoardClip> clips,
  required List<Stroke> strokes,
  required List<Connector> connectors,
}) {
  final selectedFrames = [
    for (final f in frames)
      if (selectedFrameIds.contains(f.id)) f,
  ];
  final explicitlySelectedClips = [
    for (final c in clips)
      if (selectedClipIds.contains(c.id)) c,
  ];

  final targetRects = <Rect>[
    for (final f in selectedFrames) FrameGeometry.boardRect(f),
    if (explicitlySelectedClips.isNotEmpty)
      ClipGeometry.boardBoundingBox(explicitlySelectedClips),
  ];

  final exportClips = targetRects.isEmpty
      ? const <BoardClip>[]
      : [
          for (final c in clips)
            if (targetRects.any((r) => ClipGeometry.marqueeIntersects(r, c))) c,
        ];

  return PdfExportSelection(
    frames: selectedFrames,
    clips: exportClips,
    strokes: strokes,
    connectors: connectors,
  );
}
