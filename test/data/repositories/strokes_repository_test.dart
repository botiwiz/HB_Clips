import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/models/stroke.dart';
import 'package:hb_clips/data/repositories/strokes_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late StrokesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StrokesRepository(db);
  });

  tearDown(() => db.close());

  test('points survive an add/watch round trip', () async {
    const points = [Offset(0, 0), Offset(0.5, 0.25), Offset(1, 1)];
    await repo.addStroke(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      clipId: 'clip-1',
      colorHex: '#FF3B30',
      strokeWidth: 4,
      points: points,
    );

    final strokes = await repo.watchStrokes(kLocalBoardId).first;
    expect(strokes, hasLength(1));
    expect(strokes.single.clipId, 'clip-1');
    expect(strokes.single.colorHex, '#FF3B30');
    expect(strokes.single.strokeWidth, 4);
    expect(strokes.single.points, points);
    expect(strokes.single.dashed, isFalse);
    expect(strokes.single.arrowEnd, isFalse);
  });

  test('dashed and arrowEnd flags survive an add/watch round trip', () async {
    await repo.addStroke(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      colorHex: '#FF3B30',
      strokeWidth: 4,
      points: const [Offset(0, 0), Offset(1, 1)],
      dashed: true,
      arrowEnd: true,
    );

    final strokes = await repo.watchStrokes(kLocalBoardId).first;
    expect(strokes.single.dashed, isTrue);
    expect(strokes.single.arrowEnd, isTrue);
  });

  test('freestanding strokes have a null clipId', () async {
    await repo.addStroke(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      colorHex: '#0A84FF',
      strokeWidth: 2,
      points: const [Offset(10, 10), Offset(20, 20)],
    );

    final strokes = await repo.watchStrokes(kLocalBoardId).first;
    expect(strokes.single.clipId, isNull);
  });

  test('deleteMostRecentStroke removes only the newest stroke', () async {
    await repo.addStroke(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );
    // sqlite's CURRENT_TIMESTAMP (what Drift's currentDateAndTime uses) is
    // only second-granularity, so the delay needs to cross a whole second
    // for the two rows to sort deterministically by createdAt.
    await Future<void>.delayed(const Duration(seconds: 1));
    final secondId = _uuid.v4();
    await repo.addStroke(
      id: secondId,
      boardId: kLocalBoardId,
      colorHex: '#34C759',
      strokeWidth: 3,
      points: const [Offset(2, 2), Offset(3, 3)],
    );

    await repo.deleteMostRecentStroke(kLocalBoardId);

    final strokes = await repo.watchStrokes(kLocalBoardId).first;
    expect(strokes, hasLength(1));
    expect(strokes.single.id, isNot(secondId));
  });

  test('deleteStrokesForClip only removes that clip\'s strokes', () async {
    await repo.addStroke(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      clipId: 'clip-a',
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );
    await repo.addStroke(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      clipId: 'clip-b',
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );

    await repo.deleteStrokesForClip('clip-a');

    final strokes = await repo.watchStrokes(kLocalBoardId).first;
    expect(strokes, hasLength(1));
    expect(strokes.single.clipId, 'clip-b');
  });

  test('Stroke.encodePoints/decodePoints round trip', () {
    const points = [Offset(1.5, -2.25), Offset(0, 0)];
    final json = Stroke.encodePoints(points);
    final decoded = Stroke.decodePoints(json);
    expect(decoded, points);
  });
}
