import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants.dart'
    show
        kBoardGridSpacing,
        kDefaultHighlightColorHex,
        kHighlightCornerRadius,
        kTextCaretReservedWidth,
        kTextNoteFontSize,
        kTextNotePadding;
import '../../core/theme/app_theme.dart' show AppTheme;
import '../../features/annotation/controllers/annotation_controller.dart'
    show kDefaultStrokeWidth;
import '../../features/annotation/stroke_painter.dart' show hexToColor;
import '../../features/board/geometry/connector_geometry.dart';
import '../../features/board/geometry/frame_geometry.dart';
import '../../features/board/geometry/highlight_geometry.dart';
import '../../features/board/geometry/image_pan_zoom_geometry.dart';
import '../../features/board/geometry/page_crop_settings.dart';
import '../../features/board/geometry/selection_geometry.dart';
import '../../features/board/geometry/shape_geometry.dart';
import '../../features/board/geometry/text_note_geometry.dart';
import '../../features/board/geometry/text_style_ranges.dart';
import '../local/database.dart' show FrameRow;
import '../models/clip.dart';
import '../models/connector.dart';
import '../models/stroke.dart';

/// The app's own dark-grey canvas background (`AppTheme.canvasBackground`)
/// and dot-grid color (`AppTheme.gridDot`, same value as `AppTheme.border`)
/// - duplicated here as hex literals rather than importing `core/theme`,
/// matching this file's existing convention (`_buildTextWidget`'s border
/// color below is the same literal, already hardcoded this way).
const String _kCanvasBackgroundHex = '#18181A';
const String _kGridDotHex = '#3A3A40';

/// How many pages/images made it into the exported PDF.
class PdfExportSummary {
  final int framePages;
  final bool hasOverviewPage;
  final int imagesDrawn;
  final int imagesSkipped;
  final List<String> skippedFileNames;

  const PdfExportSummary({
    required this.framePages,
    required this.hasOverviewPage,
    required this.imagesDrawn,
    required this.imagesSkipped,
    this.skippedFileNames = const [],
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
  final List<String> skippedFileNames;
  const _PageResult(this.drawn, this.skipped, this.skippedFileNames);
}

/// Writes the board out as a multi-page PDF - one page per frame, plus a
/// leading "overview" page for any clips not parented to a frame. The key
/// design choice: **1 board unit = 1 PDF point**, so a frame's own
/// `width`/`height` becomes that page's exact `PdfPageFormat` with zero
/// scaling - a frame set to an A4 preset (`frame_presets.dart`) exports as a
/// literal, exact A4 page.
///
/// Every clip is drawn fresh from its stored board-space geometry rather
/// than screenshotting the on-screen widget tree - except text notes,
/// which ARE rasterized (see [rasterizeTextClip]) using the app's own
/// real text-rendering code, since `package:pdf`'s own text system uses a
/// different font with no shared styling/highlight support. [readBytes]
/// resolves a clip's `localFilePath` to its raw bytes.
///
/// Returns null (nothing to export) if the board has zero frames and zero
/// clips.
Future<PdfWriteResult?> writePdfFile({
  required List<FrameRow> frames,
  required List<BoardClip> clips,
  required List<Stroke> strokes,
  required Future<Uint8List?> Function(String key) readBytes,
  PdfPageFormat? pageFormat,
  Map<String, PageCropSettings>? pageCrops,
  List<Connector> connectors = const [],
}) async {
  if (frames.isEmpty && clips.isEmpty) return null;

  final doc = pw.Document();
  var imagesDrawn = 0;
  var imagesSkipped = 0;
  final skippedFileNames = <String>[];

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
      pageSize: pageFormat == null
          ? rect.size
          : Size(pageFormat.width, pageFormat.height),
      crop: pageCrops?[kOverviewPageCropKey] ?? PageCropSettings.initial,
      backgroundColorHex: null,
      clips: looseClips,
      strokes: strokes,
      connectors: connectors,
      readBytes: readBytes,
    );
    imagesDrawn += result.drawn;
    imagesSkipped += result.skipped;
    skippedFileNames.addAll(result.skippedFileNames);
  }

  for (final frame in frames) {
    final frameRect = FrameGeometry.boardRect(frame);
    final children = clips.where((c) => c.frameId == frame.id).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final result = await _buildPage(
      doc: doc,
      origin: frameRect.topLeft,
      size: frameRect.size,
      pageSize: pageFormat == null
          ? frameRect.size
          : Size(pageFormat.width, pageFormat.height),
      crop: pageCrops?[frame.id] ?? PageCropSettings.initial,
      backgroundColorHex: frame.backgroundColorHex,
      clips: children,
      strokes: strokes,
      connectors: connectors,
      readBytes: readBytes,
    );
    imagesDrawn += result.drawn;
    imagesSkipped += result.skipped;
    skippedFileNames.addAll(result.skippedFileNames);
  }

  return PdfWriteResult(
    await doc.save(),
    PdfExportSummary(
      framePages: frames.length,
      hasOverviewPage: hasOverview,
      imagesDrawn: imagesDrawn,
      imagesSkipped: imagesSkipped,
      skippedFileNames: skippedFileNames,
    ),
  );
}

Future<_PageResult> _buildPage({
  required pw.Document doc,
  required Offset origin,
  required Size size,
  required Size pageSize,
  required PageCropSettings crop,
  required String? backgroundColorHex,
  required List<BoardClip> clips,
  required List<Stroke> strokes,
  required List<Connector> connectors,
  required Future<Uint8List?> Function(String key) readBytes,
}) async {
  var drawn = 0;
  var skipped = 0;
  final skippedFileNames = <String>[];

  final pageRect = Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
  final clipIds = clips.map((c) => c.id).toSet();
  final relevantStrokes = strokes.where((s) {
    if (s.clipId != null) return clipIds.contains(s.clipId);
    return s.points.any(pageRect.contains);
  }).toList();

  // Hoisted up front (only depends on the two parameters) so the dot-grid
  // gating below can know whether the extended, page-space grid layer
  // further down will take over - see that layer's own comment.
  final needsFit = pageSize != size;

  // Always fill the page - the app's own canvas color (+ dot grid) by
  // default, WYSIWYG with what's actually on screen, or the frame's own
  // custom color when it has one (in which case no grid is drawn over it,
  // matching the board's own "a custom frame color replaces the grid
  // visually" behavior).
  final pageChildren = <pw.Widget>[
    pw.Positioned.fill(
      child: pw.Container(
        color: PdfColor.fromHex(backgroundColorHex ?? _kCanvasBackgroundHex),
      ),
    ),
  ];
  if (backgroundColorHex == null && !needsFit) {
    pageChildren.add(
      pw.Positioned.fill(
        child: pw.CustomPaint(
          size: PdfPoint(size.width, size.height),
          painter: (PdfGraphics canvas, PdfPoint canvasSize) =>
              _drawDotGrid(canvas, origin, size),
        ),
      ),
    );
  }

  for (final clip in clips) {
    pw.Widget? content;
    if (clip.type == ClipType.text) {
      // No try/catch unlike the image branch below: there's no external-
      // file failure mode here (no I/O, no unparseable bytes) - a
      // failure would be a genuine engine-level error that should
      // surface as a crash, not silently vanish as a miscounted
      // "skipped image".
      final pngBytes = await rasterizeTextClip(clip);
      content = pw.Image(
        pw.MemoryImage(pngBytes),
        fit: pw.BoxFit.fill,
        width: clip.width,
        height: clip.height,
      );
    } else if (clip.type == ClipType.shape) {
      content = _buildShapeWidget(clip);
    } else {
      content = await _buildImageWidget(clip, readBytes);
      if (content == null) {
        skipped++;
        final path = clip.localFilePath;
        if (path != null) skippedFileNames.add(_basename(path));
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

  // Connectors painted on top of everything else above (clips,
  // per-clip/freestanding strokes) - mirrors ConnectorsOverlay's own
  // "always on top of every clip" stacking on the live board. Relevant
  // to this page exactly when BOTH of a connector's endpoint clips are
  // among this page's own clips - a connector whose endpoints span two
  // different pages (different frames, or a frame and a loose clip) has
  // nowhere sensible to render and is simply dropped, same "page-local
  // relevance" idea relevantStrokes already applies per-clip above.
  final relevantConnectors = connectors
      .where(
        (c) => clipIds.contains(c.fromClipId) && clipIds.contains(c.toClipId),
      )
      .toList();
  if (relevantConnectors.isNotEmpty) {
    pageChildren.add(
      pw.Positioned.fill(
        child: pw.CustomPaint(
          size: PdfPoint(size.width, size.height),
          painter: (PdfGraphics canvas, PdfPoint size) {
            for (final connector in relevantConnectors) {
              final fromClip = ClipGeometry.findById(
                clips,
                connector.fromClipId,
              );
              final toClip = ClipGeometry.findById(clips, connector.toClipId);
              if (fromClip == null || toClip == null) continue;
              final route = ConnectorGeometry.routeBoard(
                fromClip: fromClip,
                fromSide: connector.fromSide,
                toClip: toClip,
                toRelX: connector.toRelX,
                toRelY: connector.toRelY,
              );
              _paintConnector(
                canvas,
                connector,
                route.map((p) => p - origin).toList(),
              );
            }
          },
        ),
      ),
    );
  }

  // When a uniform pageSize was requested (the export wizard's chosen
  // resolution/orientation) and it doesn't match this page's own content
  // rect, cover-fit the content into pageSize (always fills it
  // completely, cropping overflow) with the user-adjustable [crop]
  // zoom/pan applied on top - reuses ImagePanZoomGeometry exactly like
  // _buildImageWidget already does for per-image crop, just treating
  // this whole page's content block as "the image" and pageSize as "the
  // frame". When pageSize == size (no pageFormat was requested, or it
  // happens to already match), skip the wrapper entirely so output
  // stays byte-identical to before this feature existed.
  final pw.Widget pageContent;
  if (!needsFit) {
    pageContent = pw.Stack(children: pageChildren);
  } else {
    final contentAspect = size.width / size.height;
    final cover = ImagePanZoomGeometry.coverSize(
      pageSize.width,
      pageSize.height,
      contentAspect,
    );
    // No min/max clamp here, unlike per-image crop - a page's content
    // block is free to shrink below cover-fit (showing margin) or zoom
    // in arbitrarily far; see clampPageCropZoom's own doc comment.
    final zoom = clampPageCropZoom(crop.zoom);
    final scaled = ImagePanZoomGeometry.scaledSize(cover, zoom);
    final scale = scaled.width / size.width; // == scaled.height / size.height

    // Raw, possibly-negative difference rather than ImagePanZoomGeometry
    // .overflow (which floors at 0 per axis - correct for per-image crop,
    // where zoom never goes below 1.0, but wrong here: once content can
    // be smaller than the page, flooring this would silently force it to
    // always render centered regardless of crop.panX/panY). Identical to
    // the old overflow-based result whenever the raw difference is
    // already >= 0, i.e. every previously-reachable case.
    final rawOverflowX = scaled.width - pageSize.width;
    final rawOverflowY = scaled.height - pageSize.height;
    final visibleLeft = (rawOverflowX / 2) * (1 + crop.panX);
    final visibleTop = (rawOverflowY / 2) * (1 + crop.panY);

    // The full board-space window actually visible on the page - the
    // inverse of the transform positioning the content above. Once zoom
    // can shrink content below the page's own size, the page shows more
    // than just the content's own rect; the dot grid (when no custom
    // frame color is set) is drawn across this whole window instead of
    // just the content rect, so it continues seamlessly into whatever
    // margin is revealed, matching the live board's own infinite grid.
    final visibleBoardRect = Rect.fromLTWH(
      origin.dx + visibleLeft / scale,
      origin.dy + visibleTop / scale,
      pageSize.width / scale,
      pageSize.height / scale,
    );

    pageContent = pw.Stack(
      children: [
        pw.Positioned.fill(
          child: pw.Container(
            color: PdfColor.fromHex(
              backgroundColorHex ?? _kCanvasBackgroundHex,
            ),
          ),
        ),
        if (backgroundColorHex == null)
          pw.Positioned.fill(
            child: pw.CustomPaint(
              size: PdfPoint(pageSize.width, pageSize.height),
              painter: (PdfGraphics canvas, PdfPoint canvasSize) =>
                  _drawDotGrid(
                    canvas,
                    visibleBoardRect.topLeft,
                    visibleBoardRect.size,
                    scale: scale,
                  ),
            ),
          ),
        pw.Positioned(
          left: -visibleLeft,
          top: -visibleTop,
          child: pw.Transform.scale(
            scale: scale,
            alignment: pw.Alignment.topLeft,
            child: pw.SizedBox(
              width: size.width,
              height: size.height,
              child: pw.Stack(children: pageChildren),
            ),
          ),
        ),
      ],
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(pageSize.width, pageSize.height),
      margin: pw.EdgeInsets.zero,
      clip: true,
      build: (context) => pageContent,
    ),
  );

  return _PageResult(drawn, skipped, skippedFileNames);
}

/// Output resolution multiplier for rasterized text notes - a flat 1x
/// (board-unit == PDF-point) would render blurry once a PDF viewer lets
/// the user zoom in past 100% or the file is printed. 3x roughly matches
/// a 288dpi effective resolution - crisp through normal zoom/print
/// without each note's PNG getting needlessly large.
const double _kTextRasterPixelRatio = 3.0;

/// Rasterizes a text clip's content using the app's own real
/// text-rendering logic (`TextNoteGeometry`/`TextStyleRanges`/
/// `HighlightGeometry` - the exact calls `ClipWidget._buildText()`
/// makes) instead of reimplementing rich-text/highlight rendering
/// against package:pdf's own, unrelated font/widget system (a different
/// font than Flutter's own, with no shared styling code - this
/// previously meant highlights never rendered, a stray border always
/// showed even though the live UI has none, and text could get cut off
/// since the two systems' layouts could disagree). Guarantees the PDF
/// matches what the user sees on the board; the accepted tradeoff is
/// that exported text becomes a flat, non-selectable image, same as
/// every other clip type already effectively is in this export.
///
/// Stays in native board-space units (board unit == PDF point) -
/// [pixelRatio] is a flat canvas scale applied purely to bump output
/// resolution, never touching layout/wrapping, so this always agrees
/// with `ClipWidget` at `viewScale: 1.0`. No leading underscore - this
/// needs to be callable directly from `pdf_writer_test.dart`.
Future<Uint8List> rasterizeTextClip(
  BoardClip clip, {
  double pixelRatio = _kTextRasterPixelRatio,
}) async {
  final text = clip.textContent ?? '';
  final formatting = clip.textFormatting;
  final baseStyle = TextNoteGeometry.baseStyle(
    fontSize: clip.fontSize ?? kTextNoteFontSize,
    color: AppTheme.textNoteText,
  );

  // Same width math as ClipWidget._buildText() (NOT TextNoteGeometry's
  // own requiredHeight(), which omits the caret-reservation subtraction
  // - the raster must match what the live board actually draws).
  final innerWidth = clip.width - 2 * kTextNotePadding;
  final contentWidth = innerWidth > kTextCaretReservedWidth
      ? innerWidth - kTextCaretReservedWidth
      : innerWidth;

  final pixelWidth = (clip.width * pixelRatio).round().clamp(1, 1 << 20);
  final pixelHeight = (clip.height * pixelRatio).round().clamp(1, 1 << 20);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()),
  )..scale(pixelRatio);

  // 1. Background fill - mirrors ClipWidget's outer Container `color`
  // for a text clip: a custom color if set, else nothing (the default,
  // AppTheme.textNoteSurface, is fully transparent).
  if (clip.backgroundColorHex != null) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, clip.width, clip.height),
      Paint()..color = hexToColor(clip.backgroundColorHex!),
    );
  }

  // 2. Highlight layer - HighlightPainter's paint loop, inlined directly
  // onto this raw Canvas instead of instantiating the widget/painter.
  final highlightRects = HighlightGeometry.rectsFor(
    text: text,
    formatting: formatting,
    baseStyle: baseStyle,
    width: contentWidth,
    cornerRadius: kHighlightCornerRadius,
  );
  if (highlightRects.isNotEmpty) {
    final highlightPaint = Paint()
      ..color = hexToColor(clip.highlightColorHex ?? kDefaultHighlightColorHex);
    final padOffset = Offset(kTextNotePadding, kTextNotePadding);
    for (final rect in highlightRects) {
      canvas.drawRRect(rect.shift(padOffset), highlightPaint);
    }
  }

  // 3. Rich text itself - same TextSpan tree ClipWidget._buildText() builds.
  final painter = TextPainter(
    text: TextSpan(
      children: TextStyleRanges.buildSpans(text, formatting, baseStyle),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: contentWidth < 1 ? 1 : contentWidth);
  painter.paint(canvas, Offset(kTextNotePadding, kTextNotePadding));

  final picture = recorder.endRecording();
  final image = await picture.toImage(pixelWidth, pixelHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// Replicates `DotGridPainter`'s board-space dot grid (fixed spacing,
/// 1.5pt base radius, 0.5 alpha) onto a PDF page - unlike the live board,
/// there's no zoom to fade/thin it for, so it's always drawn at the base
/// density. [origin]/[size] are the board-space rect to cover (same
/// values `_buildPage` already uses to position clips when [scale] is
/// the default 1.0; the `needsFit` branch instead passes the full
/// visible board-space window at that page's own fit scale). [scale]
/// defaults to 1.0 (board unit == PDF point, byte-identical to this
/// function's pre-Part-57 behavior) and otherwise scales both dot radius
/// and position, so a page drawn at some zoom still gets a
/// correctly-sized grid.
void _drawDotGrid(
  PdfGraphics canvas,
  Offset origin,
  Size size, {
  double scale = 1.0,
}) {
  const spacing = kBoardGridSpacing;
  final radius = 1.5 * scale;
  final startCol = (origin.dx / spacing).floor();
  final endCol = ((origin.dx + size.width) / spacing).ceil();
  final startRow = (origin.dy / spacing).floor();
  final endRow = ((origin.dy + size.height) / spacing).ceil();

  canvas
    ..saveContext()
    ..setGraphicState(const PdfGraphicState(opacity: 0.5))
    ..setFillColor(PdfColor.fromHex(_kGridDotHex));
  for (var col = startCol; col <= endCol; col++) {
    final x = (col * spacing - origin.dx) * scale;
    for (var row = startRow; row <= endRow; row++) {
      final y = (row * spacing - origin.dy) * scale;
      canvas
        ..drawEllipse(x, y, radius, radius)
        ..fillPath();
    }
  }
  canvas.restoreContext();
}

/// Draws a shape clip's fill/stroke from its [ShapeKind] and box size -
/// mirrors `ShapePainter`'s exact rendering rules (fill only if set,
/// stroke only if a color AND a positive width are both present) so the
/// exported page matches the on-board clip.
pw.Widget _buildShapeWidget(BoardClip clip) {
  final kind = clip.shapeKind ?? ShapeKind.rectangle;
  final fillHex = clip.shapeFillColorHex;
  final strokeHex = clip.shapeStrokeColorHex ?? _kGridDotHex;
  final strokeWidth = clip.shapeStrokeWidth ?? kDefaultStrokeWidth;

  return pw.CustomPaint(
    size: PdfPoint(clip.width, clip.height),
    painter: (PdfGraphics canvas, PdfPoint size) {
      void tracePath() {
        if (ShapeGeometry.isEllipse(kind)) {
          canvas.drawEllipse(
            clip.width / 2,
            clip.height / 2,
            clip.width / 2,
            clip.height / 2,
          );
        } else {
          final vertices = ShapeGeometry.polygonVertices(
            kind,
            Size(clip.width, clip.height),
          );
          canvas.moveTo(vertices.first.dx, vertices.first.dy);
          for (final v in vertices.skip(1)) {
            canvas.lineTo(v.dx, v.dy);
          }
          canvas.closePath();
        }
      }

      if (fillHex != null) {
        tracePath();
        canvas
          ..setFillColor(PdfColor.fromHex(fillHex))
          ..fillPath();
      }
      if (strokeWidth > 0) {
        tracePath();
        canvas
          ..setStrokeColor(PdfColor.fromHex(strokeHex))
          ..setLineWidth(strokeWidth)
          ..strokePath();
      }
    },
  );
}

/// The filename portion of a (possibly OS-specific) file path, for the
/// export-complete summary - handles both `/`- and `\`-separated paths.
String _basename(String path) {
  final i = path.lastIndexOf(RegExp(r'[/\\]'));
  return i < 0 ? path : path.substring(i + 1);
}

/// Fallback decoder for image bytes `package:image`'s own `decodeImage`
/// couldn't parse (e.g. a format only the platform's codec supports) -
/// uses Flutter's own `dart:ui` codec instead, then converts the decoded
/// frame's raw RGBA pixels into a `package:image` `Image` so it can feed
/// into the same crop/encode pipeline below. Returns null if this also
/// fails (genuinely undecodable bytes).
Future<img.Image?> _decodeViaFlutterCodec(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return null;
    return img.Image.fromBytes(
      width: frame.image.width,
      height: frame.image.height,
      bytes: byteData.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  } catch (_) {
    return null;
  }
}

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

  final decoded = img.decodeImage(bytes) ?? await _decodeViaFlutterCodec(bytes);
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

/// Draws one connector's orthogonal route as a plain sharp-cornered
/// polyline (no dashing/arrowhead - connectors have neither) plus a
/// small filled endpoint circle, mirroring `ConnectorPainter`'s own
/// sharp-corner rendering and `_endpointRadius` (4) for visual parity
/// between the live board and the exported PDF.
void _paintConnector(
  PdfGraphics canvas,
  Connector connector,
  List<Offset> points,
) {
  if (points.length < 2) return;
  final color = PdfColor.fromHex(connector.colorHex);
  canvas
    ..setStrokeColor(color)
    ..setLineWidth(connector.strokeWidth)
    ..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    canvas.lineTo(p.dx, p.dy);
  }
  canvas.strokePath();
  canvas
    ..setFillColor(color)
    ..drawEllipse(points.last.dx, points.last.dy, 4, 4)
    ..fillPath();
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
