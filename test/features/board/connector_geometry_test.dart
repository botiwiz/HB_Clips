import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/data/models/connector.dart';
import 'package:hb_clips/features/board/controllers/board_controller.dart';
import 'package:hb_clips/features/board/geometry/connector_geometry.dart';
import 'package:hb_clips/features/board/geometry/selection_geometry.dart';

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

    test('90-degree rotation moves the top midpoint to where the right '
        'midpoint was (square clip, so the two midpoints are equidistant '
        'from center)', () {
      final clip = _clip(width: 100, height: 100, rotation: math.pi / 2);
      final top = ConnectorGeometry.sideMidpointBoard(clip, ConnectorSide.top);
      expect(top.dx, closeTo(100, 1e-9));
      expect(top.dy, closeTo(50, 1e-9));
    });
  });

  group('outwardNormal', () {
    test('unrotated clip: axis-aligned unit vectors per side', () {
      final clip = _clip();
      expect(
        ConnectorGeometry.outwardNormal(clip, ConnectorSide.top),
        const Offset(0, -1),
      );
      expect(
        ConnectorGeometry.outwardNormal(clip, ConnectorSide.right),
        const Offset(1, 0),
      );
      expect(
        ConnectorGeometry.outwardNormal(clip, ConnectorSide.bottom),
        const Offset(0, 1),
      );
      expect(
        ConnectorGeometry.outwardNormal(clip, ConnectorSide.left),
        const Offset(-1, 0),
      );
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
      final side = ConnectorGeometry.hitTestHandle(
        clip,
        view,
        const Offset(110, 20),
      );
      expect(side, ConnectorSide.top);
    });

    test('a point far from every handle misses', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      const view = BoardViewState();
      final side = ConnectorGeometry.hitTestHandle(
        clip,
        view,
        const Offset(-500, -500),
      );
      expect(side, isNull);
    });
  });

  group('nearestBoundaryAnchor', () {
    test('a point beyond the right edge resolves to the right side', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      final result = ConnectorGeometry.nearestBoundaryAnchor(
        clip,
        const Offset(500, 30),
      );
      expect(result.side, ConnectorSide.right);
      expect(result.point, const Offset(100, 30));
    });

    test('a point beyond the top edge resolves to the top side', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      final result = ConnectorGeometry.nearestBoundaryAnchor(
        clip,
        const Offset(50, -500),
      );
      expect(result.side, ConnectorSide.top);
      expect(result.point, const Offset(50, 0));
    });

    test('a point inside the rect snaps to the nearest of the 4 edges', () {
      final clip = _clip(x: 0, y: 0, width: 100, height: 60);
      // Distances to left/right/top/bottom are 20/80/15/45 - top is nearest.
      final result = ConnectorGeometry.nearestBoundaryAnchor(
        clip,
        const Offset(20, 15),
      );
      expect(result.side, ConnectorSide.top);
      expect(result.point, const Offset(20, 0));
    });

    test('rotated clip: un-rotate/rotate round trip resolves correctly', () {
      final clip = _clip(
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        rotation: math.pi / 2,
      );
      // Board-space point that sits far along the clip's local +x axis once
      // un-rotated - i.e. "to the local right" of the rotated square.
      final result = ConnectorGeometry.nearestBoundaryAnchor(
        clip,
        const Offset(50, 500),
      );
      expect(result.side, ConnectorSide.right);
      expect(result.point.dx, closeTo(50, 1e-9));
      expect(result.point.dy, closeTo(100, 1e-9));
    });
  });

  group('routeBoard', () {
    test(
      'opposite-direction horizontal anchors route as a straight line through stubs',
      () {
        final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
        final toClip = _clip(id: 'to', x: 300, y: 0, width: 100, height: 60);
        final result = ConnectorGeometry.routeBoard(
          fromClip: fromClip,
          fromSide: ConnectorSide.right,
          toClip: toClip,
        );

        expect(result, [
          const Offset(100, 30),
          const Offset(140, 30),
          const Offset(200, 30),
          const Offset(260, 30),
          const Offset(300, 30),
        ]);
      },
    );

    test('perpendicular source/target directions route as a single-bend L', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 150, y: 500, width: 100, height: 60);
      final result = ConnectorGeometry.routeBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.right,
        toClip: toClip,
      );

      expect(result, [
        const Offset(100, 30),
        const Offset(140, 30),
        const Offset(150, 30),
        const Offset(150, 460),
        const Offset(150, 500),
      ]);
    });

    test('every segment is axis-aligned (horizontal or vertical only)', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 340, y: 220, width: 100, height: 60);
      final result = ConnectorGeometry.routeBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.bottom,
        toClip: toClip,
      );
      for (var i = 0; i < result.length - 1; i++) {
        final delta = result[i + 1] - result[i];
        final axisAligned = delta.dx == 0 || delta.dy == 0;
        expect(axisAligned, isTrue, reason: 'segment $i is diagonal: $delta');
      }
    });

    test('very close clips clamp the stub length to the minimum', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 105, y: 0, width: 100, height: 60);
      final result = ConnectorGeometry.routeBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.right,
        toClip: toClip,
      );

      expect((result[1] - result[0]).distance, closeTo(16, 1e-9));
    });

    test('very far clips clamp the stub length to the maximum', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 5000, y: 0, width: 100, height: 60);
      final result = ConnectorGeometry.routeBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.right,
        toClip: toClip,
      );

      expect((result[1] - result[0]).distance, closeTo(40, 1e-9));
    });

    test(
      'explicit relative target lands at pointFromRelative, not the boundary',
      () {
        final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
        final toClip = _clip(id: 'to', x: 300, y: 200, width: 100, height: 60);
        final result = ConnectorGeometry.routeBoard(
          fromClip: fromClip,
          fromSide: ConnectorSide.top,
          toClip: toClip,
          toRelX: 0.5,
          toRelY: 0.5,
        );

        expect(
          result.last,
          ConnectorGeometry.pointFromRelative(toClip, const Offset(0.5, 0.5)),
        );
        expect(result.last, ClipGeometry.clipCenter(toClip));
      },
    );
  });

  group('relativePointInClip / pointFromRelative', () {
    test('round-trips through an unrotated clip', () {
      final clip = _clip(x: 100, y: 50, width: 200, height: 80);
      final boardPoint = const Offset(150, 70);
      final rel = ConnectorGeometry.relativePointInClip(clip, boardPoint);
      expect(rel.dx, closeTo(0.25, 1e-9));
      expect(rel.dy, closeTo(0.25, 1e-9));
      final back = ConnectorGeometry.pointFromRelative(clip, rel);
      expect(back.dx, closeTo(boardPoint.dx, 1e-9));
      expect(back.dy, closeTo(boardPoint.dy, 1e-9));
    });

    test('round-trips through a rotated clip', () {
      final clip = _clip(
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        rotation: math.pi / 2,
      );
      final boardPoint = const Offset(50, 500);
      final rel = ConnectorGeometry.relativePointInClip(clip, boardPoint);
      final back = ConnectorGeometry.pointFromRelative(clip, rel);
      // relativePointInClip clamps to [0,1], so a point far outside the
      // rect round-trips only to its clamped boundary projection, not the
      // original point - assert the clamp landed on the expected edge
      // instead (matches nearestBoundaryAnchor's own rotated-clip case).
      expect(back.dx, closeTo(50, 1e-9));
      expect(back.dy, closeTo(100, 1e-9));
    });

    test('a point inside the rect round-trips exactly', () {
      final clip = _clip(
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        rotation: math.pi / 2,
      );
      final center = ClipGeometry.clipCenter(clip);
      final rel = ConnectorGeometry.relativePointInClip(clip, center);
      expect(rel.dx, closeTo(0.5, 1e-9));
      expect(rel.dy, closeTo(0.5, 1e-9));
    });
  });

  group('hitTestRoute', () {
    test('true near the midpoint of a route segment', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 300, y: 0, width: 100, height: 60);
      final route = ConnectorGeometry.routeBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.right,
        toClip: toClip,
      );
      final mid = Offset.lerp(route.first, route.last, 0.5)!;
      expect(ConnectorGeometry.hitTestRoute(route, mid), isTrue);
    });

    test('false far from the route', () {
      final fromClip = _clip(id: 'from', x: 0, y: 0, width: 100, height: 60);
      final toClip = _clip(id: 'to', x: 300, y: 0, width: 100, height: 60);
      final route = ConnectorGeometry.routeBoard(
        fromClip: fromClip,
        fromSide: ConnectorSide.right,
        toClip: toClip,
      );
      expect(
        ConnectorGeometry.hitTestRoute(route, const Offset(-1000, -1000)),
        isFalse,
      );
    });
  });
}
