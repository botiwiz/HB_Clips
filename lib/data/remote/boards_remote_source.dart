import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';

/// Talks to the `boards` table remotely. Abstract so sync code can be
/// unit-tested against a fake implementation with no network involved.
abstract class BoardsRemoteSource {
  Future<void> upsert(BoardRow board);
  Future<void> delete(String id);
  Future<List<Map<String, dynamic>>> fetchAll();
}

/// The real implementation, over PostgREST. [BoardRow.dirty] is local-only
/// sync bookkeeping and is never sent.
class SupabaseBoardsRemoteSource implements BoardsRemoteSource {
  final SupabaseClient _client;

  SupabaseBoardsRemoteSource(this._client);

  @override
  Future<void> upsert(BoardRow board) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('boards').upsert({
      'id': board.id,
      'user_id': userId,
      'name': board.name,
      'updated_at': board.updatedAt.toIso8601String(),
    });
  }

  @override
  Future<void> delete(String id) {
    return _client.from('boards').delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('boards').select();
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
