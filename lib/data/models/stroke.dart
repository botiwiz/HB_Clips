import 'dart:convert';

import 'package:flutter/rendering.dart';

import '../local/database.dart';

/// A vector annotation stroke: either attached to a clip ([clipId] set,
/// points stored as fractions 0..1 of the clip's own width/height so the
/// stroke tracks the clip as it moves/resizes/rotates) or freestanding on
/// the board ([clipId] null, points stored as absolute board-space
/// coordinates). Unlimited count - see `core/constants.dart` for the
/// separate 30-image cap, which strokes never count toward.
class Stroke {
  final String id;
  final String boardId;
  final String? clipId;
  final String colorHex;
  final double strokeWidth;
  final List<Offset> points;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Stroke({
    required this.id,
    required this.boardId,
    this.clipId,
    required this.colorHex,
    required this.strokeWidth,
    required this.points,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Stroke.fromRow(StrokeRow row) => Stroke(
    id: row.id,
    boardId: row.boardId,
    clipId: row.clipId,
    colorHex: row.color,
    strokeWidth: row.strokeWidth,
    points: decodePoints(row.pointsJson),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  static List<Offset> decodePoints(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.map((entry) {
      final pair = entry as List<dynamic>;
      return Offset((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
    }).toList();
  }

  static String encodePoints(List<Offset> points) {
    return jsonEncode(points.map((p) => [p.dx, p.dy]).toList());
  }
}
