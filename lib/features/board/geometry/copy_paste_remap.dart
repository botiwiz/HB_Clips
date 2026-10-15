import '../../../data/models/connector.dart';
import '../../../data/models/stroke.dart';

/// Rebuilds [connectors] against [clipIdMap] (old clip id -> newly pasted
/// clip id) on [targetBoardId] - a connector whose endpoint isn't in
/// [clipIdMap] is dropped rather than pasted dangling (shouldn't normally
/// happen, since callers only ever pass connectors fully inside the
/// copied selection). [newId]/[now] are injected rather than called
/// directly so the same new ids can be reused by both the initial paste
/// and a later redo, and so this stays a pure, clock/uuid-free function
/// for testing.
List<Connector> remapConnectorsForPaste(
  List<Connector> connectors,
  Map<String, String> clipIdMap,
  String targetBoardId, {
  required String Function() newId,
  required DateTime Function() now,
}) {
  final result = <Connector>[];
  for (final c in connectors) {
    final from = clipIdMap[c.fromClipId];
    final to = clipIdMap[c.toClipId];
    if (from == null || to == null) continue;
    final timestamp = now();
    result.add(
      Connector(
        id: newId(),
        boardId: targetBoardId,
        fromClipId: from,
        fromSide: c.fromSide,
        toClipId: to,
        toRelX: c.toRelX,
        toRelY: c.toRelY,
        colorHex: c.colorHex,
        strokeWidth: c.strokeWidth,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }
  return result;
}

/// [remapConnectorsForPaste]'s counterpart for strokes - every stroke
/// passed in is expected to already be clip-attached (`clipId != null`),
/// since there's no selection mechanism that would bring a freestanding
/// stroke along with a copy in the first place; one is dropped
/// defensively if its `clipId` doesn't resolve through [clipIdMap].
List<Stroke> remapStrokesForPaste(
  List<Stroke> strokes,
  Map<String, String> clipIdMap,
  String targetBoardId, {
  required String Function() newId,
  required DateTime Function() now,
}) {
  final result = <Stroke>[];
  for (final s in strokes) {
    final newClipId = s.clipId == null ? null : clipIdMap[s.clipId];
    if (s.clipId != null && newClipId == null) continue;
    final timestamp = now();
    result.add(
      Stroke(
        id: newId(),
        boardId: targetBoardId,
        clipId: newClipId,
        colorHex: s.colorHex,
        strokeWidth: s.strokeWidth,
        points: s.points,
        dashed: s.dashed,
        arrowEnd: s.arrowEnd,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }
  return result;
}
