import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/latest_async_request.dart';

void main() {
  for (final failOld in [false, true]) {
    test(
        'old ${failOld ? "failure" : "success"} cannot replace newer results/loading',
        () async {
      final requests = LatestAsyncRequest();
      final old = Completer<String>();
      final events = <String>[];
      Future<void> run(Future<String> response) => requests.run(() => response,
          onResult: events.add,
          onError: (_) => events.add('error'),
          onComplete: () => events.add('done'));
      final pending = run(old.future);
      await run(Future.value('new'));
      if (failOld) {
        old.completeError(StateError('old'));
      } else {
        old.complete('old');
      }
      await pending;
      expect(events, ['new', 'done']);
    });
  }
  test(
      'clearing text, changing language or disposing invalidates pending delivery',
      () async {
    final requests = LatestAsyncRequest();
    final response = Completer<int>();
    final pending = requests.run(() => response.future,
        onResult: (_) => fail('stale result'),
        onError: (_) => fail('stale error'),
        onComplete: () => fail('stale loading state'));
    requests.invalidate();
    response.complete(1);
    await pending;
  });
  test('an active error is delivered and loading completes', () async {
    final events = <String>[];
    await LatestAsyncRequest().run<int>(() async => throw StateError('current'),
        onResult: (_) => fail('unexpected result'),
        onError: (_) => events.add('error'),
        onComplete: () => events.add('done'));
    expect(events, ['error', 'done']);
  });
}
