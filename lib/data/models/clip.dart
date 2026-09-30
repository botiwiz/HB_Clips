import 'dart:convert';

import '../local/database.dart';

enum ClipType { image, text }

/// A half-open `[start, end)` character range into a text clip's
/// `textContent`, used by [TextFormatting]'s 3 independent range lists.
typedef IntRange = ({int start, int end});

/// Bold/italic/strikethrough ranges over a text clip's `textContent` -
/// each of the 3 lists is independently normalized (sorted, merged,
/// non-overlapping) by `TextStyleRanges.toggle`. Whole-note font size
/// lives on [BoardClip.fontSize] instead, since it's not a per-range
/// attribute (confirmed scope: whole textbox, not per-selection).
class TextFormatting {
  final List<IntRange> bold;
  final List<IntRange> italic;
  final List<IntRange> strikethrough;

  const TextFormatting({
    this.bold = const [],
    this.italic = const [],
    this.strikethrough = const [],
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
      strikethrough: ranges('strikethrough'),
    );
  }

  String toJson() {
    List<List<int>> encode(List<IntRange> ranges) =>
        ranges.map((r) => [r.start, r.end]).toList();
    return jsonEncode({
      'bold': encode(bold),
      'italic': encode(italic),
      'strikethrough': encode(strikethrough),
    });
  }
}

extension ClipTypeStorage on ClipType {
  String get storageValue => switch (this) {
    ClipType.image => 'image',
    ClipType.text => 'text',
  };

  static ClipType fromStorage(String value) => switch (value) {
    'image' => ClipType.image,
    'text' => ClipType.text,
    _ => throw ArgumentError('Unknown clip type: $value'),
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
      isBinned: isBinned ?? this.isBinned,
      binnedAt: binnedAt ?? this.binnedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
