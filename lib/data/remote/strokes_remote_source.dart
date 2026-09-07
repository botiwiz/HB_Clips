import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stroke.dart';

/// Talks to the `strokes` table over PostgREST. `points` is stored as
/// `jsonb` remotely - sent as a plain nested list, not the locally-used
/// JSON-encoded string column, so PostgREST serializes it as real JSON.
class StrokesRemoteSource {
  final SupabaseClient _client;

  StrokesRemoteSource(this._client);

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

  Future<void> delete(String id) {
    return _client.from('strokes').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('strokes').select();
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
