import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../services/gif_controller_service.dart';
import 'local_image.dart';

/// Renders a GIF clip's currently-selected frame once its frames have been
/// decoded via [GifPlaybackController], falling back to the ordinary
/// autoplaying `Image.file` while decoding is still in flight - so there's
/// no blank/flash gap on first selection.
class GifPlaybackView extends ConsumerStatefulWidget {
  final String clipId;
  final String path;

  const GifPlaybackView({
    super.key,
    required this.clipId,
    required this.path,
  });

  @override
  ConsumerState<GifPlaybackView> createState() => _GifPlaybackViewState();
}

class _GifPlaybackViewState extends ConsumerState<GifPlaybackView> {
  late final GifPlaybackController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(gifPlaybackControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bytes = await ref
          .read(localBlobStoreProvider)
          .readBytes(widget.path);
      if (!mounted || bytes == null) return;
      _controller.openClip(widget.clipId, bytes);
    });
  }

  @override
  void dispose() {
    if (ref.read(gifPlaybackControllerProvider)?.clipId == widget.clipId) {
      _controller.closeClip();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gifPlaybackControllerProvider);
    if (state == null || state.clipId != widget.clipId || state.frames.isEmpty) {
      return LocalImage(
        path: widget.path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return RawImage(
      image: state.frames[state.currentFrame].image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
