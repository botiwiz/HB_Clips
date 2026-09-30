import '../local/database.dart';

enum ConnectorSide { top, right, bottom, left }

extension ConnectorSideStorage on ConnectorSide {
  String get storageValue => switch (this) {
    ConnectorSide.top => 'top',
    ConnectorSide.right => 'right',
    ConnectorSide.bottom => 'bottom',
    ConnectorSide.left => 'left',
  };

  static ConnectorSide fromStorage(String value) => switch (value) {
    'top' => ConnectorSide.top,
    'right' => ConnectorSide.right,
    'bottom' => ConnectorSide.bottom,
    'left' => ConnectorSide.left,
    _ => throw ArgumentError('Unknown connector side: $value'),
  };
}

/// A persisted connector between a text-note clip's fixed edge midpoint
/// ([fromSide]) and an image clip ([toClipId]). The target anchor lands at
/// ([toRelX], [toRelY]) - a fraction (0-1) of the target clip's own
/// width/height - when both are set; null falls back to the original
/// nearest-boundary-anchor behavior (see `Connectors` table's doc comment).
class Connector {
  final String id;
  final String boardId;
  final String fromClipId;
  final ConnectorSide fromSide;
  final String toClipId;
  final double? toRelX;
  final double? toRelY;
  final String colorHex;
  final double strokeWidth;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Connector({
    required this.id,
    required this.boardId,
    required this.fromClipId,
    required this.fromSide,
    required this.toClipId,
    this.toRelX,
    this.toRelY,
    required this.colorHex,
    required this.strokeWidth,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Connector.fromRow(ConnectorRow row) => Connector(
    id: row.id,
    boardId: row.boardId,
    fromClipId: row.fromClipId,
    fromSide: ConnectorSideStorage.fromStorage(row.fromSide),
    toClipId: row.toClipId,
    toRelX: row.toRelX,
    toRelY: row.toRelY,
    colorHex: row.color,
    strokeWidth: row.strokeWidth,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
