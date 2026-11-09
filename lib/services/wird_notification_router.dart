import 'package:flutter/foundation.dart';

bool supportsWirdNotificationRouting(TargetPlatform platform,
        {required bool isWeb}) =>
    !isWeb &&
    (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

/// Retains a startup tap until the navigator has rendered its first frame.
class WirdNotificationRouter {
  final VoidCallback openWird;
  bool _ready = false;
  bool _pending = false;
  WirdNotificationRouter(this.openWird);

  void handle(String? payload) {
    if (payload == null || !payload.startsWith('wird_') || payload.length <= 5) {
      return;
    }
    if (_ready) {
      openWird();
    } else {
      _pending = true;
    }
  }

  void markReady() {
    _ready = true;
    if (_pending) {
      _pending = false;
      openWird();
    }
  }
}
