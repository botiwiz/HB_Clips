import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import 'add_image_service.dart';
import 'image_file_formats.dart';

/// Writes [clip]'s image bytes to the OS clipboard in their original
/// format (matched against [imageFileFormats] by `localFilePath`'s
/// extension - falls back to PNG if that ever fails to match, since every
/// format this app reads is also a valid write format, no decode/re-encode
/// round-trip needed) so another application (Photoshop, Slack, Discord,
/// etc.) can paste it. The write-side counterpart to
/// `clipboard_paste_service.dart`'s read-only `pasteFromClipboard`.
Future<void> copyImageToOsClipboard(
  BuildContext context,
  WidgetRef ref,
  BoardClip clip,
) async {
  final path = clip.localFilePath;
  final clipboard = SystemClipboard.instance;
  if (path == null || clipboard == null) {
    showBoardSnack(
      context,
      'Copying an image isn\'t supported here.',
      isError: true,
    );
    return;
  }

  final bytes = await ref.read(localBlobStoreProvider).readBytes(path);
  if (!context.mounted) return;
  if (bytes == null) {
    showBoardSnack(context, 'Could not read that image.', isError: true);
    return;
  }

  final item = DataWriterItem()..add(writeFormatForPath(path)(bytes));
  await clipboard.write([item]);
  if (!context.mounted) return;
  showBoardSnack(context, 'Image copied to clipboard.');
}

/// Picks the [imageFileFormats] writer format matching [path]'s own
/// extension (case-insensitive), falling back to PNG if nothing matches -
/// pulled out as its own pure function so it's testable without a
/// `BuildContext`/`WidgetRef`/real clipboard.
SimpleFileFormat writeFormatForPath(String path) {
  final lowerPath = path.toLowerCase();
  for (final entry in imageFileFormats.entries) {
    if (lowerPath.endsWith(entry.value)) return entry.key;
  }
  return Formats.png;
}
