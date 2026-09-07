import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';

import '../local/database.dart';
import '../remote/boards_remote_source.dart';
import '../remote/clips_remote_source.dart';
import '../remote/strokes_remote_source.dart';
import 'realtime_listener.dart';
import 'sync_queue_drainer.dart';

/// Ties the outbox drainer and the realtime listener together: starts
/// realtime, drains + reconciles on regaining connectivity and on a
/// periodic timer, and never sits on the critical path of any UI-facing
/// repository call (every method here is fire-and-forget from the
/// caller's perspective).
class SyncEngine {
  final AppDatabase _db;
  final SyncQueueDrainer _drainer;
  final RealtimeListener _realtime;
  final ClipsRemoteSource _clipsRemote;
  final StrokesRemoteSource _strokesRemote;
  final BoardsRemoteSource _boardsRemote;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  bool _started = false;

  SyncEngine(
    this._db,
    this._drainer,
    this._realtime,
    this._clipsRemote,
    this._strokesRemote,
    this._boardsRemote, {
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _realtime.start();
    unawaited(_drainAndReconcile());

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        unawaited(_drainAndReconcile());
      }
    });

    _periodicTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_drainer.drainOnce()),
    );
  }

  Future<void> stop() async {
    _started = false;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    await _realtime.stop();
  }

  Future<void> _drainAndReconcile() async {
    await _drainer.drainOnce();
    await reconcile();
  }

  /// Full pull + diff against the local id set, per table. Every fetched
  /// remote row is re-applied through the same LWW-gated logic the live
  /// realtime path uses (self-correcting for any change missed while
  /// offline, not just ones that are missing locally). Local ids missing
  /// from the remote set get deleted locally, unless the row is `dirty`
  /// or its own upsert hasn't been pushed yet (either would mean it's a
  /// genuinely new local row the server just doesn't know about yet, not
  /// a server-side delete that happened while offline).
  ///
  /// Public - triggered automatically on reconnect/periodic ticks, but
  /// also a reasonable thing for a future "sync now" UI action to call
  /// directly.
  Future<void> reconcile() async {
    await _reconcileClips();
    await _reconcileStrokes();
    await _reconcileBoards();
  }

  Future<Set<String>> _pendingUpsertIds(String entityType) async {
    final rows = await (_db.select(_db.syncQueueEntries)..where(
          (e) =>
              e.entityType.equals(entityType) & e.operation.equals('upsert'),
        ))
        .get();
    return rows.map((e) => e.entityId).toSet();
  }

  Future<void> _reconcileClips() async {
    final remoteRows = await _clipsRemote.fetchAll();
    for (final r in remoteRows) {
      await _realtime.applyClipRecord(r);
    }

    final remoteIds = remoteRows.map((r) => r['id'] as String).toSet();
    final pendingUpsertIds = await _pendingUpsertIds('clip');
    final localRows = await _db.select(_db.clips).get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id)) continue;
      if (row.dirty || pendingUpsertIds.contains(row.id)) continue;
      await (_db.delete(_db.clips)..where((c) => c.id.equals(row.id))).go();
    }
  }

  Future<void> _reconcileStrokes() async {
    final remoteRows = await _strokesRemote.fetchAll();
    for (final r in remoteRows) {
      await _realtime.applyStrokeRecord(r);
    }

    final remoteIds = remoteRows.map((r) => r['id'] as String).toSet();
    final pendingUpsertIds = await _pendingUpsertIds('stroke');
    final localRows = await _db.select(_db.strokes).get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id)) continue;
      if (row.dirty || pendingUpsertIds.contains(row.id)) continue;
      await (_db.delete(_db.strokes)..where((s) => s.id.equals(row.id))).go();
    }
  }

  Future<void> _reconcileBoards() async {
    final remoteRows = await _boardsRemote.fetchAll();
    for (final r in remoteRows) {
      await _realtime.applyBoardRecord(r);
    }

    final remoteIds = remoteRows.map((r) => r['id'] as String).toSet();
    final pendingUpsertIds = await _pendingUpsertIds('board');
    final localRows = await _db.select(_db.boards).get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id)) continue;
      if (row.dirty || pendingUpsertIds.contains(row.id)) continue;
      await (_db.delete(_db.boards)..where((b) => b.id.equals(row.id))).go();
    }
  }
}
