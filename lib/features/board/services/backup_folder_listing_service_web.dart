// Web has no ambient, readable-by-path filesystem - Load is native-only
// (see backup_folder_service.dart), so this is never actually called on
// web; it exists only to satisfy the conditional export in
// backup_folder_listing_service.dart.
import 'dart:typed_data';

Future<Map<String, Uint8List>> readBackupFilesInFolder(String folderPath) =>
    throw UnsupportedError(
      'readBackupFilesInFolder is not supported on this platform',
    );
