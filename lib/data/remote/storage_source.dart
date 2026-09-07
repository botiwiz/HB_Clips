import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _clipImagesBucket = 'clip-images';

/// Uploads/downloads image clip files. Abstract so sync code can be
/// unit-tested against a fake implementation with no network involved.
abstract class StorageSource {
  /// Uploads [localFile] and returns the `storage_path` to persist on the
  /// clip's row.
  Future<String> uploadImage({
    required String userId,
    required String clipId,
    required File localFile,
  });

  /// Downloads a remote image (from another device) into the local clips
  /// cache directory, returning the local file path to store as
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
/// the local file actually is) rather than hardcoding `.jpg` - GIF
/// playback (the `L` sub-phase) depends on the extension surviving the
/// round trip through Storage.
class SupabaseStorageSource implements StorageSource {
  final SupabaseClient _client;

  SupabaseStorageSource(this._client);

  String _pathFor(String userId, String clipId, String localFilePath) {
    final ext = p.extension(localFilePath);
    return '$userId/$clipId/original$ext';
  }

  @override
  Future<String> uploadImage({
    required String userId,
    required String clipId,
    required File localFile,
  }) async {
    final storagePath = _pathFor(userId, clipId, localFile.path);
    await _client.storage
        .from(_clipImagesBucket)
        .upload(storagePath, localFile, fileOptions: const FileOptions(upsert: true));
    return storagePath;
  }

  @override
  Future<String> downloadImage({
    required String clipId,
    required String storagePath,
  }) async {
    final bytes = await _client.storage.from(_clipImagesBucket).download(storagePath);
    final supportDir = await getApplicationSupportDirectory();
    final clipsDir = Directory(p.join(supportDir.path, 'clips'));
    await clipsDir.create(recursive: true);
    final ext = p.extension(storagePath);
    final destPath = p.join(clipsDir.path, '$clipId$ext');
    await File(destPath).writeAsBytes(bytes);
    return destPath;
  }
}
