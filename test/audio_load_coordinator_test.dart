import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/audio_load_coordinator.dart';

void main() {
  test('late preparation cannot replace the latest selection', () async {
    final loads = AudioLoadCoordinator();
    final old = loads.invalidate();
    final current = loads.invalidate();
    final writes = <int>[];
    expect(
        await loads.apply(current, () async {
          writes.add(current);
        }),
        isTrue);
    expect(
        await loads.apply(old, () async {
          writes.add(old);
        }),
        isFalse);
    expect(writes, [current]);
  });
  test('in-flight replacement finishes before newest, skips superseded queue',
      () async {
    final loads = AudioLoadCoordinator();
    final gate = Completer<void>();
    final started = Completer<void>();
    final writes = <String>[];
    final old = loads.apply(loads.invalidate(), () async {
      started.complete();
      await gate.future;
      writes.add('old');
    });
    await started.future;
    final skipped = loads.apply(loads.invalidate(), () async {
      writes.add('skipped');
    });
    final latest = loads.apply(loads.invalidate(), () async {
      writes.add('latest');
    });
    gate.complete();
    expect(await old, isFalse);
    expect(await skipped, isFalse);
    expect(await latest, isTrue);
    expect(writes, ['old', 'latest']);
  });
  test('failure does not poison queue and invalidation prevents retries',
      () async {
    final loads = AudioLoadCoordinator();
    final old = loads.invalidate();
    await expectLater(
        loads.apply(old, () async {
          throw StateError('load');
        }),
        throwsStateError);
    final current = loads.invalidate();
    expect(loads.isCurrent(old), isFalse);
    expect(await loads.apply(current, () async {}), isTrue);
    loads.invalidate(); // Disposal or another user selection.
    expect(
        await loads.apply(current, () async {
          fail('disposed request ran');
        }),
        isFalse);
  });
}
