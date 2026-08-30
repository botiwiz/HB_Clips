import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/clips_repository.dart';
import '../controllers/board_controller.dart';

const _uuid = Uuid();

const _imageFormats = <SimpleFileFormat, String>{
  Formats.png: '.png',
  Formats.jpeg: '.jpg',
  Formats.gif: '.gif',
  Formats.webp: '.webp',
  Formats.bmp: '.bmp',
  Formats.tiff: '.tiff',
};

/// `getFile` is callback-based even on the async `ClipboardReader` - only
/// `readValue` is natively `Future`-based - so this wraps it the same way
/// the super_clipboard example app does.
Future<Uint8List?> _readFileBytes(ClipboardReader reader, FileFormat format) {
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

void _showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppTheme.danger : null,
    ),
  );
}

/// Reads an image off the OS clipboard (e.g. a pasted screenshot) and adds
/// it as a new image clip, mirroring how file-picker imports are handled in
/// `board_screen.dart`. Shared by the Ctrl+V shortcut and the paste toolbar
/// button so there is exactly one code path.
Future<void> pasteImageFromClipboard(BuildContext context, WidgetRef ref) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    _showSnack(context, 'Clipboard access is not available on this platform.');
    return;
  }

  final reader = await clipboard.read();
  if (!context.mounted) return;
  SimpleFileFormat? matchedFormat;
  for (final format in _imageFormats.keys) {
    if (reader.canProvide(format)) {
      matchedFormat = format;
      break;
    }
  }
  if (matchedFormat == null) {
    _showSnack(context, 'No image found on the clipboard.');
    return;
  }

  final Uint8List? bytes;
  try {
    bytes = await _readFileBytes(reader, matchedFormat);
  } catch (_) {
    if (!context.mounted) return;
    _showSnack(context, "Couldn't read the image from the clipboard.", isError: true);
    return;
  }
  if (bytes == null || bytes.isEmpty) {
    if (!context.mounted) return;
    _showSnack(context, 'No image found on the clipboard.');
    return;
  }

  final id = _uuid.v4();
  final supportDir = await getApplicationSupportDirectory();
  final clipsDir = Directory(p.join(supportDir.path, 'clips'));
  await clipsDir.create(recursive: true);
  final destPath = p.join(clipsDir.path, '$id${_imageFormats[matchedFormat]}');
  await File(destPath).writeAsBytes(bytes);

  if (!context.mounted) return;
  final size = MediaQuery.sizeOf(context);
  final screenCenter = Offset(size.width / 2, size.height / 2);
  final view = ref.read(boardViewProvider);
  final center = (screenCenter - view.panOffset) / view.scale;

  try {
    await ref
        .read(clipsRepositoryProvider)
        .addImageClip(
          id: id,
          boardId: ref.read(currentBoardIdProvider),
          localFilePath: destPath,
          x: center.dx - kDefaultClipWidth / 2,
          y: center.dy - kDefaultClipHeight / 2,
        );
  } on ClipCapExceededException {
    if (!context.mounted) return;
    _showSnack(
      context,
      'You\'ve reached the $kMaxImageClips image clip limit. '
      'Bin or delete one to add another.',
      isError: true,
    );
  }
}
