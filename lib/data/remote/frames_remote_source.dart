import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';

/// Talks to the `frames` table remotely. Abstract so sync code can be
/// unit-tested against a fake implementation with no network involved.
abstract class FramesRemoteSource {
  Future<void> upsert(FrameRow frame);
  Future<void> delete(String id);
  Future<List<Map<String, dynamic>>> fetchAll();
}

/// The real implementation, over PostgREST. [FrameRow.dirty] is
/// local-only sync bookkeeping and is never sent.
class SupabaseFramesRemoteSource implements FramesRemoteSource {
  final SupabaseClient _client;

  SupabaseFramesRemoteSource(this._client);

  @override
  Future<void> upsert(FrameRow frame) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('frames').upsert({
      'id': frame.id,
      'board_id': frame.boardId,
      'user_id': userId,
      'name': frame.name,
      'x': frame.x,
      'y': frame.y,
      'width': frame.width,
      'height': frame.height,
      'updated_at': frame.updatedAt.toIso8601String(),
    });
  }

  @override
  Future<void> delete(String id) {
    return _client.from('frames').delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('frames').select();
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
