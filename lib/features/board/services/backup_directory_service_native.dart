import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// `<documents>/backups` - created if it doesn't exist yet. The single
/// shared root both AutoBackupScheduler (writes into it) and
/// showBackupsFolder (opens it) resolve independently, so it always
/// exists by the time either is used even if the other never ran yet.
Future<String> backupsRootPath() async {
  final docs = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(docs.path, 'backups'));
  await root.create(recursive: true);
  return root.path;
}

Future<String> createBackupRunFolder(String rootPath, String runName) async {
  final dir = Directory(p.join(rootPath, runName));
  await dir.create(recursive: true);
  return dir.path;
}

/// Run-folder names (not full paths) currently under [rootPath], sorted
/// ascending - callers rely on the timestamp-based naming scheme (see
/// AutoBackupScheduler) making lexicographic order the same as
/// chronological order.
Future<List<String>> listBackupRunFolders(String rootPath) async {
  final dir = Directory(rootPath);
  if (!await dir.exists()) return [];
  final names = [
    for (final entity in dir.listSync())
      if (entity is Directory) p.basename(entity.path),
  ]..sort();
  return names;
}

Future<void> deleteBackupRunFolder(String path) {
  return Directory(path).delete(recursive: true);
}
