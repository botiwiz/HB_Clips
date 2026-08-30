import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../annotation/stroke_painter.dart';

/// Renders one clip's content (image or text note) at its given size. The
/// caller (`BoardCanvas`) is responsible for positioning this via
/// `Positioned` in board space - this widget just draws the card itself.
class ClipWidget extends StatelessWidget {
  final BoardClip clip;
  final bool selected;

  const ClipWidget({super.key, required this.clip, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: clip.opacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.red : AppTheme.border,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          color: clip.type == ClipType.text
              ? (clip.backgroundColorHex != null
                    ? hexToColor(clip.backgroundColorHex!)
                    : AppTheme.textNoteSurface)
              : AppTheme.surfaceCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: clip.type == ClipType.image ? _buildImage() : _buildText(),
      ),
    );
  }

  Widget _buildImage() {
    final path = clip.localFilePath;
    if (path == null) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppTheme.textDisabled,
        ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppTheme.textDisabled,
        ),
      ),
    );
  }

  Widget _buildText() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        clip.textContent ?? '',
        style: const TextStyle(
          color: AppTheme.textNoteText,
          fontSize: 14,
          height: 1.3,
        ),
      ),
    );
  }
}
