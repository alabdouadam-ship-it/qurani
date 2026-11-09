/// Orders source replacements and rejects obsolete asynchronous requests.
class AudioLoadCoordinator {
  int generation = 0;
  bool isApplying = false;
  Future<void> _tail = Future<void>.value();

  int invalidate() => ++generation;
  bool isCurrent(int request) => request == generation;

  Future<bool> apply(int request, Future<void> Function() action) async {
    final previous = _tail;
    final work = () async {
      await previous;
      if (!isCurrent(request)) return false;
      isApplying = true;
      try {
        await action();
        return isCurrent(request);
      } finally {
        isApplying = false;
      }
    }();
    // A failed replacement must not prevent the next selection from loading.
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return work;
  }
}
