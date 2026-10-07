// `Directory`-returning helper for where this app's local state lives -
// a `boards/` folder next to the running `.exe` on native desktop, making
// the whole install (exe + its data) one portable folder. Never called on
// web, which has no `.exe` to be portable next to and keeps using IndexedDB
// via drift's own web backend.
export 'portable_data_root_stub.dart'
    if (dart.library.js_interop) 'portable_data_root_web.dart'
    if (dart.library.ffi) 'portable_data_root_native.dart';
