import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stroke.dart';

/// Talks to the `strokes` table remotely. Abstract so sync code can be
/// unit-tested against a fake implementation with no network involved.
abstract class StrokesRemoteSource {
  Future<void> upsert(Stroke stroke);
  Future<void> delete(String id);
  Future<List<Map<String, dynamic>>> fetchAll();
}

/// The real implementation, over PostgREST. `points` is stored as `jsonb`
/// remotely - sent as a plain nested list, not the locally-used JSON-
/// encoded string column, so PostgREST serializes it as real JSON.
class SupabaseStrokesRemoteSource implements StrokesRemoteSource {
  final SupabaseClient _client;

  SupabaseStrokesRemoteSource(this._client);

  @override
  Future<void> upsert(Stroke stroke) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('strokes').upsert({
      'id': stroke.id,
      'board_id': stroke.boardId,
      'clip_id': stroke.clipId,
      'user_id': userId,
      'color': stroke.colorHex,
      'stroke_width': stroke.strokeWidth,
      'points': stroke.points.map((p) => [p.dx, p.dy]).toList(),
      'dashed': stroke.dashed,
      'arrow_end': stroke.arrowEnd,
      'updated_at': stroke.updatedAt.toIso8601String(),
    });
  }

  @override
  Future<void> delete(String id) {
    return _client.from('strokes').delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('strokes').select();
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
