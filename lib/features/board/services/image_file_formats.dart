import 'dart:async';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

/// Every image format this app knows how to read off the OS clipboard or a
/// drag-and-drop payload, mapped to the file extension used when writing it
/// to local blob storage. Shared by clipboard paste and drag-and-drop so
/// both recognize exactly the same set of image types.
const imageFileFormats = <SimpleFileFormat, String>{
  Formats.png: '.png',
  Formats.jpeg: '.jpg',
  Formats.gif: '.gif',
  Formats.webp: '.webp',
  Formats.bmp: '.bmp',
  Formats.tiff: '.tiff',
};

/// Returns the first format in [imageFileFormats] that [reader] can
/// provide, or null if it doesn't look like an image at all.
SimpleFileFormat? matchImageFormat(DataReader reader) {
  for (final format in imageFileFormats.keys) {
    if (reader.canProvide(format)) return format;
  }
  return null;
}

/// `getFile` is callback-based even on the otherwise-`Future`-based
/// `DataReader` API, so this wraps it the same way the super_clipboard
/// example app does. Works for both a clipboard read and a drag-and-drop
/// item's reader - `ClipboardReader` and `DropItem.dataReader` are both a
/// `DataReader` under the hood. `getFile`'s default `allowVirtualFiles:
/// true` is what makes this work for a browser-dragged image too (no local
/// file exists yet - the OS/browser generates one on demand).
Future<Uint8List?> readImageFileBytes(DataReader reader, FileFormat format) {
  final completer = Completer<Uint8List?>();
  final progress = reader.getFile(
    format,
    (file) async {
      try {
        completer.complete(await file.readAll());
      } catch (error) {
        completer.completeError(error);
      }
    },
    onError: completer.completeError,
  );
  if (progress == null) completer.complete(null);
  return completer.future;
}
