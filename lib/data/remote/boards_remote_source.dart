import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';

/// Talks to the `boards` table over PostgREST. [BoardRow.dirty] is local-
/// only sync bookkeeping and is never sent.
class BoardsRemoteSource {
  final SupabaseClient _client;

  BoardsRemoteSource(this._client);

  Future<void> upsert(BoardRow board) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('boards').upsert({
      'id': board.id,
      'user_id': userId,
      'name': board.name,
      'updated_at': board.updatedAt.toIso8601String(),
    });
  }

  Future<void> delete(String id) {
    return _client.from('boards').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('boards').select();
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
