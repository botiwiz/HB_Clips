import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Native: `FilePicker.platform.saveFile` returned a real path - write the
/// bytes there ourselves.
Future<void> writeBytesToPath(String path, Uint8List bytes) {
  return File(path).writeAsBytes(bytes);
}

/// Writes then immediately deletes a tiny marker file inside [folderPath] -
/// throws if either step fails. Used by `backup_folder_service.dart`'s
/// `pickBackupFolder` to catch a folder-picker result that looks like a
/// valid path but isn't actually writable (e.g. an xdg-desktop-portal-
/// confined path on some Linux desktops) right at selection time, instead
/// of failing later, more confusingly, during an actual Save/Load.
Future<void> probeFolderWritable(String folderPath) async {
  final probe = File(p.join(folderPath, '.hb_clips_write_test'));
  await probe.writeAsBytes(const [0]);
  await probe.delete();
}
