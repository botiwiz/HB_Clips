import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The folder the running app lives in, with a `boards/` subfolder - the
/// single root every piece of this app's local state (the sqlite database,
/// image blobs, and backups) is stored under. Copying or moving that folder
/// takes `boards/` with it, with no dependency on the per-user Documents
/// folder - that's what makes a `build_portable.bat` output folder (Windows)
/// or an AppImage (Linux) a genuinely self-contained, portable app: drop the
/// exe/AppImage anywhere, and its data folder travels right alongside it.
///
/// Windows and Linux only: this repo also targets Android, where there is
/// no writable, copyable "folder next to the executable" (an installed
/// APK's path isn't writable at all) - that platform keeps using the
/// original `getApplicationDocumentsDirectory()` location unchanged, exactly
/// as before this file existed.
Future<Directory> portableDataRoot() async {
  if (!Platform.isWindows && !Platform.isLinux) {
    return getApplicationDocumentsDirectory();
  }
  final exeDir = p.dirname(_appDirectoryPath());
  final root = Directory(p.join(exeDir, 'boards'));
  await root.create(recursive: true);
  await _migrateLegacyDocumentsDataIfNeeded(root);
  return root;
}

/// The path of the running executable, or - on Linux, when launched from
/// an AppImage - the path of the `.AppImage` file itself.
///
/// An AppImage runs its payload from a temporary FUSE mount (e.g.
/// `/tmp/.mount_XXXXXX/...`) that's unmounted the moment the app exits, so
/// `Platform.resolvedExecutable` alone would resolve a `boards/` folder
/// that's wiped out between runs. The AppImage runtime sets the `APPIMAGE`
/// environment variable to the real, stable path of the `.AppImage` file
/// the user actually placed somewhere - that's what "next to the AppImage"
/// has to mean. Outside of an AppImage (a plain unpacked Linux bundle, or
/// Windows), there's no such mount to work around, so this is just
/// `Platform.resolvedExecutable`.
String _appDirectoryPath() {
  final appImagePath = Platform.environment['APPIMAGE'];
  if (Platform.isLinux && appImagePath != null && appImagePath.isNotEmpty) {
    return appImagePath;
  }
  return Platform.resolvedExecutable;
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
