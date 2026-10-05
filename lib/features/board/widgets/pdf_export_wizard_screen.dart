import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
          AspectRatio(
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
        ],
      ),
    );
  }
}

/// The gesture-and-render widget for one page's crop: cover-fits the
/// page's content block into [pageSize] via [ImagePanZoomGeometry] (the
/// same math/representation the existing per-image crop tool uses, just
/// applied to a whole page's content instead of one image), with
/// scroll-to-zoom and drag-to-pan mirroring `board_canvas.dart`'s
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

  Offset get _overflow => ImagePanZoomGeometry.overflow(
    widget.pageSize.width,
    widget.pageSize.height,
    _scaled,
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

  // The full board-space window actually visible on the page - the
  // inverse of the transform positioning the content below. Lets the
  // dot-grid background layer continue past the content's own extent
  // once zoomed out below cover-fit, mirroring pdf_writer.dart's
  // `visibleBoardRect` exactly so the live preview and the final export
  // always agree.
  Rect get _visibleBoardRect => Rect.fromLTWH(
    widget.contentOrigin.dx + _visibleLeft / _scaleFactor,
    widget.contentOrigin.dy + _visibleTop / _scaleFactor,
    widget.pageSize.width / _scaleFactor,
    widget.pageSize.height / _scaleFactor,
  );

  void _handleScroll(PointerScrollEvent event) {
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    widget.onChanged(
      widget.crop.copyWith(zoom: clampPageCropZoom(widget.crop.zoom * factor)),
    );
  }

  void _handleDown(PointerDownEvent event) {
    _dragStartLocal = event.localPosition;
    _dragStartPan = Offset(widget.crop.panX, widget.crop.panY);
  }

  void _handleMove(PointerMoveEvent event, double previewToPageScale) {
    if (_dragStartLocal == null) return;
    final localDelta =
        (event.localPosition - _dragStartLocal!) * previewToPageScale;
    final newPan = ImagePanZoomGeometry.applyPanDelta(
      _dragStartPan!,
      localDelta,
      _overflow,
    );
    widget.onChanged(widget.crop.copyWith(panX: newPan.dx, panY: newPan.dy));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewToPageScale = widget.pageSize.width / constraints.maxWidth;
        return ClipRect(
          child: Listener(
            onPointerSignal: (e) {
              // Registers through the same PointerSignalResolver every
              // Scrollable (including the wizard's own ListView, an
              // ancestor of this editor) uses for its own scroll
              // handling - "first registered callback wins," and
              // pointer-signal dispatch visits the deepest hit-test
              // target first, so this editor wins the resolution and the
              // ListView's own, later registration for the same event is
              // dropped entirely. Calling _handleScroll directly (as
              // before) sidesteps this arbitration, which is why scroll
              // used to also bleed into the list.
              if (e is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(
                  e,
                  (event) => _handleScroll(event as PointerScrollEvent),
                );
              }
            },
            onPointerDown: _handleDown,
            onPointerMove: (e) => _handleMove(e, previewToPageScale),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: widget.pageSize.width,
                  height: widget.pageSize.height,
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
                      ClipRect(
                        child: OverflowBox(
                          alignment: Alignment(
                            widget.crop.panX,
                            widget.crop.panY,
                          ),
                          minWidth: _scaled.width,
                          maxWidth: _scaled.width,
                          minHeight: _scaled.height,
                          maxHeight: _scaled.height,
                          child: SizedBox(
                            width: widget.contentSize.width,
                            height: widget.contentSize.height,
                            child: Transform.scale(
                              scale: _scaleFactor,
                              alignment: Alignment.topLeft,
                              child: _PageContent(
                                contentOrigin: widget.contentOrigin,
                                clips: widget.clips,
                              ),
                            ),
                          ),
                        ),
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
