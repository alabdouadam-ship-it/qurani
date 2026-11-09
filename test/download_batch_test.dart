import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/download_batch.dart';

void main() {
  test('failed files do not advance progress or mark a batch complete',
      () async {
    final progress = <int>[];
    final result = await runDownloadBatch<int>(
      items: [1, 2, 3],
      download: (item) async {
        if (item == 2) throw StateError('network');
      },
      onProgress: (completed, total) {
        expect(total, 3);
        progress.add(completed);
      },
    );
    expect(progress, [0, 1, 2]);
    expect(result.completed, 2);
    expect(result.failed, 1);
    expect(result.isComplete, isFalse);
  });
  test('all verified files complete the batch, including concurrent workers',
      () async {
    final result = await runDownloadBatch<int>(
        items: [1, 2, 3],
        concurrency: 3,
        download: (_) async {},
        onProgress: (_, __) {});
    expect(result.isComplete, isTrue);
  });
  test('cancelling an active request stops the queue and never reports success',
      () async {
    final token = CancelToken();
    final started = Completer<void>();
    final visited = <int>[];
    final progress = <int>[];
    final work = runDownloadBatch<int>(
        items: [1, 2, 3],
        cancelToken: token,
        download: (item) async {
          visited.add(item);
          started.complete();
          await token.whenCancel;
          checkDownloadCancellation(token);
        },
        onProgress: (n, _) => progress.add(n));
    await started.future;
    token.cancel();
    final result = await work;
    expect(result.cancelled, isTrue);
    expect(result.isComplete, isFalse);
    expect(result.failed, 0);
    expect(visited, [1]);
    expect(progress, [0]);
  });
  test('pre-cancelled and empty batches cannot be successful', () async {
    final token = CancelToken()..cancel();
    final cancelled = await runDownloadBatch(
        items: [1],
        cancelToken: token,
        download: (_) async => fail('must not download'),
        onProgress: (_, __) {});
    expect(cancelled.cancelled, isTrue);
    final empty = await runDownloadBatch<int>(
        items: [], download: (_) async {}, onProgress: (_, __) {});
    expect(empty.isComplete, isFalse);
  });
}
