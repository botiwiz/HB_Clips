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

/// Ids of the currently selected clips. A plain click collapses this to a
/// single id; shift/ctrl-click toggles membership; a marquee drag replaces
/// it with everything the marquee overlapped.
final selectedClipIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Ephemeral, not-yet-persisted transform of a clip currently being dragged,
/// resized, or rotated. The board renders this instead of the DB value for
/// that clip while the gesture is in progress, and the repository is only
/// written to on pointer-up - this keeps drags smooth and avoids spamming
/// sqlite writes on every pointer-move frame.
class DraggingClip {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;

  const DraggingClip({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
  });

  DraggingClip copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) => DraggingClip(
    id: id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
  );
}

/// Ephemeral transforms for every clip involved in the gesture currently in
/// progress: one entry per clip during a group move, always exactly one
/// entry during a resize/rotate (those are single-select only).
final groupDragProvider = StateProvider<Map<String, DraggingClip>?>(
  (ref) => null,
);

/// Board-space rectangle of an in-progress marquee-select drag, or null when
/// no marquee is active. Selection is only recomputed on pointer-up.
final marqueeRectProvider = StateProvider<Rect?>((ref) => null);

/// True while a drag is currently hovering over the bin drop target, so the
/// bin widget can highlight itself.
final isDraggingOverBinProvider = StateProvider<bool>((ref) => false);
