import '../../../data/local/database.dart' show FrameRow;
import '../../../data/models/clip.dart';
import '../../../data/models/connector.dart';
import '../../../data/models/stroke.dart';

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
/// export should contain:
/// - A selected frame (`selectedFrameIds`) brings ALL its children
///   (every clip with `clip.frameId == frame.id`), unconditionally -
///   same all-or-nothing semantics every other frame operation
///   (delete, duplicate, move) already has.
/// - A selected clip (`selectedClipIds`) that lives inside a frame NOT
///   itself in `selectedFrameIds` is dropped entirely - frame-content
///   inclusion is driven only by `selectedFrameIds`, never a loose
///   clip-level override.
/// - A selected clip with no frame (`frameId == null`) is kept as a
///   loose/overview-page clip, same as today's "every loose clip" rule,
///   just filtered to the selection.
/// - `strokes`/`connectors` are NOT filtered here - `writePdfFile`/
///   `_buildPage` already derives which strokes/connectors are
///   "relevant" per page from the page's own clip set (and, for
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
  final selectedFrameIdSet = selectedFrames.map((f) => f.id).toSet();

  final exportClips = <BoardClip>[];
  for (final c in clips) {
    if (c.frameId != null) {
      if (selectedFrameIdSet.contains(c.frameId)) exportClips.add(c);
    } else if (selectedClipIds.contains(c.id)) {
      exportClips.add(c);
    }
  }

  return PdfExportSelection(
    frames: selectedFrames,
    clips: exportClips,
    strokes: strokes,
    connectors: connectors,
  );
}
