import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/queue_service.dart';

part 'audio_providers.g.dart';

/// Riverpod mirror for [QueueService.queueNotifier].
///
/// Audio screens that need the current listen-queue can use
/// `ref.watch(queueProvider)` instead of manually subscribing to
/// `QueueService().queueNotifier` via `addListener`/`removeListener`.
///
/// Writes (`addToQueue`, `removeFromQueue`, `clearQueue`) still go
/// through [QueueService]; every one of those methods fires the
/// underlying ValueNotifier, which this notifier listens to and mirrors
/// into Riverpod state. No write-side changes required.
@riverpod
class QueueNotifier extends _$QueueNotifier {
  @override
  List<int> build() {
    final vn = QueueService().queueNotifier;
    void listener() {
      state = List<int>.unmodifiable(vn.value);
    }

    vn.addListener(listener);
    ref.onDispose(() => vn.removeListener(listener));
    return List<int>.unmodifiable(vn.value);
  }
}

/// Back-compat alias for the pre-codegen `queueProvider` symbol.
final queueProvider = queueNotifierProvider;
