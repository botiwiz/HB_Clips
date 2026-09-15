import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_blob_store.dart';

const _clipImagesBucket = 'clip-images';

/// Uploads/downloads image clip bytes. Abstract so sync code can be
/// unit-tested against a fake implementation with no network involved.
/// Byte-oriented rather than `File`-oriented so this compiles and works
/// identically on web, where `dart:io` doesn't exist.
abstract class StorageSource {
  /// Uploads [bytes] and returns the `storage_path` to persist on the
  /// clip's row. [extension] (e.g. `.png`, `.gif`) becomes part of that
  /// path, matching the bucket's RLS-keyed `{user_id}/{clip_id}/original{ext}`
  /// convention.
  Future<String> uploadImage({
    required String userId,
    required String clipId,
    required Uint8List bytes,
    required String extension,
  });

  /// Downloads a remote image (from another device) into the local clips
  /// cache ([LocalBlobStore]), returning the key to store as
  /// `local_file_path`.
  Future<String> downloadImage({
    required String clipId,
    required String storagePath,
  });
}

/// The real implementation, over Supabase Storage's `clip-images` bucket,
/// at the path convention `{user_id}/{clip_id}/original{ext}` the bucket's
/// RLS policies (`supabase/migrations/0001_init.sql`) key on.
///
/// The real source extension is preserved (`.png`/`.gif`/`.jpg`, whatever
/// the image actually is) rather than hardcoding `.jpg` - GIF playback (the
/// `L` sub-phase) depends on the extension surviving the round trip
/// through Storage.
class SupabaseStorageSource implements StorageSource {
  final SupabaseClient _client;
  final LocalBlobStore _blobStore;

  SupabaseStorageSource(this._client, this._blobStore);

  String _pathFor(String userId, String clipId, String extension) {
    return '$userId/$clipId/original$extension';
  }

  @override
  Future<String> uploadImage({
    required String userId,
    required String clipId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final storagePath = _pathFor(userId, clipId, extension);
    await _client.storage
        .from(_clipImagesBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return storagePath;
  }

  @override
  Future<String> downloadImage({
    required String clipId,
    required String storagePath,
  }) async {
    final bytes = await _client.storage
        .from(_clipImagesBucket)
        .download(storagePath);
    return _blobStore.writeBytes(bytes, extension: p.extension(storagePath));
  }
}
