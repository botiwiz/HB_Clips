import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/clip.dart';
import '../../data/providers.dart';

/// Minimal Bin screen for Phase 1: list binned clips, restore them.
/// Delete Forever / Empty Bin with confirmation land in Phase 4 polish.
class BinScreen extends ConsumerWidget {
  const BinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binned = ref.watch(binnedClipsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Bin')),
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
                          childAspectRatio: 0.85,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(child: _preview()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(clipsRepositoryProvider).restoreClip(clip.id),
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restore'),
            ),
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
