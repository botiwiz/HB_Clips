import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Camera transform for the infinite board: screenPoint = boardPoint *
/// scale + panOffset.
class BoardViewState {
  final Offset panOffset;
  final double scale;

  const BoardViewState({this.panOffset = Offset.zero, this.scale = 1});

  BoardViewState copyWith({Offset? panOffset, double? scale}) {
    return BoardViewState(
      panOffset: panOffset ?? this.panOffset,
      scale: scale ?? this.scale,
    );
  }
}

class BoardViewNotifier extends StateNotifier<BoardViewState> {
  BoardViewNotifier() : super(const BoardViewState());

  static const double _minScale = 0.15;
  static const double _maxScale = 4.0;

  void setPan(Offset panOffset) {
    state = state.copyWith(panOffset: panOffset);
  }

  void panBy(Offset delta) {
    state = state.copyWith(panOffset: state.panOffset + delta);
  }

  /// Zooms so that the board point under [focalScreenPoint] stays under the
  /// cursor - the usual "zoom towards the mouse" desktop behaviour.
  void zoomAt(Offset focalScreenPoint, double scaleFactor) {
    final newScale = (state.scale * scaleFactor).clamp(_minScale, _maxScale);
    final boardPoint =
        (focalScreenPoint - state.panOffset) / state.scale;
    final newPanOffset = focalScreenPoint - boardPoint * newScale;
    state = BoardViewState(panOffset: newPanOffset, scale: newScale);
  }

  void reset() => state = const BoardViewState();
}

final boardViewProvider =
    StateNotifierProvider<BoardViewNotifier, BoardViewState>(
      (ref) => BoardViewNotifier(),
    );

/// Id of the currently selected clip, if any. Phase 1 is single-select only;
/// Phase 2 will generalise this into a multi-select set.
final selectedClipIdProvider = StateProvider<String?>((ref) => null);

/// Ephemeral, not-yet-persisted position of a clip currently being dragged.
/// The board renders this instead of the DB value for that one clip while
/// dragging is in progress, and the repository is only written to on
/// pointer-up - this keeps drags smooth and avoids spamming sqlite writes
/// on every pointer-move frame.
class DraggingClip {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;

  const DraggingClip({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  DraggingClip copyWith({double? x, double? y}) => DraggingClip(
    id: id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width,
    height: height,
  );
}

final draggingClipProvider = StateProvider<DraggingClip?>((ref) => null);

/// True while a drag is currently hovering over the bin drop target, so the
/// bin widget can highlight itself.
final isDraggingOverBinProvider = StateProvider<bool>((ref) => false);
