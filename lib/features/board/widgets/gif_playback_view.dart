import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart' show ImagePanZoomLive;
import '../services/gif_controller_service.dart';
import 'image_pan_zoom_frame.dart';
import 'local_image.dart';

/// Renders a GIF clip's currently-selected frame once its frames have been
/// decoded via [GifPlaybackController], falling back to the ordinary
/// autoplaying `Image.file` while decoding is still in flight - so there's
/// no blank/flash gap on first selection.
class GifPlaybackView extends ConsumerStatefulWidget {
  final String clipId;
  final String path;
  final BoardClip clip;
  final ImagePanZoomLive? panZoomLive;

  const GifPlaybackView({
    super.key,
    required this.clipId,
    required this.path,
    required this.clip,
    this.panZoomLive,
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
      return ImagePanZoomFrame(
        clip: widget.clip,
        live: widget.panZoomLive,
        imageBuilder: (width, height) =>
            LocalImage(path: widget.path, fit: BoxFit.fill, width: width, height: height),
      );
    }
    return ImagePanZoomFrame(
      clip: widget.clip,
      live: widget.panZoomLive,
      imageBuilder: (width, height) => RawImage(
        image: state.frames[state.currentFrame].image,
        fit: BoxFit.fill,
        width: width,
        height: height,
      ),
    );
  }
}
