// A clip image, rendered from its `LocalBlobStore` key - the web-compatible
// replacement for `Image.file(File(path))`, since `dart:io` doesn't
// compile for Flutter Web at all. Native keeps the exact same
// `Image.file` behavior (highest-traffic rendering path in the app, not
// worth adding indirection to something that already works); web reads
// bytes from `LocalBlobStore` and renders via `Image.memory`, with a
// small in-memory cache so repeated rebuilds don't re-hit IndexedDB.
export 'local_image_stub.dart'
    if (dart.library.js_interop) 'local_image_web.dart'
    if (dart.library.ffi) 'local_image_native.dart';
