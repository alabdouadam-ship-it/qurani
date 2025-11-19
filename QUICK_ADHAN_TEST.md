# Quick Test: Why Adhan Callback Never Fires

## Test 1: Does Callback Work When Called Directly?

Add this to `lib/prayer_times_screen.dart` in the build method:

```dart
ElevatedButton(
  onPressed: () async {
    print('[TEST] ==== CALLING CALLBACK DIRECTLY ====');
    // Clear logcat first: adb logcat -c
    await AdhanScheduler.testAdhanPlaybackImmediate();
    print('[TEST] Check logcat for [AdhanScheduler.Callback] logs');
  },
  child: const Text('TEST: Direct Callback'),
)
```

**Run and tap this button:**

Expected logcat output:
```
I/flutter(22115): [TEST] ==== CALLING CALLBACK DIRECTLY ====
I/flutter(22115): [AdhanScheduler] TEST: Triggering Adhan callback IMMEDIATELY
I/flutter(22115): [AdhanScheduler.Callback] ===== ADHAN CALLBACK TRIGGERED
I/flutter(22115): [AdhanScheduler.Callback] Step 0: Initializing Flutter bindings...
I/flutter(22115): [AdhanScheduler.Callback] ✓ WidgetsFlutterBinding initialized
I/flutter(22115): [AdhanScheduler.Callback] Step 1: Getting preferences...
I/flutter(22115): [AdhanScheduler.Callback] ✓ Playback started
```

**Result?**
- [ ] Adhan plays + logs appear → Callback is OK
- [ ] No sound + no logs → **Audio system broken**
- [ ] No sound + partial logs → **Callback dies mid-execution**

---

## Test 2: Schedule Alarm for 3 Seconds, Keep App Open

Add to build method:

```dart
ElevatedButton(
  onPressed: () async {
    print('[TEST] ==== ALARM FOR 3 SECONDS (APP OPEN) ====');
    // Clear logs: adb logcat -c
    await AdhanScheduler.testAdhanPlaybackAfterSeconds(3, 'afs');
    print('[TEST] Keep app open for 3 seconds...');
    print('[TEST] Check logcat for [AdhanScheduler.Callback] logs');
  },
  child: const Text('TEST: 3 Sec Alarm (App Open)'),
)
```

**Tap button, wait 3 seconds:**

Expected:
- After 3 seconds: Adhan plays
- Logcat shows: `[AdhanScheduler.Callback]` logs

**Result?**
- [ ] Plays + logs appear → Alarm system works with app open
- [ ] No sound → Alarm didn't fire or callback failed

---

## Test 3: Schedule Alarm for 3 Seconds, Close App Immediately

```dart
ElevatedButton(
  onPressed: () async {
    print('[TEST] ==== ALARM FOR 3 SECONDS (CLOSE APP) ====');
    // Clear logs: adb logcat -c
    await AdhanScheduler.testAdhanPlaybackAfterSeconds(3, 'afs');
    print('[TEST] CLOSE THE APP NOW!');
  },
  child: const Text('TEST: 3 Sec Alarm (Close App)'),
)
```

**Steps:**
1. Tap button
2. **Immediately press Home to close app**
3. Wait 3+ seconds
4. **Check logcat for sound AND logs**

```bash
adb logcat | grep "AdhanScheduler.Callback"
```

**Result?**
- [ ] Plays + logs appear → Everything works
- [ ] Plays + NO logs → Sound works but logging broken
- [ ] No sound, no logs → **App killed before alarm**

---

## Test 4: Check System Alarm Manager

See if Android even received the alarm:

```bash
adb shell dumpsys alarm > alarm_dump.txt
cat alarm_dump.txt | grep -i qurani
```

Look for your alarm in the output. If not there, the alarm wasn't set.

---

## Test 5: Monitor System for Alarm Firing

While running Test 3, watch system logs:

```bash
adb logcat "*:I" | grep -E "AlarmManager|onReceive|alarm"
```

Should see something like:
```
AlarmManager: send alarm [RTC_WAKEUP]
OnAlarmReceiver: received alarm
```

If you see this, alarm fired. If not, alarm didn't trigger.

---

## Diagnosis Key

Based on results:

| Test 1 | Test 2 | Test 3 | Diagnosis |
|--------|--------|--------|-----------|
| ✓ | ✓ | ✗ | App killed before alarm |
| ✓ | ✓ | ✓ | WORKS! No fix needed |
| ✓ | ✗ | ✗ | Alarm system broken |
| ✗ | ✗ | ✗ | Callback/audio broken |

---

## What to Do Based on Results

### If Test 1 & 2 Pass But Test 3 Fails
**Problem**: App is killed before alarm fires
**Solution**: Add foreground service (see ADHAN_REAL_FIX_FOREGROUND_SERVICE.md)

### If Test 2 Fails
**Problem**: Alarm system not working
**Causes**:
- Battery optimization blocking alarms
- Device manufacturer restrictions (Xiaomi, OnePlus, etc.)
- Android version restrictions
- Exact alarm permission issue

**Quick Fix**:
```
Settings → Battery → Battery Optimization
Find Qurani → Set to "Not optimized"
```

### If Test 1 Fails
**Problem**: Audio system or callback broken
**Causes**:
- Audio files missing from cache
- Permission issue
- Audio session not initialized

**Debug**: Check if audio cache files exist:
```bash
adb shell ls -la /data/user/0/com.qurani.app/app_flutter/adhan_cache/
```

Should see:
```
afs.mp3
afs-fajr.mp3
basit.mp3
basit-fajr.mp3
```

---

## Run These Tests NOW

1. **Add buttons to Prayer Times Screen**
2. **Run app on device**
3. **Run Test 1** → Report result
4. **Run Test 2** → Report result  
5. **Run Test 3** → Report result
6. **Report which test fails first**

Then I can give you the exact fix based on failure point.

---

## Collect This Info Before Testing

```
Device: [Model]
Android Version: [e.g., 12.0]
Manufacturer: [Samsung/Xiaomi/Stock/etc]
Battery Optimization Setting: [Not optimized / Optimized]
```

This info helps diagnose manufacturer-specific issues.
