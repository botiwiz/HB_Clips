import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fixed swatch palette for the draw tool - deliberately small and simple
/// rather than a full color picker.
const List<String> kStrokeColorPalette = [
  '#FF3B30', // red (DB default)
  '#FFCC00', // yellow
  '#34C759', // green
  '#0A84FF', // blue
  '#FFFFFF', // white
  '#111111', // near-black
];

const double kMinStrokeWidth = 2;
const double kMaxStrokeWidth = 12;
const double kDefaultStrokeWidth = 3;

/// Whether the board is currently in draw mode. While true, the board's
/// pointer handling in `board_canvas.dart` is entirely dedicated to
/// freehand drawing - no pan/select/marquee/resize.
final isDrawModeProvider = StateProvider<bool>((ref) => false);

final strokeColorHexProvider = StateProvider<String>(
  (ref) => kStrokeColorPalette.first,
);

final strokeWidthValueProvider = StateProvider<double>(
  (ref) => kDefaultStrokeWidth,
);

/// Board-space points of the stroke currently being drawn, or null when no
/// draw gesture is in progress. Rendered live by `DrawingOverlay`; only
/// persisted to the repository on pointer-up.
final liveStrokePointsProvider = StateProvider<List<Offset>?>((ref) => null);

/// Which draw-mode sub-tool is active. `eyedropper` is wired up alongside
/// `pen`/`eraser` here so the enum only needs defining once, even though its
/// own toolbar button/pointer handling isn't added until later.
enum DrawTool { pen, eraser, eyedropper }

final drawToolProvider = StateProvider<DrawTool>((ref) => DrawTool.pen);

/// Whether new strokes are drawn dashed / with an arrowhead at their end
/// point. Read at pointer-up when persisting a stroke, and by the live
/// preview so the in-progress stroke matches what will actually be saved.
final strokeDashedProvider = StateProvider<bool>((ref) => false);

final strokeArrowProvider = StateProvider<bool>((ref) => false);

/// Screen-space distance (matches other constant-screen-size hit radii like
/// `ClipGeometry.handleHitRadius`) within which the eraser deletes a stroke
/// it passes near.
const double kEraserHitRadius = 12;
