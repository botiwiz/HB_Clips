// Fallback for a platform that is neither web nor native (dart:ffi) -
// never actually reached in this app; exists only to satisfy the
// conditional export in backup_folder_listing_service.dart.
import 'dart:typed_data';

Future<Map<String, Uint8List>> readBackupFilesInFolder(String folderPath) =>
    throw UnsupportedError(
      'readBackupFilesInFolder is not supported on this platform',
    );
