import '../local/database.dart';

enum ClipType { image, text }

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
/// persistence details (nullable sync columns, etc.).
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
  final String? storagePath;
  final String? localFilePath;
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
    this.storagePath,
    this.localFilePath,
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
    storagePath: row.storagePath,
    localFilePath: row.localFilePath,
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
    String? storagePath,
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
      storagePath: storagePath ?? this.storagePath,
      localFilePath: localFilePath,
      isBinned: isBinned ?? this.isBinned,
      binnedAt: binnedAt ?? this.binnedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
