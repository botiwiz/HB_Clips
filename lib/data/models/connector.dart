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
/// ([fromSide]) and an image clip ([toClipId]) - see the `Connectors`
/// table's doc comment for why the target side isn't stored.
class Connector {
  final String id;
  final String boardId;
  final String fromClipId;
  final ConnectorSide fromSide;
  final String toClipId;
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
    colorHex: row.color,
    strokeWidth: row.strokeWidth,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
