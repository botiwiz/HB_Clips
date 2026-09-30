import 'package:drift/drift.dart';

import '../local/database.dart';
import '../models/connector.dart';

/// Local read/write API for connectors - same pattern as
/// [StrokesRepository].
class ConnectorsRepository {
  final AppDatabase _db;

  ConnectorsRepository(this._db);

  Stream<List<Connector>> watchConnectors(String boardId) {
    final query = _db.select(_db.connectors)
      ..where((c) => c.boardId.equals(boardId))
      ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]);
    return query.watch().map((rows) => rows.map(Connector.fromRow).toList());
  }

  Future<void> addConnector({
    required String id,
    required String boardId,
    required String fromClipId,
    required ConnectorSide fromSide,
    required String toClipId,
  }) {
    return _db.into(_db.connectors).insert(
      ConnectorsCompanion.insert(
        id: id,
        boardId: boardId,
        fromClipId: fromClipId,
        fromSide: fromSide.storageValue,
        toClipId: toClipId,
      ),
    );
  }

  /// Deletes every connector attached to [clipId] as either endpoint.
  /// Callers are responsible for invoking this when a clip is permanently
  /// deleted (mirrors [StrokesRepository.deleteStrokesForClip] - same
  /// pre-existing scope: wired into `BoardsRepository.deleteBoard`'s
  /// whole-board cascade, not into single-clip permanent delete).
  Future<void> deleteConnectorsForClip(String clipId) {
    return (_db.delete(_db.connectors)..where(
          (c) => c.fromClipId.equals(clipId) | c.toClipId.equals(clipId),
        ))
        .go();
  }

  Future<void> deleteConnector(String id) {
    return (_db.delete(_db.connectors)..where((c) => c.id.equals(id))).go();
  }
}
