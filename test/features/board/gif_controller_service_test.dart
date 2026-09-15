import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/gif_controller_service.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List gifBytes;

  setUpAll(() {
    final anim = img.Image(width: 4, height: 4);
    img.fill(anim, color: img.ColorRgb8(255, 0, 0));
    anim.frameDuration = 100;
    final frame2 = img.Image(width: 4, height: 4);
    img.fill(frame2, color: img.ColorRgb8(0, 0, 255));
    frame2.frameDuration = 100;
    anim.addFrame(frame2);
    gifBytes = img.encodeGif(anim);
  });

  test('openClip decodes every frame and starts playing from frame 0', () async {
    final controller = GifPlaybackController();
    await controller.openClip('clip-1', gifBytes);
    final state = controller.state;
    expect(state, isNotNull);
    expect(state!.clipId, 'clip-1');
    expect(state.frames.length, 2);
    expect(state.currentFrame, 0);
    expect(state.playing, isTrue);
    expect(state.speed, 1.0);
    controller.dispose();
  });

  test('togglePlay flips the playing flag', () async {
    final controller = GifPlaybackController();
    await controller.openClip('clip-1', gifBytes);
    controller.togglePlay();
    expect(controller.state!.playing, isFalse);
    controller.togglePlay();
    expect(controller.state!.playing, isTrue);
    controller.dispose();
  });

  test('seekToFrame clamps to the valid frame range', () async {
    final controller = GifPlaybackController();
    await controller.openClip('clip-1', gifBytes);
    controller.seekToFrame(1);
    expect(controller.state!.currentFrame, 1);
    controller.seekToFrame(99);
    expect(controller.state!.currentFrame, 1); // clamped to last frame
    controller.seekToFrame(-5);
    expect(controller.state!.currentFrame, 0); // clamped to first frame
    controller.dispose();
  });

  test('setSpeed updates the speed without changing the current frame', () async {
    final controller = GifPlaybackController();
    await controller.openClip('clip-1', gifBytes);
    controller.seekToFrame(1);
    controller.setSpeed(2.0);
    expect(controller.state!.speed, 2.0);
    expect(controller.state!.currentFrame, 1);
    controller.dispose();
  });

  test('closeClip clears the state', () async {
    final controller = GifPlaybackController();
    await controller.openClip('clip-1', gifBytes);
    controller.closeClip();
    expect(controller.state, isNull);
    controller.dispose();
  });

  test('openClip is a no-op when the same clip is already open', () async {
    final controller = GifPlaybackController();
    await controller.openClip('clip-1', gifBytes);
    controller.seekToFrame(1);
    await controller.openClip('clip-1', gifBytes);
    expect(controller.state!.currentFrame, 1); // untouched, not reloaded
    controller.dispose();
  });
}
