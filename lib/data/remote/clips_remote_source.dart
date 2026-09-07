import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clip.dart';

/// Talks to the `clips` table remotely. Abstract so sync code (the
/// drainer, the reconciliation pull) can be unit-tested against a fake
/// implementation with no network involved - see
/// `test/data/sync/sync_queue_drainer_test.dart`.
abstract class ClipsRemoteSource {
  Future<void> upsert(BoardClip clip);
  Future<void> delete(String id);

  /// All of the current user's clips, for the reconciliation pull.
  Future<List<Map<String, dynamic>>> fetchAll();
}

/// The real implementation, over PostgREST. The single place that
/// translates [BoardClip]'s camelCase shape into the Postgres schema's
/// snake_case columns, and stamps `user_id` onto every write - local
/// Drift rows never carry it, RLS requires it.
class SupabaseClipsRemoteSource implements ClipsRemoteSource {
  final SupabaseClient _client;

  SupabaseClipsRemoteSource(this._client);

  @override
  Future<void> upsert(BoardClip clip) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('clips').upsert({
      'id': clip.id,
      'board_id': clip.boardId,
      'user_id': userId,
      'type': clip.type.storageValue,
      'x': clip.x,
      'y': clip.y,
      'width': clip.width,
      'height': clip.height,
      'rotation': clip.rotation,
      'z_index': clip.zIndex,
      'opacity': clip.opacity,
      'text_content': clip.textContent,
      'background_color_hex': clip.backgroundColorHex,
      'group_id': clip.groupId,
      'storage_path': clip.storagePath,
      'is_binned': clip.isBinned,
      'binned_at': clip.binnedAt?.toIso8601String(),
      'updated_at': clip.updatedAt.toIso8601String(),
    });
  }

  @override
  Future<void> delete(String id) {
    return _client.from('clips').delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('clips').select();
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
