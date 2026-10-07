// Web has no ambient, silently-writable filesystem - automatic backups
// are native-only (see auto_backup_service.dart), so these are never
// actually called on web; they exist only to satisfy the conditional
// export in backup_directory_service.dart.

Future<String> backupsRootPath() =>
    throw UnsupportedError('backupsRootPath is not supported on this platform');

Future<String> createBackupRunFolder(String rootPath, String runName) =>
    throw UnsupportedError(
      'createBackupRunFolder is not supported on this platform',
    );

Future<List<String>> listBackupRunFolders(String rootPath) =>
    throw UnsupportedError(
      'listBackupRunFolders is not supported on this platform',
    );

Future<void> deleteBackupRunFolder(String path) => throw UnsupportedError(
  'deleteBackupRunFolder is not supported on this platform',
);
