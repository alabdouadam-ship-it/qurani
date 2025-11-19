# Adhan Callback Not Triggering - Diagnostic Guide

## The Core Problem

Alarms **schedule successfully** but **never fire**. This indicates the app/callback is being killed by Android before the alarm time.

## Step 1: Verify Callback CAN Execute (In-App Test)

### Add this to Prayer Times Screen or a debug button:

```dart
// In lib/prayer_times_screen.dart or any stateful widget
ElevatedButton(
  onPressed: () async {
    print('[TEST] Calling Adhan callback DIRECTLY from app...');
    await AdhanScheduler.testAdhanPlaybackImmediate();
    print('[TEST] Check logcat for [AdhanScheduler.Callback] logs');
  },
  child: Text('TEST ADHAN NOW'),
)
```

### What to expect:
- Adhan should play immediately
- Logcat should show:
  ```
  [AdhanScheduler.Callback] ===== ADHAN CALLBACK TRIGGERED
  [AdhanScheduler.Callback] ✓ WidgetsFlutterBinding initialized
  [AdhanScheduler.Callback] ✓ DartPluginRegistrant initialized
  [AdhanScheduler.Callback] Step 1: Getting preferences...
  [AdhanScheduler.Callback] ✓ Playback started
  ```

### If Adhan doesn't play:
**The callback itself is broken**. Issues could be:
- Audio file cache doesn't exist
- Permissions missing
- Audio system not initialized

### If Adhan plays:
**The callback works when called directly** → Problem is alarm scheduling/triggering

---

## Step 2: Test Alarm Scheduling (5-second test)

### Add to a debug button:

```dart
ElevatedButton(
  onPressed: () async {
    print('[TEST] Scheduling Adhan alarm for 5 seconds from now...');
    await AdhanScheduler.testAdhanPlaybackAfterSeconds(5, 'afs');
    print('[TEST] Alarm scheduled. Keep app open for 5 seconds...');
    print('[TEST] If it plays: alarms work with app OPEN');
  },
  child: Text('TEST ALARM (5 SEC)'),
)
```

### Expected:
- Wait 5 seconds
- Adhan plays even while app is still open
- **Logcat shows [AdhanScheduler.Callback] logs**

### If nothing happens:
- Alarm system is broken
- Try increasing to 30 seconds to be safe

---

## Step 3: Test Alarm With App Closed

### Prerequisite: Must complete Step 2 successfully

### Steps:
1. Click "TEST ALARM (30 SEC)" button
2. Immediately press Home button (close app to background)
3. Lock screen if possible
4. Wait 30+ seconds
5. **Check if Adhan plays**
6. **Check logcat for [AdhanScheduler.Callback] logs**

### Possible outcomes:

| Result | Cause | Solution |
|--------|-------|----------|
| Adhan plays, logs appear | ✓ Working | Keep changes |
| No Adhan, no logs | App killed before alarm | See "Fix" section |
| Adhan plays, no logs | Works but logging broken | Low priority |

---

## Diagnosis: Why App Is Being Killed

Android kills background apps to save resources. Key places to check:

### 1. **Battery Optimization** (Most Common)
```
Settings → Battery → Battery Optimization/Battery Saver
  → Find "Qurani"
  → Set to "NOT OPTIMIZED" or "UNRESTRICTED"
```

### 2. **App Permissions**
```
Settings → Apps → Qurani → Permissions
  ✓ Schedule exact alarm (granted)
  ✓ Post notifications (granted)
  ✓ Wake lock (not user-facing but needed)
  ✓ All calendar/location permissions optional
```

### 3. **Background Restriction** (Android 12+)
```
Settings → Apps → Qurani → "Battery" or "Other"
  → Check for "Background restriction" toggle
  → Disable if enabled
```

### 4. **Recent App Cleanup**
Some launchers auto-kill apps. If using:
- Xiaomi: Settings → Authorization → Background launch → Allow
- Samsung: Bixby Routines → Battery settings → Don't kill app
- OnePlus: Settings → Apps → Protected apps → Add Qurani

---

## Real Fix: Ensure App Survives Alarm

The fundamental issue: Android's ComponentCallbacks can't restore a killed app.

### Potential Solutions (In Priority Order):

#### Option A: Notification-Based Approach (Current)
- ✓ Works when app is running
- ✗ Doesn't work when app killed
- Status: **NOT SUFFICIENT**

#### Option B: Add Foreground Service (RECOMMENDED)
```dart
// In android_alarm_manager_plus callback:
// Start a foreground service when alarm fires
// Service keeps app process alive for callback
```

#### Option C: Use WorkManager Instead
```dart
// WorkManager has better reliability for background tasks
// But requires migrating entire scheduling system
```

---

## Logcat Debugging Commands

### See all Adhan callback logs:
```bash
adb logcat -v threadtime | grep "AdhanScheduler.Callback"
```

### Capture logs to file while app runs:
```bash
adb logcat > adhan_logs.txt &
# Run test
adb logcat -c  # Clear when done
```

### Search for why app was killed:
```bash
adb logcat | grep -i "killed\|death\|low memory"
```

### See alarm manager logs:
```bash
adb logcat | grep "AlarmManager"
```

---

## Critical Information to Collect

When testing, save this information:

1. **Android version**: Settings → About phone → Android version
2. **Does Step 1 test work?** (Direct callback): YES / NO
3. **Does Step 2 test work?** (Alarm with app open): YES / NO  
4. **Does Step 3 test work?** (Alarm with app closed): YES / NO
5. **Battery optimization setting**: [setting name]
6. **Device manufacturer**: Samsung/Xiaomi/OnePlus/Stock/Other
7. **Logcat output from failed test**: [copy full log]

---

## Temporary Workaround

Until we fix the background issue, users can:

1. **Keep app in foreground during prayer times**
   - Keep prayer times screen open
   - This ensures callback can execute

2. **Disable battery optimization**
   - Increases battery drain but makes Adhan reliable
   - Good for testing

3. **Disable sleep** while testing
   - Settings → Display → Sleep → Never
   - Keeps app from being killed

---

## Next Steps After Diagnosis

1. **Collect Step 1-3 test results**
2. **Share logcat output** showing callback logs (or lack thereof)
3. **Identify which step fails**
4. **Then implement specific fix** based on failure point
