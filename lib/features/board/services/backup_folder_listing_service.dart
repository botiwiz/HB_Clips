// Reads every `.hbbackup` file directly inside a chosen folder - `dart:io`
// doesn't exist on web, so (like save_file_service.dart/the old
// backup_directory_service.dart) this has to be a real conditional export
// rather than a runtime kIsWeb branch. Every caller guards with kIsWeb
// first anyway (Load is native-only - see backup_folder_service.dart), so
// the web/stub variants only need to exist to satisfy the conditional
// export, never to behave correctly.
export 'backup_folder_listing_service_stub.dart'
    if (dart.library.js_interop) 'backup_folder_listing_service_web.dart'
    if (dart.library.ffi) 'backup_folder_listing_service_native.dart';
