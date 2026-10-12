import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/constants.dart' show kBoardBackupExtension;

/// Reads every `.hbbackup` file directly inside [folderPath] (not
/// recursive - a nested old-style dated backup run folder is not
/// descended into), keyed by filename. Returns an empty map if the
/// folder doesn't exist.
Future<Map<String, Uint8List>> readBackupFilesInFolder(
  String folderPath,
) async {
  final dir = Directory(folderPath);
  if (!await dir.exists()) return {};
  final result = <String, Uint8List>{};
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    if (p.extension(entity.path).toLowerCase() != '.$kBoardBackupExtension') {
      continue;
    }
    result[p.basename(entity.path)] = await entity.readAsBytes();
  }
  return result;
}
