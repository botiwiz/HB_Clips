import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One decoded GIF frame - the raster image plus how long it should be
/// shown at 1x speed.
class GifFrame {
  final ui.Image image;
  final Duration duration;

  const GifFrame({required this.image, required this.duration});
}

/// Playback state for whichever GIF clip is currently being interactively
/// controlled (only the selected clip gets this - every other GIF clip
/// keeps using the zero-cost `Image.file` autoplay).
class GifPlaybackState {
  final String clipId;
  final List<GifFrame> frames;
  final int currentFrame;
  final bool playing;
  final double speed;

  const GifPlaybackState({
    required this.clipId,
    required this.frames,
    required this.currentFrame,
    required this.playing,
    required this.speed,
  });

  GifPlaybackState copyWith({
    int? currentFrame,
    bool? playing,
    double? speed,
  }) {
    return GifPlaybackState(
      clipId: clipId,
      frames: frames,
      currentFrame: currentFrame ?? this.currentFrame,
      playing: playing ?? this.playing,
      speed: speed ?? this.speed,
    );
  }
}

/// Decodes a GIF file frame-by-frame via `dart:ui`'s `instantiateImageCodec`
/// and drives manual frame-advance playback with a `Timer` - `Image.file`'s
/// own built-in GIF autoplay has no exposed pause/seek/speed hooks, so this
/// exists purely to add controls on top for the one clip currently selected.
class GifPlaybackController extends StateNotifier<GifPlaybackState?> {
  GifPlaybackController() : super(null);

  Timer? _timer;

  /// Loads and starts playing [path]'s frames for [clipId], replacing
  /// whatever was previously open. A no-op if [clipId] is already open.
  Future<void> openClip(String clipId, String path) async {
    if (state?.clipId == clipId) return;
    _timer?.cancel();
    state = null;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frames = <GifFrame>[];
    for (var i = 0; i < codec.frameCount; i++) {
      final info = await codec.getNextFrame();
      frames.add(GifFrame(image: info.image, duration: info.duration));
    }
    if (frames.isEmpty) return;
    // The clip may have been deselected while decoding was in flight.
    if (state != null) return;

    state = GifPlaybackState(
      clipId: clipId,
      frames: frames,
      currentFrame: 0,
      playing: true,
      speed: 1.0,
    );
    _scheduleNext();
  }

  void closeClip() {
    _timer?.cancel();
    state = null;
  }

  void _scheduleNext() {
    _timer?.cancel();
    final current = state;
    if (current == null || !current.playing || current.frames.length < 2) {
      return;
    }
    final base = current.frames[current.currentFrame].duration;
    final micros = (base.inMicroseconds / current.speed).round().clamp(
      1000,
      1 << 30,
    );
    _timer = Timer(Duration(microseconds: micros), () {
      final s = state;
      if (s == null) return;
      state = s.copyWith(currentFrame: (s.currentFrame + 1) % s.frames.length);
      _scheduleNext();
    });
  }

  void togglePlay() {
    final current = state;
    if (current == null) return;
    final playing = !current.playing;
    state = current.copyWith(playing: playing);
    if (playing) {
      _scheduleNext();
    } else {
      _timer?.cancel();
    }
  }

  void seekToFrame(int index) {
    final current = state;
    if (current == null || current.frames.isEmpty) return;
    final clamped = index.clamp(0, current.frames.length - 1);
    state = current.copyWith(currentFrame: clamped);
    if (current.playing) _scheduleNext();
  }

  void setSpeed(double speed) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(speed: speed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final gifPlaybackControllerProvider =
    StateNotifierProvider<GifPlaybackController, GifPlaybackState?>(
      (ref) => GifPlaybackController(),
    );
