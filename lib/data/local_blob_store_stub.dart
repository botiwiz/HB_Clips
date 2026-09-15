import 'dart:typed_data';

import 'local/database.dart';

/// Fallback for a platform that is neither `dart.library.ffi` (native) nor
/// `dart.library.js_interop` (web) - should never actually be selected in
/// this app, but conditional exports require a default target.
class LocalBlobStore {
  // ignore: unused_element_parameter
  LocalBlobStore(AppDatabase db);

  Future<String> writeBytes(Uint8List bytes, {String extension = ''}) {
    throw UnsupportedError('LocalBlobStore is not supported on this platform');
  }

  Future<Uint8List?> readBytes(String key) {
    throw UnsupportedError('LocalBlobStore is not supported on this platform');
  }

  Future<void> delete(String key) {
    throw UnsupportedError('LocalBlobStore is not supported on this platform');
  }
}
