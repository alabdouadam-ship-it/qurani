import 'dart:async';

import 'package:flutter/foundation.dart';

/// Visibility state machine for the reader's fullscreen overlay chrome.
///
/// In fullscreen the reader hides everything and shows two transient pieces of
/// UI: an exit button that auto-hides after a few seconds, and a playback
/// control strip revealed by long-press. The interaction between them has a few
/// non-obvious rules that were previously spread across three fields, a Timer
/// and six methods on `read_quran_screen.dart`:
///
///  * Nothing is ever shown when not in fullscreen.
///  * Opening the controls also reveals the exit button, and keeps it up.
///  * The auto-hide timer must NOT hide the button while the controls are open.
///  * Tapping toggles: a visible button hides immediately, a hidden one appears
///    and restarts the auto-hide countdown.
///  * Leaving fullscreen cancels everything.
///
/// Extracted so those rules are stated in one place and can be tested with real
/// timers, which is why [autoHideDelay] is injectable.
class FullscreenChromeController extends ChangeNotifier {
  FullscreenChromeController({
    this.autoHideDelay = const Duration(milliseconds: 3500),
  });

  /// How long the exit button stays up before sliding away.
  final Duration autoHideDelay;

  bool _isFullscreen = false;
  bool _controlsVisible = false;
  bool _buttonVisible = false;
  Timer? _hideTimer;
  bool _disposed = false;

  bool get isFullscreen => _isFullscreen;

  /// The playback control strip, revealed by long-press.
  bool get controlsVisible => _controlsVisible;

  /// The transient "exit fullscreen" button.
  bool get buttonVisible => _buttonVisible;

  /// Enters or leaves fullscreen.
  ///
  /// Leaving resets both overlays and cancels the pending auto-hide, so
  /// re-entering fullscreen always starts from a clean state rather than
  /// inheriting a stale timer.
  void setFullscreen(bool value) {
    if (_isFullscreen == value) return;
    _isFullscreen = value;
    if (!value) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _controlsVisible = false;
      _buttonVisible = false;
    }
    _safeNotify();
  }

  /// Reveals the playback controls, and the exit button along with them.
  void showControls() {
    _setControlsVisible(true);
    autoShowButton();
  }

  /// Hides the playback controls and restarts the button's auto-hide countdown.
  void hideControls() {
    _setControlsVisible(false);
    scheduleHideButton();
  }

  /// Shows the exit button and schedules it to auto-hide.
  void autoShowButton() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_isFullscreen) return;
    if (!_buttonVisible) {
      _buttonVisible = true;
      _safeNotify();
    }
    scheduleHideButton();
  }

  /// Tap behaviour: hide immediately if visible, otherwise show and restart the
  /// countdown.
  void toggleButton() {
    if (!_isFullscreen) return;
    if (_buttonVisible) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _buttonVisible = false;
      _safeNotify();
    } else {
      autoShowButton();
    }
  }

  /// Schedules the exit button to slide away after [delay].
  ///
  /// The callback re-checks its preconditions because a lot can happen in a few
  /// seconds: the user may have left fullscreen, or opened the controls — and
  /// the button must stay up while the controls are open.
  void scheduleHideButton({Duration? delay}) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay ?? autoHideDelay, () {
      _hideTimer = null;
      if (_disposed) return;
      if (_isFullscreen && !_controlsVisible && _buttonVisible) {
        _buttonVisible = false;
        _safeNotify();
      }
    });
  }

  void _setControlsVisible(bool visible) {
    // Overlay chrome only exists in fullscreen.
    if (!_isFullscreen || _controlsVisible == visible) return;
    _controlsVisible = visible;
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    _hideTimer = null;
    super.dispose();
  }
}
