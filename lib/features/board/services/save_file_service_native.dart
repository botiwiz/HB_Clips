import 'dart:io';
import 'dart:typed_data';

/// Native: `FilePicker.platform.saveFile` returned a real path - write the
/// bytes there ourselves.
Future<void> writeBytesToPath(String path, Uint8List bytes) {
  return File(path).writeAsBytes(bytes);
}
