import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'local/database.dart';

const _uuid = Uuid();

/// Web implementation: bytes live in the local-only `LocalBlobs` Drift
/// table (itself backed by IndexedDB via `driftDatabase()`'s web/WASM
/// path), keyed by a generated id. [extension] is appended to that key
/// (e.g. `<uuid>.png`) purely so callers that derive a file's extension
/// from `Clip.localFilePath` (Storage's upload path, GIF detection) keep
/// working unchanged on web even though the key is opaque, not a real
/// path - it never touches the filesystem or is parsed back apart here.
class LocalBlobStore {
  final AppDatabase _db;

  LocalBlobStore(this._db);

  Future<String> writeBytes(Uint8List bytes, {String extension = ''}) async {
    final key = '${_uuid.v4()}$extension';
    await _db
        .into(_db.localBlobs)
        .insert(LocalBlobsCompanion.insert(id: key, bytes: bytes));
    return key;
  }

  Future<Uint8List?> readBytes(String key) async {
    final row = await (_db.select(
      _db.localBlobs,
    )..where((b) => b.id.equals(key))).getSingleOrNull();
    return row?.bytes;
  }

  Future<void> delete(String key) async {
    await (_db.delete(_db.localBlobs)..where((b) => b.id.equals(key))).go();
  }
}
