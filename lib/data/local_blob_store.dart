// Cross-platform local cache for clip image bytes - the web-compatible
// replacement for reading/writing `dart:io` `File`s directly, since
// `dart:io` does not compile for Flutter Web at all.
//
// On native platforms this writes real files under the app's documents
// directory, exactly as before. On web, bytes are cached in a
// local-only Drift table (`LocalBlobs`) instead - never synced, the
// remote copy of an image always lives in Supabase Storage.
//
// Every variant exports an identically-shaped `LocalBlobStore` class
// (same constructor, same three methods) - callers only ever import this
// file and never know which one they got, mirroring the pattern
// `package:drift_flutter` itself uses for `driftDatabase()`.
export 'local_blob_store_stub.dart'
    if (dart.library.js_interop) 'local_blob_store_web.dart'
    if (dart.library.ffi) 'local_blob_store_native.dart';
