import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/clip.dart';
import '../../data/providers.dart';

/// Permanently deletes [clip]: its local image file (best-effort), any
/// strokes attached to it, then the clip row itself - in that order, since
/// once the row is gone there's nothing left to look up the file path or
/// stroke ownership from. Lives here rather than in `ClipsRepository` so
/// the repositories stay decoupled from each other and from `dart:io`.
Future<void> _deleteClipForever(WidgetRef ref, BoardClip clip) async {
  final path = clip.localFilePath;
  if (clip.type == ClipType.image && path != null) {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort: a missing/unreadable file shouldn't block deletion.
    }
  }
  await ref.read(strokesRepositoryProvider).deleteStrokesForClip(clip.id);
  await ref.read(clipsRepositoryProvider).deleteForever(clip.id);
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete Forever'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class BinScreen extends ConsumerWidget {
  const BinScreen({super.key});

  Future<void> _emptyBin(
    BuildContext context,
    WidgetRef ref,
    List<BoardClip> binned,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Empty bin?',
      message:
          'This will permanently delete ${binned.length} '
          '${binned.length == 1 ? 'item' : 'items'}. This can\'t be undone.',
    );
    if (!confirmed) return;
    for (final clip in binned) {
      await _deleteClipForever(ref, clip);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binned = ref.watch(binnedClipsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bin'),
        actions: [
          if (binned.isNotEmpty)
            TextButton.icon(
              onPressed: () => _emptyBin(context, ref, binned),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Empty Bin'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: binned.isEmpty
          ? const Center(
              child: Text(
                'Nothing in the bin.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Binned image clips still count toward your 30-image '
                    'limit until deleted forever.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: binned.length,
                    itemBuilder: (context, index) =>
                        _BinnedClipTile(clip: binned[index]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BinnedClipTile extends ConsumerWidget {
  final BoardClip clip;

  const _BinnedClipTile({required this.clip});

  Future<void> _deleteForever(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Delete forever?',
      message: 'This can\'t be undone.',
    );
    if (!confirmed) return;
    await _deleteClipForever(ref, clip);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(child: _preview()),
          TextButton.icon(
            onPressed: () =>
                ref.read(clipsRepositoryProvider).restoreClip(clip.id),
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restore'),
          ),
          TextButton.icon(
            onPressed: () => _deleteForever(context, ref),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            icon: const Icon(Icons.delete_forever_outlined, size: 16),
            label: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (clip.type == ClipType.text) {
      return Container(
        width: double.infinity,
        color: const Color(0xFFFFF3B0),
        padding: const EdgeInsets.all(8),
        child: Text(
          clip.textContent ?? '',
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black87, fontSize: 12),
        ),
      );
    }
    final path = clip.localFilePath;
    if (path == null) {
      return const Icon(Icons.broken_image_outlined, color: Colors.white38);
    }
    return Image.file(File(path), fit: BoxFit.cover, width: double.infinity);
  }
}
