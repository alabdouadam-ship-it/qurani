# Testing Audio Fixes - Quick Guide

## Test 1: Background Notification Appears

### Steps:
1. Build and run the app on Android device
2. Go to Audio Player screen
3. Select any surah and start playback
4. **Pull down notification shade** (swipe from top)
5. **Expected**: Should see notification with:
   - Title: "Playing: [Surah Name]"
   - Description: "Reciter: [Reciter Name]"

### If Not Appearing:
- Check if app has POST_NOTIFICATIONS permission granted (Android 13+)
  - Settings → Apps → Qurani → Permissions → Notifications
- Verify notification channel was created (check Android logs)
- Try stopping and starting playback again

---

## Test 2: Notification Persists When App Closed

### Steps:
1. Start playing Quran audio
2. Verify notification appears (Test 1)
3. **Press Home button or tap another app** to go to background
4. **Pull down notification shade**
5. **Expected**: Notification should still be visible

### If Disappears:
- Check if notification was canceled incorrectly
- Verify ongoing flag is set (should be in code: `ongoing: true`)

---

## Test 3: Notification Hides When Playback Stops

### Steps:
1. Start playing Quran audio
2. Verify notification appears
3. **Tap pause button**
4. **Pull down notification shade**
5. **Expected**: Notification should disappear

### If Still Showing:
- Check if `_hidePlaybackNotification()` was called
- Verify notification ID matches (should be 9999)

---

## Test 4: Adhan Playback After 5 Seconds (Background)

### To Test Programmatically:
1. Add this to main.dart or a test button:
```dart
AdhanScheduler.testAdhanPlaybackAfterSeconds(5, 'afs');
```

2. Run the app and trigger this test
3. Wait 5 seconds
4. **Close/minimize the app** (even before 5 seconds pass)
5. **Expected**: Adhan should play after 5 seconds, even with app closed

### What to Check:
- Sound plays from device speaker
- Volume buttons control Adhan volume
- Notification appears when Adhan plays
- Check logcat for detailed execution logs:
```
[AdhanScheduler.Callback] ===== ADHAN CALLBACK TRIGGERED
[AdhanScheduler.Callback] ✓ Audio source set
[AdhanScheduler.Callback] ✓ Playback started
```

### If Adhan Doesn't Play When App Closed:
1. **Check Battery Optimization**:
   - Settings → Battery → Battery Saver/Battery Optimization
   - Find "Qurani" app
   - Change to "Not optimized" or "Unrestricted"

2. **Check Android Version**:
   - Android 14+ has stricter background execution limits
   - Might require additional permission or system setting

3. **Check Logcat**:
   - Look for errors in callback logs
   - Search for: `[AdhanScheduler.Callback]`
   - File not found errors → Cache files missing
   - Session configuration errors → Audio system issue

---

## Logcat Debug Commands

### Show all Adhan-related logs:
```bash
adb logcat | grep "AdhanScheduler"
```

### Show audio player logs:
```bash
adb logcat | grep "AudioPlayer"
```

### Show notification logs:
```bash
adb logcat | grep "NotificationService"
```

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Notification doesn't appear when audio starts | Check POST_NOTIFICATIONS permission |
| Notification appears but doesn't stay | Check `ongoing: true` flag is set |
| Adhan doesn't play when app closed | Disable battery optimization for app |
| Adhan plays but with delays | Normal - system may throttle background tasks |
| Adhan file not found errors in logs | Ensure app started properly (cache initialization) |
| Audio stops after 15-30 minutes | Check system resource cleanup (addressed in audio session config) |

---

## Device-Specific Notes

### Android 13-14:
- Requires POST_NOTIFICATIONS permission
- May require explicit permission in app settings
- Battery optimization must be disabled for background tasks

### Android 15+:
- Additional restrictions on background audio playback
- Might require foreground service declaration
- Check for new battery optimization settings

### Xiaomi/OnePlus/Samsung:
- Custom battery savers often override Android settings
- May need to add app to "Protected Apps" list
- Look for manufacturer-specific notification settings

---

## Performance Notes

- Notification updates on every playback state change
- Minimal CPU/memory impact (using system notification service)
- Adhan callback with 120s timeout prevents indefinite waiting
- No constant background service running (only when audio playing)
