import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/sync/realtime_listener.dart';

void main() {
  final older = DateTime(2024, 1, 1);
  final newer = DateTime(2024, 1, 2);

  group('shouldApplyRemote', () {
    test('a dirty local row always wins, even against a newer remote row', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: older,
          localDirty: true,
          remoteUpdatedAt: newer,
        ),
        isFalse,
      );
    });

    test('no local row at all - the remote row is always applied', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: null,
          localDirty: false,
          remoteUpdatedAt: older,
        ),
        isTrue,
      );
    });

    test('clean local row, newer remote row - remote wins (LWW)', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: older,
          localDirty: false,
          remoteUpdatedAt: newer,
        ),
        isTrue,
      );
    });

    test('clean local row, older remote row - local wins (LWW)', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: newer,
          localDirty: false,
          remoteUpdatedAt: older,
        ),
        isFalse,
      );
    });

    test('clean local row, equal timestamps - remote is not applied '
        '(isAfter is strict, avoids a needless rewrite on an exact echo)', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: older,
          localDirty: false,
          remoteUpdatedAt: older,
        ),
        isFalse,
      );
    });
  });
}
