// Tests for the reader's fullscreen overlay visibility rules.
//
// The rules are simple individually but interact: the exit button auto-hides on
// a timer, EXCEPT while the playback controls are open, and nothing shows at all
// outside fullscreen. Before extraction these lived across three fields, a Timer
// and six methods on the screen, so the "don't hide the button while controls
// are open" guard was easy to lose in a refactor.
//
// A short autoHideDelay is injected so the timer can be exercised with real
// waits rather than mocked time.

import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/read_quran/fullscreen_chrome_controller.dart';

/// Comfortably longer than the injected delay, to avoid flakiness.
const _pastDelay = Duration(milliseconds: 90);

FullscreenChromeController _controller() => FullscreenChromeController(
      autoHideDelay: const Duration(milliseconds: 30),
    );

void main() {
  group('outside fullscreen', () {
    test('starts with nothing visible', () {
      final c = _controller();
      expect(c.isFullscreen, isFalse);
      expect(c.controlsVisible, isFalse);
      expect(c.buttonVisible, isFalse);
      c.dispose();
    });

    test('ignores every request to show chrome', () {
      final c = _controller();
      c.showControls();
      c.autoShowButton();
      c.toggleButton();
      expect(c.controlsVisible, isFalse);
      expect(c.buttonVisible, isFalse);
      c.dispose();
    });
  });

  group('in fullscreen', () {
    test('entering fullscreen alone shows nothing', () {
      final c = _controller()..setFullscreen(true);
      expect(c.isFullscreen, isTrue);
      expect(c.controlsVisible, isFalse);
      expect(c.buttonVisible, isFalse);
      c.dispose();
    });

    test('showControls reveals the controls AND the exit button', () {
      final c = _controller()..setFullscreen(true);
      c.showControls();
      expect(c.controlsVisible, isTrue);
      expect(c.buttonVisible, isTrue);
      c.dispose();
    });

    test('the button auto-hides after the delay', () async {
      final c = _controller()..setFullscreen(true);
      c.autoShowButton();
      expect(c.buttonVisible, isTrue);
      await Future<void>.delayed(_pastDelay);
      expect(c.buttonVisible, isFalse);
      c.dispose();
    });

    test('the button does NOT auto-hide while the controls are open', () async {
      // The guard that is easiest to lose: the timer fires, but the controls
      // being open must keep the button up.
      final c = _controller()..setFullscreen(true);
      c.showControls();
      await Future<void>.delayed(_pastDelay);
      expect(c.controlsVisible, isTrue);
      expect(c.buttonVisible, isTrue,
          reason: 'button must stay up while controls are open');
      c.dispose();
    });

    test('hiding the controls restarts the button countdown', () async {
      final c = _controller()..setFullscreen(true);
      c.showControls();
      c.hideControls();
      expect(c.controlsVisible, isFalse);
      expect(c.buttonVisible, isTrue, reason: 'still up immediately after');
      await Future<void>.delayed(_pastDelay);
      expect(c.buttonVisible, isFalse, reason: 'now the timer may hide it');
      c.dispose();
    });

    test('toggle hides a visible button immediately', () {
      final c = _controller()..setFullscreen(true);
      c.autoShowButton();
      expect(c.buttonVisible, isTrue);
      c.toggleButton();
      expect(c.buttonVisible, isFalse);
      c.dispose();
    });

    test('toggle shows a hidden button and restarts the countdown', () async {
      final c = _controller()..setFullscreen(true);
      c.toggleButton();
      expect(c.buttonVisible, isTrue);
      await Future<void>.delayed(_pastDelay);
      expect(c.buttonVisible, isFalse);
      c.dispose();
    });

    test('re-showing before the timer fires extends the countdown', () async {
      final c = _controller()..setFullscreen(true);
      c.autoShowButton();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c.autoShowButton(); // restarts the 30ms countdown
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.buttonVisible, isTrue,
          reason: '40ms elapsed overall but only 20ms since the restart');
      c.dispose();
    });
  });

  group('leaving fullscreen', () {
    test('resets both overlays', () {
      final c = _controller()..setFullscreen(true);
      c.showControls();
      c.setFullscreen(false);
      expect(c.controlsVisible, isFalse);
      expect(c.buttonVisible, isFalse);
      c.dispose();
    });

    test('cancels the pending auto-hide so re-entering starts clean', () async {
      final c = _controller()..setFullscreen(true);
      c.autoShowButton();
      c.setFullscreen(false);
      c.setFullscreen(true);
      c.autoShowButton();
      // If the first timer had survived it would fire here and wrongly hide the
      // freshly-shown button.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.buttonVisible, isTrue);
      c.dispose();
    });
  });

  group('notifications', () {
    test('notifies on each visible state change, not on no-ops', () {
      final c = _controller();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.setFullscreen(true);
      expect(notifications, 1);

      c.setFullscreen(true); // no-op
      expect(notifications, 1);

      c.showControls(); // controls + button
      expect(notifications, 3);

      c.showControls(); // already visible; autoShowButton re-arms the timer only
      expect(notifications, 3);

      c.dispose();
    });

    test('does not notify after dispose', () async {
      final c = _controller()..setFullscreen(true);
      c.autoShowButton();
      var notifications = 0;
      c.addListener(() => notifications++);
      c.dispose();
      // A pending auto-hide timer must not notify a disposed controller.
      await Future<void>.delayed(_pastDelay);
      expect(notifications, 0);
    });
  });
}
