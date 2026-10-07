// Lists/creates/deletes backup-run folders under the app's documents
// directory - `dart:io` doesn't exist on web, so (like
// save_file_service.dart) this has to be a real conditional export
// rather than a runtime kIsWeb branch. Every caller of these functions
// guards with `kIsWeb` first anyway (automatic backups are native-only
// - see auto_backup_service.dart), so the web/stub variants only need
// to exist to satisfy the conditional export, never to behave
// correctly.
export 'backup_directory_service_stub.dart'
    if (dart.library.js_interop) 'backup_directory_service_web.dart'
    if (dart.library.ffi) 'backup_directory_service_native.dart';
