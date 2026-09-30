import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/data/models/connector.dart';
import 'package:hb_clips/features/board/controllers/board_controller.dart';
import 'package:hb_clips/features/board/geometry/connector_geometry.dart';

BoardClip _clip({
  String id = 'a',
  double x = 0,
  double y = 0,
  double width = 100,
  double height = 60,
  double rotation = 0,
}) {
  final now = DateTime(2026);
  return BoardClip(
    id: id,
    boardId: 'board',
    type: ClipType.text,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: rotation,
    createdAt: now,
    updatedAt: now,
  );
}

/// Cross product of (b-a) and (c-a) - zero means a/b/c are collinear.
double _cross(Offset a, Offset b, Offset c) {
  final ab = b - a;
  final ac = c - a;
  return ab.dx * ac.dy - ab.dy * ac.dx;
}

void main() {
  group('sideMidpointBoard', () {
    test('unrotated clip: exact midpoints of all 4 sides', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      expect(
        ConnectorGeometry.sideMidpointBoard(clip, ConnectorSide.top),
        const Offset(50, 0),
      );
      expect(
        ConnectorGeometry.sideMidpointBoard(clip, ConnectorSide.right),
        const Offset(100, 30),
      );
      expect(
        ConnectorGeometry.sideMidpointBoard(clip, ConnectorSide.bottom),
        const Offset(50, 60),
      );
      expect(
        ConnectorGeometry.sideMidpointBoard(clip, ConnectorSide.left),
        const Offset(0, 30),
      );
    });

    test(
      '90-degree rotation moves the top midpoint to where the right '
      'midpoint was (square clip, so the two midpoints are equidistant '
      'from center)',
      () {
        final clip = _clip(width: 100, height: 100, rotation: math.pi / 2);
        final top = ConnectorGeometry.sideMidpointBoard(clip, ConnectorSide.top);
        expect(top.dx, closeTo(100, 1e-9));
        expect(top.dy, closeTo(50, 1e-9));
      },
    );
  });

  group('outwardNormal', () {
    test('unrotated clip: axis-aligned unit vectors per side', () {
      final clip = _clip();
      expect(ConnectorGeometry.outwardNormal(clip, ConnectorSide.top), const Offset(0, -1));
      expect(ConnectorGeometry.outwardNormal(clip, ConnectorSide.right), const Offset(1, 0));
      expect(ConnectorGeometry.outwardNormal(clip, ConnectorSide.bottom), const Offset(0, 1));
      expect(ConnectorGeometry.outwardNormal(clip, ConnectorSide.left), const Offset(-1, 0));
    });

    test('rotated clip: normal rotates too, magnitude stays 1', () {
      final clip = _clip(rotation: math.pi / 2);
      final normal = ConnectorGeometry.outwardNormal(clip, ConnectorSide.top);
      expect(normal.dx, closeTo(1, 1e-9));
      expect(normal.dy, closeTo(0, 1e-9));
      expect(normal.distance, closeTo(1, 1e-9));
    });
  });

  group('handleScreenPositions / hitTestHandle', () {
    test('screen position is board position scaled and panned', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      const view = BoardViewState(panOffset: Offset(10, 20), scale: 2);
      final positions = ConnectorGeometry.handleScreenPositions(clip, view);
      expect(positions[ConnectorSide.top], const Offset(110, 20));
    });

    test('a point within the hit radius of a handle hits that side', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      const view = BoardViewState(panOffset: Offset(10, 20), scale: 2);
      final side = ConnectorGeometry.hitTestHandle(clip, view, const Offset(110, 20));
      expect(side, ConnectorSide.top);
    });

    test('a point far from every handle misses', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      const view = BoardViewState();
      final side = ConnectorGeometry.hitTestHandle(clip, view, const Offset(-500, -500));
      expect(side, isNull);
    });
  });

  group('nearestBoundaryAnchor', () {
    test('a point beyond the right edge resolves to the right side', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      final result = ConnectorGeometry.nearestBoundaryAnchor(clip, const Offset(500, 30));
      expect(result.side, ConnectorSide.right);
      expect(result.point, const Offset(100, 30));
    });

    test('a point beyond the top edge resolves to the top side', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      final result = ConnectorGeometry.nearestBoundaryAnchor(clip, const Offset(50, -500));
      expect(result.side, ConnectorSide.top);
      expect(result.point, const Offset(50, 0));
    });

    test('a point inside the rect snaps to the nearest of the 4 edges', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      // Distances to left/right/top/bottom are 20/80/15/45 - top is nearest.
      final result = ConnectorGeometry.nearestBoundaryAnchor(clip, const Offset(20, 15));
      expect(result.side, ConnectorSide.top);
      expect(result.point, const Offset(20, 0));
    });

    test('rotated clip: un-rotate/rotate round trip resolves correctly', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 100, rotation: math.pi / 2);
      // Board-space point that sits far along the clip's local +x axis once
      // un-rotated - i.e. "to the local right" of the rotated square.
      final result = ConnectorGeometry.nearestBoundaryAnchor(clip, const Offset(50, 500));
      expect(result.side, ConnectorSide.right);
      expect(result.point.dx, closeTo(50, 1e-9));
      expect(result.point.dy, closeTo(100, 1e-9));
    });
  });

  group('bezierBoard', () {
    test('control points land strictly off the straight p0-p3 line', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 300, y: 200, width: 100, height: 60);
      final result = ConnectorGeometry.bezierBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.top,
        toClip: toClip,
      );

      expect(_cross(result.p0, result.p3, result.c1).abs(), greaterThan(1));
      expect(_cross(result.p0, result.p3, result.c2).abs(), greaterThan(1));
    });

    test('very close clips clamp the control offset to the minimum', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 105, y: 0, width: 100, height: 60);
      final result = ConnectorGeometry.bezierBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.right,
        toClip: toClip,
      );

      expect((result.c1 - result.p0).distance, closeTo(20, 1e-9));
    });

    test('very far clips clamp the control offset to the maximum', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 5000, y: 0, width: 100, height: 60);
      final result = ConnectorGeometry.bezierBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.right,
        toClip: toClip,
      );

      expect((result.c1 - result.p0).distance, closeTo(120, 1e-9));
    });
  });
}
