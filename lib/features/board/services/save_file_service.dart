// Writes bytes to a path chosen via `FilePicker.platform.saveFile`. On
// native platforms `saveFile` returns a real path the app has to write to
// itself; on web, passing `bytes:` into `saveFile` already triggers a
// browser download, so nothing further needs to happen there - `dart:io`
// doesn't exist on web at all, so this has to be a real conditional
// export rather than a runtime `kIsWeb` branch.
export 'save_file_service_stub.dart'
    if (dart.library.js_interop) 'save_file_service_web.dart'
    if (dart.library.ffi) 'save_file_service_native.dart';
