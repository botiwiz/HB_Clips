import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import 'image_size_service.dart';

const _uuid = Uuid();

void showBoardSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppTheme.danger : null,
    ),
  );
}

/// Writes [bytes] to local blob storage and adds an image clip centered at
/// [boardCenter], sized to preserve the image's own aspect ratio. Shared by
/// clipboard paste and drag-and-drop - the only two ways an image's raw
/// bytes (rather than an already-on-disk file the user picked) become a
/// clip.
Future<void> addImageClipFromBytes(
  WidgetRef ref, {
  required Uint8List bytes,
  required String extension,
  required Offset boardCenter,
}) async {
  final id = _uuid.v4();
  final destPath = await ref
      .read(localBlobStoreProvider)
      .writeBytes(bytes, extension: extension);

  final clipSize = clipSizeForImageBytes(bytes);
  await ref
      .read(clipsRepositoryProvider)
      .addImageClip(
        id: id,
        boardId: ref.read(currentBoardIdProvider),
        localFilePath: destPath,
        x: boardCenter.dx - clipSize.width / 2,
        y: boardCenter.dy - clipSize.height / 2,
        width: clipSize.width,
        height: clipSize.height,
        imageAspectRatio: imageAspectRatioForBytes(bytes),
      );
}
