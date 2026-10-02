import 'dart:convert';

import '../local/database.dart';

enum ClipType { image, text, shape }

/// A flowchart-style vector primitive a shape clip renders as. Fixed at
/// creation, like [ClipType] itself - never changes after a shape clip is
/// placed.
enum ShapeKind { rectangle, ellipse, triangle, trapezoid, parallelogram }

/// A half-open `[start, end)` character range into a text clip's
/// `textContent`, used by [TextFormatting]'s 3 independent range lists.
typedef IntRange = ({int start, int end});

/// Bold/italic/underline/strikethrough ranges over a text clip's
/// `textContent` - each of the 4 lists is independently normalized
/// (sorted, merged, non-overlapping) by `TextStyleRanges.toggle`. Whole-note
/// font size lives on [BoardClip.fontSize] instead, since it's not a
/// per-range attribute (confirmed scope: whole textbox, not per-selection).
class TextFormatting {
  final List<IntRange> bold;
  final List<IntRange> italic;
  final List<IntRange> underline;
  final List<IntRange> strikethrough;
  final List<IntRange> highlight;

  const TextFormatting({
    this.bold = const [],
    this.italic = const [],
    this.underline = const [],
    this.strikethrough = const [],
    this.highlight = const [],
  });

  static const empty = TextFormatting();

  factory TextFormatting.fromJson(String? json) {
    if (json == null || json.isEmpty) return empty;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    List<IntRange> ranges(String key) {
      final raw = decoded[key] as List<dynamic>? ?? const [];
      return raw.map((entry) {
        final pair = entry as List<dynamic>;
        return (start: pair[0] as int, end: pair[1] as int);
      }).toList();
    }

    return TextFormatting(
      bold: ranges('bold'),
      italic: ranges('italic'),
      underline: ranges('underline'),
      strikethrough: ranges('strikethrough'),
      highlight: ranges('highlight'),
    );
  }

  String toJson() {
    List<List<int>> encode(List<IntRange> ranges) =>
        ranges.map((r) => [r.start, r.end]).toList();
    return jsonEncode({
      'bold': encode(bold),
      'italic': encode(italic),
      'underline': encode(underline),
      'strikethrough': encode(strikethrough),
      'highlight': encode(highlight),
    });
  }
}

extension ClipTypeStorage on ClipType {
  String get storageValue => switch (this) {
    ClipType.image => 'image',
    ClipType.text => 'text',
    ClipType.shape => 'shape',
  };

  static ClipType fromStorage(String value) => switch (value) {
    'image' => ClipType.image,
    'text' => ClipType.text,
    'shape' => ClipType.shape,
    _ => throw ArgumentError('Unknown clip type: $value'),
  };
}

extension ShapeKindStorage on ShapeKind {
  String get storageValue => switch (this) {
    ShapeKind.rectangle => 'rectangle',
    ShapeKind.ellipse => 'ellipse',
    ShapeKind.triangle => 'triangle',
    ShapeKind.trapezoid => 'trapezoid',
    ShapeKind.parallelogram => 'parallelogram',
  };

  static ShapeKind fromStorage(String value) => switch (value) {
    'rectangle' => ShapeKind.rectangle,
    'ellipse' => ShapeKind.ellipse,
    'triangle' => ShapeKind.triangle,
    'trapezoid' => ShapeKind.trapezoid,
    'parallelogram' => ShapeKind.parallelogram,
    _ => throw ArgumentError('Unknown shape kind: $value'),
  };
}

/// Domain-level clip used by the board UI and controllers. Kept separate
/// from the Drift-generated [ClipRow] so UI code doesn't depend on
/// persistence details.
class BoardClip {
  final String id;
  final String boardId;
  final ClipType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int zIndex;
  final double opacity;
  final String? textContent;
  final String? backgroundColorHex;
  final String? groupId;
  final String? frameId;
  final String? localFilePath;
  final double imagePanX;
  final double imagePanY;
  final double imageZoom;
  final double? imageAspectRatio;
  final TextFormatting textFormatting;
  final double? fontSize;
  final double? sizeLockScale;

  /// Which flowchart-style vector primitive this clip renders as - set
  /// once at creation, like [type] itself. Null for every non-shape clip.
  final ShapeKind? shapeKind;

  /// Fill color as `#RRGGBB`, or null for no fill (outline-only shape).
  /// Ignored for non-shape clips.
  final String? shapeFillColorHex;

  /// Stroke/outline color as `#RRGGBB`. Null falls back to a neutral
  /// default at render time. Ignored for non-shape clips.
  final String? shapeStrokeColorHex;

  /// Stroke width in board-space pixels. Null falls back to
  /// `kDefaultStrokeWidth`. Ignored for non-shape clips.
  final double? shapeStrokeWidth;

  /// Background color behind text covered by `textFormatting.highlight`,
  /// as `#RRGGBB`. Null falls back to `kDefaultHighlightColorHex` at
  /// render time - same "nullable override, constant fallback" pattern
  /// as [fontSize]/[backgroundColorHex]. One color per note, not
  /// per-range.
  final String? highlightColorHex;

  final bool isBinned;
  final DateTime? binnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BoardClip({
    required this.id,
    required this.boardId,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.zIndex = 0,
    this.opacity = 1.0,
    this.textContent,
    this.backgroundColorHex,
    this.groupId,
    this.frameId,
    this.localFilePath,
    this.imagePanX = 0.0,
    this.imagePanY = 0.0,
    this.imageZoom = 1.0,
    this.imageAspectRatio,
    this.textFormatting = TextFormatting.empty,
    this.fontSize,
    this.sizeLockScale,
    this.shapeKind,
    this.shapeFillColorHex,
    this.shapeStrokeColorHex,
    this.shapeStrokeWidth,
    this.highlightColorHex,
    this.isBinned = false,
    this.binnedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BoardClip.fromRow(ClipRow row) => BoardClip(
    id: row.id,
    boardId: row.boardId,
    type: ClipTypeStorage.fromStorage(row.type),
    x: row.x,
    y: row.y,
    width: row.width,
    height: row.height,
    rotation: row.rotation,
    zIndex: row.zIndex,
    opacity: row.opacity,
    textContent: row.textContent,
    backgroundColorHex: row.backgroundColorHex,
    groupId: row.groupId,
    frameId: row.frameId,
    localFilePath: row.localFilePath,
    imagePanX: row.imagePanX,
    imagePanY: row.imagePanY,
    imageZoom: row.imageZoom,
    imageAspectRatio: row.imageAspectRatio,
    textFormatting: TextFormatting.fromJson(row.textFormattingJson),
    fontSize: row.fontSize,
    sizeLockScale: row.sizeLockScale,
    shapeKind: row.shapeKind == null
        ? null
        : ShapeKindStorage.fromStorage(row.shapeKind!),
    shapeFillColorHex: row.shapeFillColorHex,
    shapeStrokeColorHex: row.shapeStrokeColorHex,
    shapeStrokeWidth: row.shapeStrokeWidth,
    highlightColorHex: row.highlightColorHex,
    isBinned: row.isBinned,
    binnedAt: row.binnedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  BoardClip copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    double? opacity,
    String? textContent,
    String? backgroundColorHex,
    String? groupId,
    String? frameId,
    double? imagePanX,
    double? imagePanY,
    double? imageZoom,
    TextFormatting? textFormatting,
    double? fontSize,
    double? sizeLockScale,
    bool? isBinned,
    DateTime? binnedAt,
  }) {
    return BoardClip(
      id: id,
      boardId: boardId,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      opacity: opacity ?? this.opacity,
      textContent: textContent ?? this.textContent,
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      groupId: groupId ?? this.groupId,
      frameId: frameId ?? this.frameId,
      localFilePath: localFilePath,
      imagePanX: imagePanX ?? this.imagePanX,
      imagePanY: imagePanY ?? this.imagePanY,
      imageZoom: imageZoom ?? this.imageZoom,
      imageAspectRatio: imageAspectRatio,
      textFormatting: textFormatting ?? this.textFormatting,
      fontSize: fontSize ?? this.fontSize,
      sizeLockScale: sizeLockScale ?? this.sizeLockScale,
      shapeKind: shapeKind,
      shapeFillColorHex: shapeFillColorHex,
      shapeStrokeColorHex: shapeStrokeColorHex,
      shapeStrokeWidth: shapeStrokeWidth,
      highlightColorHex: highlightColorHex,
      isBinned: isBinned ?? this.isBinned,
      binnedAt: binnedAt ?? this.binnedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
