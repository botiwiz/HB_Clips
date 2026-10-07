import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/portable_data_root.dart';
import 'local/database.dart';

const _uuid = Uuid();

/// Native implementation: a key is a real filesystem path under
/// [portableDataRoot]'s `clips/` subfolder.
class LocalBlobStore {
  // ignore: unused_element_parameter
  LocalBlobStore(AppDatabase db);

  Future<String> writeBytes(Uint8List bytes, {String extension = ''}) async {
    final root = await portableDataRoot();
    final clipsDir = Directory(p.join(root.path, 'clips'));
    await clipsDir.create(recursive: true);
    final path = p.join(clipsDir.path, '${_uuid.v4()}$extension');
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<Uint8List?> readBytes(String key) async {
    final file = File(key);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> delete(String key) async {
    final file = File(key);
    if (await file.exists()) await file.delete();
  }
}
