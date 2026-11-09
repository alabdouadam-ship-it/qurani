import 'package:dio/dio.dart';

class DownloadBatchResult {
  final int total;
  final int completed;
  final int failed;
  final bool cancelled;
  const DownloadBatchResult(
      {required this.total,
      required this.completed,
      required this.failed,
      required this.cancelled});
  bool get isComplete =>
      total > 0 && completed == total && failed == 0 && !cancelled;
}

void checkDownloadCancellation(CancelToken? token) {
  if (token?.isCancelled == true) throw token!.cancelError!;
}

/// Progress counts verified files only. Failed/cancelled items never complete.
Future<DownloadBatchResult> runDownloadBatch<T>({
  required List<T> items,
  required Future<void> Function(T item) download,
  required void Function(int completed, int total) onProgress,
  CancelToken? cancelToken,
  int concurrency = 1,
}) async {
  var completed = 0;
  var failed = 0;
  var cancelled = false;
  final queue = items.iterator;
  onProgress(0, items.length);
  Future<void> worker() async {
    while (!cancelled && cancelToken?.isCancelled != true && queue.moveNext()) {
      final item = queue.current;
      try {
        await download(item);
        checkDownloadCancellation(cancelToken);
        completed++;
        onProgress(completed, items.length);
      } catch (error) {
        if (cancelToken?.isCancelled == true ||
            (error is DioException && CancelToken.isCancel(error))) {
          cancelled = true;
        } else {
          failed++;
        }
      }
    }
  }

  final workers = concurrency.clamp(1, items.isEmpty ? 1 : items.length);
  await Future.wait(List.generate(workers, (_) => worker()));
  return DownloadBatchResult(
      total: items.length,
      completed: completed,
      failed: failed,
      cancelled: cancelled || cancelToken?.isCancelled == true);
}
