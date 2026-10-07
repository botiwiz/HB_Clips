import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The folder the running `.exe` lives in, with a `boards/` subfolder - the
/// single root every piece of this app's local state (the sqlite database,
/// image blobs, and backups) is stored under. Copying or moving the folder
/// that contains the `.exe` takes `boards/` with it, with no dependency on
/// the per-user Documents folder - that's what makes a `build_portable.bat`
/// output folder a genuinely self-contained, portable app.
///
/// Windows-only: this repo also targets Android and Linux, where there is
/// no writable, copyable "folder next to the executable" (an installed
/// APK's path isn't writable at all) - every other native platform keeps
/// using the original `getApplicationDocumentsDirectory()` location
/// unchanged, exactly as before this file existed.
Future<Directory> portableDataRoot() async {
  if (!Platform.isWindows) {
    return getApplicationDocumentsDirectory();
  }
  final exeDir = p.dirname(Platform.resolvedExecutable);
  final root = Directory(p.join(exeDir, 'boards'));
  await root.create(recursive: true);
  await _migrateLegacyDocumentsDataIfNeeded(root);
  return root;
}

/// One-time upgrade path for installs that still have their real data in
/// the old `getApplicationDocumentsDirectory()` location (every build
/// before this portable-storage change). Copies (never moves/deletes) the
/// legacy sqlite file, `clips/`, and `backups/` into the new portable root
/// the first time it finds them, guarded by a marker file so it only ever
/// runs once. Existing clips' stored image paths still point at the old
/// Documents location after this - that copy is left in place so those
/// paths keep resolving - only state written from this point on lives
/// solely under the portable root.
Future<void> _migrateLegacyDocumentsDataIfNeeded(Directory root) async {
  final marker = File(p.join(root.path, '.migrated_from_documents'));
  if (await marker.exists()) return;

  final docs = await getApplicationDocumentsDirectory();
  final legacyDb = File(p.join(docs.path, 'hb_clips.sqlite'));
  if (await legacyDb.exists()) {
    await legacyDb.copy(p.join(root.path, 'hb_clips.sqlite'));
  }
  await _copyDirIfExists(
    Directory(p.join(docs.path, 'clips')),
    Directory(p.join(root.path, 'clips')),
  );
  await _copyDirIfExists(
    Directory(p.join(docs.path, 'backups')),
    Directory(p.join(root.path, 'backups')),
  );

  await marker.writeAsString(DateTime.now().toIso8601String());
}

Future<void> _copyDirIfExists(Directory source, Directory dest) async {
  if (!await source.exists()) return;
  await dest.create(recursive: true);
  await for (final entity in source.list(recursive: true)) {
    final relative = p.relative(entity.path, from: source.path);
    if (entity is Directory) {
      await Directory(p.join(dest.path, relative)).create(recursive: true);
    } else if (entity is File) {
      final target = File(p.join(dest.path, relative));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }
  }
}
