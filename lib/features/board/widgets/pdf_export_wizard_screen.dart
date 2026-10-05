import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;

import '../../../core/constants.dart' show kBoardGridSpacing;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../annotation/stroke_painter.dart' show hexToColor;
import '../geometry/frame_geometry.dart';
import '../geometry/frame_presets.dart';
import '../geometry/image_pan_zoom_geometry.dart';
import '../geometry/page_crop_settings.dart';
import '../geometry/pdf_export_selection.dart';
import '../geometry/selection_geometry.dart';
import 'clip_widget.dart';

/// Extra "bleed" margin shown around the page's own edges in the live
/// crop preview, as a fraction of the page's own width/height per side
/// - a fixed VIEWPORT overscan computed purely from pageSize (never
/// from zoom/content/aspect ratio), so it's always present regardless
/// of preset/orientation or how the crop is currently zoomed/panned -
/// lets the user see exactly what bleeds past the real export boundary
/// (marked by [_CropMarksOverlay]'s red rectangle). Tunable by eye once
/// seen live.
const double _kCropMarkBleedFraction = 0.25;

/// Result of the export wizard - the resolution preset/orientation chosen
/// once for the whole export, plus each page's committed pan/zoom crop.
/// `null` (returned by [PdfExportWizardScreen]'s own `Navigator.pop()`,
/// not this class) means the user cancelled.
class ExportWizardResult {
  final FramePreset preset;
  final bool landscape;
  final Map<String, PageCropSettings> pageCrops;
  const ExportWizardResult({
    required this.preset,
    required this.landscape,
    required this.pageCrops,
  });
}

/// Full-screen export wizard: pick a resolution/orientation once for the
/// whole export, then adjust each page's pan/zoom crop with a live
/// preview before committing. A full screen (not a dialog) because N
/// independent scroll-to-zoom/drag-to-pan gesture regions - one per page
/// - need real screen space.
class PdfExportWizardScreen extends StatefulWidget {
  final PdfExportSelection selection;
  const PdfExportWizardScreen({super.key, required this.selection});

  @override
  State<PdfExportWizardScreen> createState() => _PdfExportWizardScreenState();
}

class _PdfExportWizardScreenState extends State<PdfExportWizardScreen> {
  FramePreset _preset = kFramePresets.first;
  bool _landscape = false;
  final Map<String, PageCropSettings> _pageCrops = {};

  Size get _pageSize {
    final w = _landscape ? _preset.height : _preset.width;
    final h = _landscape ? _preset.width : _preset.height;
    return Size(w, h);
  }

  PageCropSettings _cropFor(String key) =>
      _pageCrops[key] ?? PageCropSettings.initial;

  void _setCrop(String key, PageCropSettings value) =>
      setState(() => _pageCrops[key] = value);

  @override
  Widget build(BuildContext context) {
    final looseClips = widget.selection.clips
        .where((c) => c.frameId == null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Export settings')),
      body: Column(
        children: [
          _PresetPicker(
            preset: _preset,
            landscape: _landscape,
            onPresetChanged: (p) => setState(() => _preset = p),
            onLandscapeChanged: (v) => setState(() => _landscape = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (looseClips.isNotEmpty)
                  _PageCropSection(
                    label: 'Overview',
                    pageSize: _pageSize,
                    contentRect: ClipGeometry.boardBoundingBox(looseClips),
                    clips: looseClips,
                    backgroundColorHex: null,
                    crop: _cropFor(kOverviewPageCropKey),
                    onChanged: (c) => _setCrop(kOverviewPageCropKey, c),
                  ),
                for (final frame in widget.selection.frames)
                  _PageCropSection(
                    label: frame.name,
                    pageSize: _pageSize,
                    contentRect: FrameGeometry.boardRect(frame),
                    clips:
                        widget.selection.clips
                            .where((c) => c.frameId == frame.id)
                            .toList()
                          ..sort((a, b) => a.zIndex.compareTo(b.zIndex)),
                    backgroundColorHex: frame.backgroundColorHex,
                    crop: _cropFor(frame.id),
                    onChanged: (c) => _setCrop(frame.id, c),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(
              ExportWizardResult(
                preset: _preset,
                landscape: _landscape,
                pageCrops: Map.of(_pageCrops),
              ),
            ),
            child: const Text('Export'),
          ),
        ),
      ),
    );
  }
}

/// The resolution/orientation picker - today's `_pickExportSettings`
/// dialog body, shown once at the top of the wizard instead of in a
/// dialog, driven by callbacks instead of a dialog's local `setState`.
class _PresetPicker extends StatelessWidget {
  final FramePreset preset;
  final bool landscape;
  final ValueChanged<FramePreset> onPresetChanged;
  final ValueChanged<bool> onLandscapeChanged;

  const _PresetPicker({
    required this.preset,
    required this.landscape,
    required this.onPresetChanged,
    required this.onLandscapeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: RadioGroup<FramePreset>(
        groupValue: preset,
        onChanged: (value) => onPresetChanged(value!),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                children: [
                  for (final p in kFramePresets)
                    RadioListTile<FramePreset>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.label),
                      value: p,
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Landscape'),
                Switch(value: landscape, onChanged: onLandscapeChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Height budget given to a page's crop preview below its label - the
/// editor is centered within this allocated box (via [ConstrainedBox] +
/// [Center], not a tight [SizedBox], so the editor still shrinks to
/// respect the available WIDTH too for an unusually wide-aspect preset
/// in a narrow window) rather than letting `AspectRatio` grow to fill
/// the full list-item width with unbounded height - which is what
/// previously let a landscape preset's preview overflow past the
/// bottom of the window with no way to see the rest of it. Tunable by
/// eye once seen live.
const double _kPageCropPreviewMaxHeight = 480.0;

/// One scrollable list item: a page's label plus its fixed-aspect crop
/// preview/editor box.
class _PageCropSection extends StatelessWidget {
  final String label;
  final Size pageSize;
  final Rect contentRect;
  final List<BoardClip> clips;
  final String? backgroundColorHex;
  final PageCropSettings crop;
  final ValueChanged<PageCropSettings> onChanged;

  const _PageCropSection({
    required this.label,
    required this.pageSize,
    required this.contentRect,
    required this.clips,
    required this.backgroundColorHex,
    required this.crop,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: _kPageCropPreviewMaxHeight,
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: pageSize.width / pageSize.height,
                child: _PageCropEditor(
                  pageSize: pageSize,
                  contentSize: contentRect.size,
                  contentOrigin: contentRect.topLeft,
                  clips: clips,
                  backgroundColorHex: backgroundColorHex,
                  crop: crop,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gesture-and-render widget for one page's crop: cover-fits the
/// page's content block into [pageSize] via [ImagePanZoomGeometry] (the
/// same math/representation the existing per-image crop tool uses, just
/// applied to a whole page's content instead of one image), with
/// Ctrl/Cmd+scroll-to-zoom (a plain scroll instead passes through to
/// the wizard's own scrollable page, so a tall crop box never traps the
/// mouse wheel) and drag-to-pan mirroring `board_canvas.dart`'s
/// existing per-image pan/zoom gesture handling.
class _PageCropEditor extends StatefulWidget {
  final Size pageSize;
  final Size contentSize;
  final Offset contentOrigin;
  final List<BoardClip> clips;
  final String? backgroundColorHex;
  final PageCropSettings crop;
  final ValueChanged<PageCropSettings> onChanged;

  const _PageCropEditor({
    required this.pageSize,
    required this.contentSize,
    required this.contentOrigin,
    required this.clips,
    required this.backgroundColorHex,
    required this.crop,
    required this.onChanged,
  });

  @override
  State<_PageCropEditor> createState() => _PageCropEditorState();
}

class _PageCropEditorState extends State<_PageCropEditor> {
  Offset? _dragStartLocal;
  Offset? _dragStartPan;

  double get _r => widget.contentSize.width / widget.contentSize.height;

  Size get _cover => ImagePanZoomGeometry.coverSize(
    widget.pageSize.width,
    widget.pageSize.height,
    _r,
  );

  // No min/max clamp here, unlike per-image crop - see
  // clampPageCropZoom's own doc comment.
  Size get _scaled => ImagePanZoomGeometry.scaledSize(
    _cover,
    clampPageCropZoom(widget.crop.zoom),
  );

  // Raw, possibly-negative per-axis overflow - replaces the floored
  // ImagePanZoomGeometry.overflow (correct for per-image crop, where
  // zoom never drops below 1.0, but wrong here once content can shrink
  // below the page) - feeds applyPageCropPanDelta.
  Offset get _rawOverflow => Offset(
    _scaled.width - widget.pageSize.width,
    _scaled.height - widget.pageSize.height,
  );

  // The page-space scale factor the content block is actually rendered
  // at - same role as pdf_writer.dart's own `scale` local in the
  // `needsFit` branch.
  double get _scaleFactor => _scaled.width / widget.contentSize.width;

  // Raw, possibly-negative overflow (not the floored _overflow above,
  // which is correct for OverflowBox's own alignment math but would be
  // wrong for computing the visible board-space window once zoom can
  // shrink content below the page's own size) - mirrors pdf_writer
  // .dart's own visibleLeft/visibleTop exactly.
  double get _visibleLeft =>
      ((_scaled.width - widget.pageSize.width) / 2) * (1 + widget.crop.panX);
  double get _visibleTop =>
      ((_scaled.height - widget.pageSize.height) / 2) * (1 + widget.crop.panY);

  // The bigger "canvas" rendered in place of the page itself, so the
  // crop marks overlay always has a visible bleed margin around the
  // real export boundary - see _kCropMarkBleedFraction's own doc
  // comment. Scaled uniformly on both axes, so its aspect ratio always
  // matches pageSize's own exactly - _PageCropSection's outer
  // AspectRatio wrapper needs no change.
  Size get _canvasSize => Size(
    widget.pageSize.width * (1 + 2 * _kCropMarkBleedFraction),
    widget.pageSize.height * (1 + 2 * _kCropMarkBleedFraction),
  );

  // Where the page's own top-left corner sits within the bigger canvas
  // - symmetric on both axes (verified algebraically: canvasSize.width
  // - pageOffset.dx - pageSize.width == pageOffset.dx), so the page
  // rect is always exactly centered in the canvas.
  Offset get _pageOffsetInCanvas => Offset(
    widget.pageSize.width * _kCropMarkBleedFraction,
    widget.pageSize.height * _kCropMarkBleedFraction,
  );

  // The full board-space window actually visible across the whole
  // CANVAS (not just the page) - the inverse of the transform
  // positioning the content below, shifted by _pageOffsetInCanvas so
  // the margin band's dot grid continues seamlessly past the red crop
  // mark too, not just past the content's own extent. Reduces to
  // pdf_writer.dart's own `visibleBoardRect` formula exactly when
  // _pageOffsetInCanvas is zero and _canvasSize equals pageSize (i.e.
  // with no bleed margin), so this is a strict generalization, not a
  // behavior change for the underlying crop math itself.
  Rect get _visibleBoardRect => Rect.fromLTWH(
    widget.contentOrigin.dx +
        (_visibleLeft - _pageOffsetInCanvas.dx) / _scaleFactor,
    widget.contentOrigin.dy +
        (_visibleTop - _pageOffsetInCanvas.dy) / _scaleFactor,
    _canvasSize.width / _scaleFactor,
    _canvasSize.height / _scaleFactor,
  );

  void _handleScroll(PointerScrollEvent event, double previewToCanvasScale) {
    final oldZoom = clampPageCropZoom(widget.crop.zoom);
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    final newZoom = clampPageCropZoom(widget.crop.zoom * factor);
    // Shifts from canvas-space (the widget's own on-screen rendering,
    // now bigger than the page by the bleed margin) into page-space
    // (origin at the page's own top-left) - the coordinate system
    // zoomPageCropTowardPoint/_visibleLeft/_visibleTop already use.
    final pointerPageSpace =
        event.localPosition * previewToCanvasScale - _pageOffsetInCanvas;
    final newPan = zoomPageCropTowardPoint(
      crop: widget.crop,
      oldZoom: oldZoom,
      newZoom: newZoom,
      pointerPageSpace: pointerPageSpace,
      cover: _cover,
      pageSize: widget.pageSize,
    );
    widget.onChanged(
      widget.crop.copyWith(zoom: newZoom, panX: newPan.dx, panY: newPan.dy),
    );
  }

  void _handleDown(PointerDownEvent event) {
    _dragStartLocal = event.localPosition;
    _dragStartPan = Offset(widget.crop.panX, widget.crop.panY);
  }

  void _handleMove(PointerMoveEvent event, double previewToCanvasScale) {
    if (_dragStartLocal == null) return;
    // A delta of two event.localPosition samples - the canvas/page
    // offset is a constant that cancels out in the subtraction, so
    // only the (renamed) scale factor itself needs to change here.
    final localDelta =
        (event.localPosition - _dragStartLocal!) * previewToCanvasScale;
    final newPan = applyPageCropPanDelta(
      _dragStartPan!,
      localDelta,
      _rawOverflow,
    );
    widget.onChanged(widget.crop.copyWith(panX: newPan.dx, panY: newPan.dy));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The widget's own on-screen size now represents the bigger
        // CANVAS (page + bleed margin), not the page itself - see
        // _canvasSize's doc comment.
        final previewToCanvasScale = _canvasSize.width / constraints.maxWidth;
        return ClipRect(
          child: Listener(
            onPointerSignal: (e) {
              // Only claims the scroll signal while Ctrl/Cmd is held -
              // plain scroll is left completely alone (never registered
              // through the resolver below), so it bubbles to the
              // wizard's own ancestor ListView exactly like it would
              // over any other list item, letting the page itself
              // scroll. Without this gate, every page's crop editor
              // would permanently claim 100% of the scroll wheel
              // anywhere over its (now height-capped, but still
              // sizable) box, making it impossible to scroll past a
              // tall page with the mouse - this is the same modifier
              // convention zoom-toward-cursor canvases elsewhere
              // (Figma, Google Maps, VS Code) already use to avoid
              // exactly this conflict.
              final zoomModifierHeld =
                  HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed;
              if (e is PointerScrollEvent && zoomModifierHeld) {
                // Registers through the same PointerSignalResolver every
                // Scrollable (including the wizard's own ListView, an
                // ancestor of this editor) uses for its own scroll
                // handling - "first registered callback wins," and
                // pointer-signal dispatch visits the deepest hit-test
                // target first, so this editor wins the resolution and
                // the ListView's own, later registration for the same
                // event is dropped entirely. Calling _handleScroll
                // directly (as before) sidesteps this arbitration,
                // which is why scroll used to also bleed into the list.
                GestureBinding.instance.pointerSignalResolver.register(
                  e,
                  (event) => _handleScroll(
                    event as PointerScrollEvent,
                    previewToCanvasScale,
                  ),
                );
              }
            },
            onPointerDown: _handleDown,
            onPointerMove: (e) => _handleMove(e, previewToCanvasScale),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  child: Stack(
                    children: [
                      // Background + extended dot-grid layer, sized to
                      // the full page and sitting BEHIND the content
                      // composition below - continues the board's own
                      // dot-grid pattern into any margin revealed once
                      // zoomed out past the content's own extent, rather
                      // than showing a blank void. A custom frame color
                      // still just shows that solid color in the margin
                      // (no grid), matching pdf_writer.dart's behavior.
                      Positioned.fill(
                        child: Container(
                          color: widget.backgroundColorHex != null
                              ? hexToColor(widget.backgroundColorHex!)
                              : AppTheme.canvasBackground,
                        ),
                      ),
                      if (widget.backgroundColorHex == null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ExportDotGridPainter(
                              _visibleBoardRect.topLeft,
                              _visibleBoardRect.size,
                              scale: _scaleFactor,
                            ),
                          ),
                        ),
                      // Positioned + Transform.scale (not OverflowBox) -
                      // OverflowBox would FORCE this subtree's layout
                      // size to _scaled (even when contentSize is
                      // explicitly declared below), since OverflowBox's
                      // min/maxWidth/Height become tight incoming
                      // constraints that collapse any descendant's own
                      // declared size into them. That's harmless when
                      // _scaled is comfortably bigger than contentSize,
                      // but once zoomed out far enough that _scaled
                      // shrinks below contentSize, _PageContent's own
                      // Stack (positioned via absolute native-board-unit
                      // offsets up to contentSize) gets forced to that
                      // same shrunken size and clips anything beyond it
                      // - exactly the "elements disappear when zoomed
                      // out far" bug. A plain Positioned (only
                      // left/top set) hands its child fully unconstrained
                      // BoxConstraints instead, so contentSize is
                      // respected regardless of zoom - mirrors
                      // pdf_writer.dart's own (already-correct)
                      // Positioned+Transform.scale pattern exactly. The
                      // outer Stack's default Clip.hardEdge now crops at
                      // the canvas edge instead of the page edge - the
                      // extra _pageOffsetInCanvas shift below moves the
                      // content's origin from page-space into
                      // canvas-space so it still lands exactly where it
                      // used to relative to the page, just centered
                      // within the bigger canvas.
                      Positioned(
                        left: _pageOffsetInCanvas.dx - _visibleLeft,
                        top: _pageOffsetInCanvas.dy - _visibleTop,
                        child: Transform.scale(
                          scale: _scaleFactor,
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: widget.contentSize.width,
                            height: widget.contentSize.height,
                            child: _PageContent(
                              contentOrigin: widget.contentOrigin,
                              clips: widget.clips,
                            ),
                          ),
                        ),
                      ),
                      // Always on top: dims everything outside the real
                      // export boundary and marks it with a red
                      // rectangle, so bleed is visible but clearly
                      // distinguished from what survives the crop.
                      _CropMarksOverlay(
                        canvasSize: _canvasSize,
                        pageOffset: _pageOffsetInCanvas,
                        pageSize: widget.pageSize,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Always-visible overlay marking exactly the real export boundary
/// inside the bigger bleed-margin canvas `_PageCropEditor` now renders -
/// a red rectangle outline at the page rect, with everything outside it
/// dimmed (not hidden) so bled-over content is still visible but
/// clearly distinguished from what survives the crop. Purely a preview
/// aid - `pdf_writer.dart` is unaffected and still crops exactly at the
/// page boundary with no margin/marks baked into the exported file.
class _CropMarksOverlay extends StatelessWidget {
  final Size canvasSize;
  final Offset pageOffset;
  final Size pageSize;

  const _CropMarksOverlay({
    required this.canvasSize,
    required this.pageOffset,
    required this.pageSize,
  });

  @override
  Widget build(BuildContext context) {
    final scrim = Colors.black.withValues(alpha: 0.55);
    const borderWidth = 1.0;
    return IgnorePointer(
      child: Stack(
        children: [
          // 4 dimming bands covering everything outside the page rect -
          // darkens whatever the background/grid/content layers already
          // painted there rather than hiding it. Left/right and
          // top/bottom bands are each exactly `pageOffset`-sized since
          // the page rect is always centered in the canvas (verified:
          // canvasSize.width - pageOffset.dx - pageSize.width ==
          // pageOffset.dx).
          Positioned(
            left: 0,
            top: 0,
            width: canvasSize.width,
            height: pageOffset.dy,
            child: ColoredBox(color: scrim),
          ),
          Positioned(
            left: 0,
            top: pageOffset.dy + pageSize.height,
            width: canvasSize.width,
            height: pageOffset.dy,
            child: ColoredBox(color: scrim),
          ),
          Positioned(
            left: 0,
            top: pageOffset.dy,
            width: pageOffset.dx,
            height: pageSize.height,
            child: ColoredBox(color: scrim),
          ),
          Positioned(
            left: pageOffset.dx + pageSize.width,
            top: pageOffset.dy,
            width: pageOffset.dx,
            height: pageSize.height,
            child: ColoredBox(color: scrim),
          ),
          // The crop mark itself - drawn last, always crisp/undimmed,
          // exactly at the real export boundary.
          Positioned(
            left: pageOffset.dx,
            top: pageOffset.dy,
            width: pageSize.width,
            height: pageSize.height,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: borderWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The positioned/rotated clips loop from `pdf_writer.dart`'s
/// `_buildPage` Stack - background fill and the dot grid now live in
/// `_PageCropEditor.build()`'s own outer layer instead (so that layer
/// can extend the grid past this content block's own extent once
/// zoomed out below cover-fit; drawing a second background/grid here
/// would just double-paint underneath it). Deliberately excludes
/// `FrameWidget`'s chrome (border/title) - the real export never draws
/// that either.
class _PageContent extends StatelessWidget {
  final Offset contentOrigin;
  final List<BoardClip> clips;

  const _PageContent({required this.contentOrigin, required this.clips});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final clip in clips)
          Positioned(
            left: clip.x - contentOrigin.dx,
            top: clip.y - contentOrigin.dy,
            child: Transform.rotate(
              angle: clip.rotation,
              child: SizedBox(
                width: clip.width,
                height: clip.height,
                child: ClipWidget(clip: clip, selected: false, viewScale: 1.0),
              ),
            ),
          ),
      ],
    );
  }
}

/// Mirrors `pdf_writer.dart`'s `_drawDotGrid` (fixed board-space density,
/// not the live board's zoom-dependent `DotGridPainter`) so the preview's
/// grid matches the exported page's grid exactly - same spacing/radius/
/// color/opacity constants. [scale] (default 1.0, matching this
/// painter's pre-Part-57 behavior byte-for-byte) scales both dot radius
/// and position, mirroring `_drawDotGrid`'s own generalization - used by
/// `_PageCropEditor` to draw the grid at the page's own fit scale across
/// [contentSize] (now the full visible board-space window, not just the
/// content block's own rect).
class _ExportDotGridPainter extends CustomPainter {
  final Offset origin;
  final Size contentSize;
  final double scale;
  const _ExportDotGridPainter(
    this.origin,
    this.contentSize, {
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = kBoardGridSpacing;
    final radius = 1.5 * scale;
    final startCol = (origin.dx / spacing).floor();
    final endCol = ((origin.dx + contentSize.width) / spacing).ceil();
    final startRow = (origin.dy / spacing).floor();
    final endRow = ((origin.dy + contentSize.height) / spacing).ceil();

    final paint = Paint()..color = AppTheme.gridDot.withValues(alpha: 0.5);
    for (var col = startCol; col <= endCol; col++) {
      final x = (col * spacing - origin.dx) * scale;
      for (var row = startRow; row <= endRow; row++) {
        final y = (row * spacing - origin.dy) * scale;
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExportDotGridPainter oldDelegate) =>
      origin != oldDelegate.origin ||
      contentSize != oldDelegate.contentSize ||
      scale != oldDelegate.scale;
}
