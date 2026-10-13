import 'package:flutter/rendering.dart';

import '../../../data/local/database.dart' show FrameRow;
import '../../../data/models/clip.dart';
import 'frame_geometry.dart';
import 'page_crop_settings.dart' show kOverviewPageCropKey;
import 'selection_geometry.dart';

/// One exported PDF page's worth of content: a label for the wizard's UI,
/// a stable key into the wizard's per-page crop settings (a frame's own
/// id, or [kOverviewPageCropKey] for the leading overview page - exactly
/// the keys `pdf_writer.dart`'s `pageCrops` map already uses), the
/// board-space rect this page covers, its background color (a frame's own
/// custom color, or null for the overview page / an uncolored frame), and
/// every clip - regardless of `frameId` - whose rect overlaps [rect].
class PdfExportPage {
  final String label;
  final String cropKey;
  final Rect rect;
  final String? backgroundColorHex;
  final List<BoardClip> clips;

  const PdfExportPage({
    required this.label,
    required this.cropKey,
    required this.rect,
    required this.backgroundColorHex,
    required this.clips,
  });
}

/// Groups [clips] into one [PdfExportPage] per [frame] (in the given
/// order), plus - if any clips aren't captured by any frame's area - one
/// leading "Overview" page covering just the leftovers' own bounding box.
///
/// A clip's `frameId` is NOT the inclusion rule here (unlike the old
/// per-page logic this replaces) - a page's clips are whatever clips'
/// board rects overlap that page's own rect (`ClipGeometry
/// .marqueeIntersects` - the same AABB-overlap test live marquee
/// selection already uses, rotation deliberately ignored). This means:
/// - A loose clip sitting on/near a frame now renders on THAT frame's
///   page (and any connector to a real frame child survives, since both
///   endpoints are now on the same page) instead of being silently
///   shunted to a separate, disconnected overview page.
/// - A clip overlapping two different exported frames' rects legitimately
///   renders on both pages - the same "shared content can appear on more
///   than one page" behavior `_buildPage` already has for freestanding
///   strokes, now extended consistently to clips too.
/// - The overview page only ever contains clips NOT already placed on any
///   frame page, so a clip already fully inside a frame's page doesn't
///   also get a pointless, confusing duplicate full page of its own.
/// - With zero frames, every clip in scope becomes one leading overview
///   page covering their shared bounding box - the "export a loose
///   multi-select, no frame involved" case.
List<PdfExportPage> buildPdfExportPages({
  required List<FrameRow> frames,
  required List<BoardClip> clips,
}) {
  final framePages = <PdfExportPage>[];
  final placedClipIds = <String>{};

  for (final frame in frames) {
    final rect = FrameGeometry.boardRect(frame);
    final members = [
      for (final c in clips)
        if (ClipGeometry.marqueeIntersects(rect, c)) c,
    ]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    placedClipIds.addAll(members.map((c) => c.id));
    framePages.add(
      PdfExportPage(
        label: frame.name,
        cropKey: frame.id,
        rect: rect,
        backgroundColorHex: frame.backgroundColorHex,
        clips: members,
      ),
    );
  }

  final leftover = [
    for (final c in clips)
      if (!placedClipIds.contains(c.id)) c,
  ]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  final pages = <PdfExportPage>[];
  if (leftover.isNotEmpty) {
    pages.add(
      PdfExportPage(
        label: 'Overview',
        cropKey: kOverviewPageCropKey,
        rect: ClipGeometry.boardBoundingBox(leftover),
        backgroundColorHex: null,
        clips: leftover,
      ),
    );
  }
  pages.addAll(framePages);
  return pages;
}
