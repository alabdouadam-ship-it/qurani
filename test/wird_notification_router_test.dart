import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/wird_notification_router.dart';

void main() {
  test('iPhone and Android both install routing, web does not', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      expect(supportsWirdNotificationRouting(platform, isWeb: false), isTrue);
      expect(supportsWirdNotificationRouting(platform, isWeb: true), isFalse);
    }
    expect(
        supportsWirdNotificationRouting(TargetPlatform.windows, isWeb: false),
        isFalse);
  });
  test(
      'cold launch waits for navigation and delivers once; warm taps open immediately',
      () {
    var opens = 0;
    final router = WirdNotificationRouter(() => opens++);
    router.handle('wird_123');
    router
        .handle('wird_123'); // launch details and startup callback may overlap
    expect(opens, 0);
    router.markReady();
    router.markReady();
    expect(opens, 1);
    router.handle('wird_456');
    expect(opens, 2);
  });
  test('unrelated and invalid notifications do not open Wird', () {
    final router = WirdNotificationRouter(() => fail('unexpected navigation'));
    for (final payload in [
      null,
      '',
      'unknown',
      'adhan',
      'stop_adhan',
      'wird_'
    ]) {
      router.handle(payload);
    }
    router.markReady();
  });
}
