import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/board/geometry/frame_geometry.dart';
import '../../features/board/geometry/image_pan_zoom_geometry.dart';
import '../../features/board/geometry/selection_geometry.dart';
import '../local/database.dart' show FrameRow;
import '../models/clip.dart';
import '../models/stroke.dart';

/// How many pages/images made it into the exported PDF.
class PdfExportSummary {
  final int framePages;
  final bool hasOverviewPage;
  final int imagesDrawn;
  final int imagesSkipped;

  const PdfExportSummary({
    required this.framePages,
    required this.hasOverviewPage,
    required this.imagesDrawn,
    required this.imagesSkipped,
  });
}

class PdfWriteResult {
  final Uint8List bytes;
  final PdfExportSummary summary;
  const PdfWriteResult(this.bytes, this.summary);
}

class _PageResult {
  final int drawn;
  final int skipped;
  const _PageResult(this.drawn, this.skipped);
}

/// Writes the board out as a multi-page PDF - one page per frame, plus a
/// leading "overview" page for any clips not parented to a frame. The key
/// design choice: **1 board unit = 1 PDF point**, so a frame's own
/// `width`/`height` becomes that page's exact `PdfPageFormat` with zero
/// scaling - a frame set to an A4 preset (`frame_presets.dart`) exports as a
/// literal, exact A4 page.
///
/// No rasterization infrastructure exists in this codebase, so every clip
/// is drawn fresh from its stored board-space geometry rather than
/// screenshotting the on-screen widget tree. [readBytes] resolves a
/// clip's `localFilePath` to its raw bytes.
///
/// Returns null (nothing to export) if the board has zero frames and zero
/// clips.
Future<PdfWriteResult?> writePdfFile({
  required List<FrameRow> frames,
  required List<BoardClip> clips,
  required List<Stroke> strokes,
  required Future<Uint8List?> Function(String key) readBytes,
}) async {
  if (frames.isEmpty && clips.isEmpty) return null;

  final doc = pw.Document();
  var imagesDrawn = 0;
  var imagesSkipped = 0;

  final looseClips = clips.where((c) => c.frameId == null).toList()
    ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  var hasOverview = false;
  if (looseClips.isNotEmpty) {
    hasOverview = true;
    final rect = ClipGeometry.boardBoundingBox(looseClips);
    final result = await _buildPage(
      doc: doc,
      origin: rect.topLeft,
      size: rect.size,
      backgroundColorHex: null,
      clips: looseClips,
      strokes: strokes,
      readBytes: readBytes,
    );
    imagesDrawn += result.drawn;
    imagesSkipped += result.skipped;
  }

  for (final frame in frames) {
    final frameRect = FrameGeometry.boardRect(frame);
    final children = clips.where((c) => c.frameId == frame.id).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final result = await _buildPage(
      doc: doc,
      origin: frameRect.topLeft,
      size: frameRect.size,
      backgroundColorHex: frame.backgroundColorHex,
      clips: children,
      strokes: strokes,
      readBytes: readBytes,
    );
    imagesDrawn += result.drawn;
    imagesSkipped += result.skipped;
  }

  return PdfWriteResult(
    await doc.save(),
    PdfExportSummary(
      framePages: frames.length,
      hasOverviewPage: hasOverview,
      imagesDrawn: imagesDrawn,
      imagesSkipped: imagesSkipped,
    ),
  );
}

Future<_PageResult> _buildPage({
  required pw.Document doc,
  required Offset origin,
  required Size size,
  required String? backgroundColorHex,
  required List<BoardClip> clips,
  required List<Stroke> strokes,
  required Future<Uint8List?> Function(String key) readBytes,
}) async {
  var drawn = 0;
  var skipped = 0;

  final pageRect = Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
  final clipIds = clips.map((c) => c.id).toSet();
  final relevantStrokes = strokes.where((s) {
    if (s.clipId != null) return clipIds.contains(s.clipId);
    return s.points.any(pageRect.contains);
  }).toList();

  final pageChildren = <pw.Widget>[];
  if (backgroundColorHex != null) {
    pageChildren.add(
      pw.Positioned.fill(
        child: pw.Container(color: PdfColor.fromHex(backgroundColorHex)),
      ),
    );
  }

  for (final clip in clips) {
    pw.Widget? content;
    if (clip.type == ClipType.text) {
      content = _buildTextWidget(clip);
    } else {
      content = await _buildImageWidget(clip, readBytes);
      if (content == null) {
        skipped++;
        continue;
      }
      drawn++;
    }

    final clipStrokes = relevantStrokes
        .where((s) => s.clipId == clip.id)
        .toList();

    final body = pw.Stack(
      children: [
        pw.SizedBox(width: clip.width, height: clip.height, child: content),
        if (clipStrokes.isNotEmpty)
          pw.Positioned.fill(
            child: pw.CustomPaint(
              size: PdfPoint(clip.width, clip.height),
              painter: (PdfGraphics canvas, PdfPoint size) {
                for (final stroke in clipStrokes) {
                  _paintStroke(
                    canvas,
                    stroke,
                    stroke.points
                        .map(
                          (p) => Offset(p.dx * clip.width, p.dy * clip.height),
                        )
                        .toList(),
                  );
                }
              },
            ),
          ),
      ],
    );

    pageChildren.add(
      pw.Positioned(
        left: clip.x - origin.dx,
        top: clip.y - origin.dy,
        child: pw.Transform.rotate(
          angle: clip.rotation,
          child: pw.SizedBox(
            width: clip.width,
            height: clip.height,
            child: body,
          ),
        ),
      ),
    );
  }

  final freestandingStrokes = relevantStrokes
      .where((s) => s.clipId == null)
      .toList();
  if (freestandingStrokes.isNotEmpty) {
    pageChildren.add(
      pw.Positioned.fill(
        child: pw.CustomPaint(
          size: PdfPoint(size.width, size.height),
          painter: (PdfGraphics canvas, PdfPoint size) {
            for (final stroke in freestandingStrokes) {
              _paintStroke(
                canvas,
                stroke,
                stroke.points.map((p) => p - origin).toList(),
              );
            }
          },
        ),
      ),
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(size.width, size.height),
      margin: pw.EdgeInsets.zero,
      clip: true,
      build: (context) => pw.Stack(children: pageChildren),
    ),
  );

  return _PageResult(drawn, skipped);
}

pw.Widget _buildTextWidget(BoardClip clip) => pw.Container(
  decoration: pw.BoxDecoration(
    color: clip.backgroundColorHex != null
        ? PdfColor.fromHex(clip.backgroundColorHex!)
        : null,
    border: pw.Border.all(color: PdfColor.fromHex('#3A3A40'), width: 1),
    borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
  ),
  padding: const pw.EdgeInsets.all(10),
  child: pw.Text(
    clip.textContent ?? '',
    style: pw.TextStyle(color: PdfColors.white, fontSize: 14),
  ),
);

/// Inverts `ImagePanZoomFrame`'s on-screen `OverflowBox`/`Alignment`
/// composition into an actual source-pixel crop, since a PDF needs real
/// cropped bytes rather than a live overflow box. Reuses
/// [ImagePanZoomGeometry]'s cover/zoom math verbatim so this always agrees
/// with what the clip looks like on screen.
Future<pw.Widget?> _buildImageWidget(
  BoardClip clip,
  Future<Uint8List?> Function(String key) readBytes,
) async {
  final path = clip.localFilePath;
  if (path == null) return null;

  final Uint8List? bytes;
  try {
    bytes = await readBytes(path);
  } catch (_) {
    return null;
  }
  if (bytes == null) return null;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final nativeW = decoded.width.toDouble();
  final nativeH = decoded.height.toDouble();
  final r = clip.imageAspectRatio ?? (clip.width / clip.height);
  final zoom = ImagePanZoomGeometry.clampZoom(clip.imageZoom);
  final cover = ImagePanZoomGeometry.coverSize(clip.width, clip.height, r);
  final scaled = ImagePanZoomGeometry.scaledSize(cover, zoom);
  final pxPerUnitX = nativeW / cover.width;
  final pxPerUnitY = nativeH / cover.height;

  final cropW = (clip.width * pxPerUnitX).clamp(0.0, nativeW);
  final cropH = (clip.height * pxPerUnitY).clamp(0.0, nativeH);
  final overflowX = (scaled.width - clip.width).clamp(0.0, double.infinity);
  final overflowY = (scaled.height - clip.height).clamp(0.0, double.infinity);
  final visibleLeftInScaled = (overflowX / 2) * (1 + clip.imagePanX);
  final visibleTopInScaled = (overflowY / 2) * (1 + clip.imagePanY);
  final cropX = (visibleLeftInScaled / zoom * pxPerUnitX).clamp(
    0.0,
    nativeW - cropW,
  );
  final cropY = (visibleTopInScaled / zoom * pxPerUnitY).clamp(
    0.0,
    nativeH - cropH,
  );

  final cropWidth = cropW.round().clamp(1, nativeW.round());
  final cropHeight = cropH.round().clamp(1, nativeH.round());

  final img.Image cropped;
  try {
    cropped = img.copyCrop(
      decoded,
      x: cropX.round(),
      y: cropY.round(),
      width: cropWidth,
      height: cropHeight,
    );
  } catch (_) {
    return null;
  }

  return pw.ClipRect(
    child: pw.Image(
      pw.MemoryImage(img.encodePng(cropped)),
      fit: pw.BoxFit.fill,
      width: clip.width,
      height: clip.height,
    ),
  );
}

void _paintStroke(PdfGraphics canvas, Stroke stroke, List<Offset> points) {
  if (points.length < 2) return;
  final color = PdfColor.fromHex(stroke.colorHex);
  canvas
    ..setColor(color)
    ..setStrokeColor(color)
    ..setLineWidth(stroke.strokeWidth);

  if (stroke.dashed) {
    _drawDashed(canvas, points);
  } else {
    canvas.moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      canvas.lineTo(p.dx, p.dy);
    }
    canvas.strokePath();
  }

  if (stroke.arrowEnd) {
    _drawArrowHead(canvas, points, stroke.strokeWidth);
  }
}

/// `StrokePainter`'s Flutter-`PathMetric`-based dashing has no `PdfGraphics`
/// equivalent, so it's ported here as manual polyline arc-length walking.
Offset _pointAtDistance(List<Offset> points, double distance) {
  var remaining = distance;
  for (var i = 0; i < points.length - 1; i++) {
    final segLen = (points[i + 1] - points[i]).distance;
    if (remaining <= segLen) {
      return Offset.lerp(
        points[i],
        points[i + 1],
        segLen == 0 ? 0.0 : remaining / segLen,
      )!;
    }
    remaining -= segLen;
  }
  return points.last;
}

void _drawDashed(PdfGraphics canvas, List<Offset> points) {
  const dashLength = 8.0;
  const gapLength = 6.0;
  final totalLength = [
    for (var i = 0; i < points.length - 1; i++)
      (points[i + 1] - points[i]).distance,
  ].fold(0.0, (a, b) => a + b);

  var distance = 0.0;
  while (distance < totalLength) {
    final end = (distance + dashLength).clamp(0.0, totalLength);
    final start = _pointAtDistance(points, distance);
    canvas.moveTo(start.dx, start.dy);
    var walked = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final segLen = (points[i + 1] - points[i]).distance;
      final vertexDist = walked + segLen;
      if (vertexDist > distance && vertexDist < end) {
        canvas.lineTo(points[i + 1].dx, points[i + 1].dy);
      }
      walked = vertexDist;
    }
    final stop = _pointAtDistance(points, end);
    canvas.lineTo(stop.dx, stop.dy);
    canvas.strokePath();
    distance = end + gapLength;
  }
}

void _drawArrowHead(PdfGraphics canvas, List<Offset> points, double width) {
  final tip = points.last;
  final from = points[points.length - 2];
  final direction = tip - from;
  if (direction.distance == 0) return;
  final angle = direction.direction;
  final headLength = 8.0 + width * 2;
  const spreadAngle = 0.5;
  for (final sign in [-1, 1]) {
    final wingEnd =
        tip + Offset.fromDirection(angle + pi + sign * spreadAngle, headLength);
    canvas
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(wingEnd.dx, wingEnd.dy)
      ..strokePath();
  }
}
