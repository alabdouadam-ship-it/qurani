/// Delivers only the latest request, including its error and completion.
class LatestAsyncRequest {
  int _generation = 0;
  void invalidate() => _generation++;

  Future<void> run<T>(
    Future<T> Function() request, {
    required void Function(T) onResult,
    required void Function(Object) onError,
    required void Function() onComplete,
  }) async {
    final generation = ++_generation;
    try {
      final result = await request();
      if (generation == _generation) onResult(result);
    } catch (error) {
      if (generation == _generation) onError(error);
    } finally {
      if (generation == _generation) onComplete();
    }
  }
}
