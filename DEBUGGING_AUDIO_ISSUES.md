# Audio Issues - Debugging Guide

## Changes Made

### 1. **Adhan Audio Caching**
- **File**: `lib/services/adhan_scheduler_io.dart`
- **Changes**:
  - Added `_cacheAdhanAudio()` to extract all Adhan audio files from assets to app's documents directory on startup
  - Files are cached in: `app_documents/adhan_cache/`
  - Added verification method `_verifyAdhanCacheFiles()` to check if files are cached
  - Added detailed logging with symbols (✓, ✗, ⊘) for easy debugging
  - Added `testAdhanPlaybackAfterSeconds()` public method for testing

### 2. **Adhan Scheduler Enhanced Logging**
- **File**: `lib/services/adhan_scheduler_io.dart`
- **Changes**:
  - Enhanced `scheduleForTimes()` with detailed logging of what's being scheduled
  - Verifies cached files before scheduling
  - Shows which prayers are enabled/disabled
  - Shows which times are being scheduled

### 3. **Audio Player Session Configuration**
- **File**: `lib/audio_player_screen.dart`
- **Changes**:
  - Added `_configureAudioSession()` method with proper AudioSessionConfiguration
  - Configured for music playback with media usage
  - Added `androidWillPauseWhenDucked: false` to prevent interruptions
  - Added listener for interruption events to pause/resume playback
  - Called during player initialization

## How to Debug

### Step 1: Check Adhan Caching
When the app starts, watch the logs for:
```
[AdhanScheduler] Adhan cache directory: /data/user/0/com.qurani.app/files/adhan_cache
[AdhanScheduler] ✓ Cached: afs.mp3 (12345 bytes)
[AdhanScheduler] ✓ Cached: afs-fajr.mp3 (67890 bytes)
...
[AdhanScheduler] Caching complete. Total new files: 16
```

**If you see errors**: Check app permissions and storage access.

### Step 2: Check Adhan Scheduling
When prayer times are loaded, you should see:
```
[AdhanScheduler] ===== SCHEDULING ADHANS START =====
[AdhanScheduler] Current time: 2025-11-18 17:49:25.000
[AdhanScheduler] Sound key: afs
[AdhanScheduler] ✓ Scheduling fajr for 2025-11-19 05:15:00.000 (ID: 202511191)
[AdhanScheduler]   ✓ fajr SCHEDULED SUCCESSFULLY
...
[AdhanScheduler] ===== SCHEDULING ADHANS END =====
```

**If you see"scheduling returned false"**: The alarm might not have been scheduled. Check:
- Battery optimization settings
- Alarm permission granted
- Device time is correct

### Step 3: Test Adhan Manually (Temporary)

Add this debug code to test Adhan after 10 seconds:
```dart
// In prayer_times_screen.dart, add a test button
FloatingActionButton(
  onPressed: () async {
    await AdhanScheduler.testAdhanPlaybackAfterSeconds(10, 'afs');
  },
  child: const Icon(Icons.bug_report),
)
```

Close the app completely, tap the button, wait 10 seconds with app closed. If Adhan plays, the system works!

## Checklist for Adhan Not Working

- [ ] App has permission to schedule alarms (`android.permission.SCHEDULE_EXACT_ALARM`)
- [ ] App has `WAKE_LOCK` permission
- [ ] Battery optimization is disabled for the app
- [ ] Device time is set correctly
- [ ] Prayer times are fetched (check prayer times screen)
- [ ] Prayer toggles are enabled (Adhan settings)
- [ ] Adhan sound is selected (not blank)
- [ ] Logs show "SCHEDULING SUCCESSFULLY"
- [ ] Logs show cached Adhan files exist
- [ ] Manual test (step 3 above) works

## Checklist for Background Audio Not Working

- [ ] Audio session is configured (check `_configureAudioSession()` logs)
- [ ] MediaItem is set for the audio source
- [ ] `audioWillPauseWhenDucked: false` is set
- [ ] Audio doesn't pause when app goes to background
- [ ] No battery optimization killing the app
- [ ] Device lock doesn't stop playback

### Solution for Background Audio

The audio is designed to continue playing even when:
- App is in background (screen off)
- Lock screen is displayed
- Other notifications appear

**If audio stops immediately when app goes to background**:
1. Check if the audio session configuration ran successfully
2. Look for any error logs
3. Make sure MediaItem is properly set

## Root Causes of Common Issues

| Issue | Likely Cause |
|-------|-------------|
| Adhan never plays | Cache files not created or alarm not scheduled |
| Adhan stops after 30 mins | Battery optimization or system resource cleanup |
| No background notification | MediaItem not set or notification plugin issue |
| Audio pauses with other sounds | `androidWillPauseWhenDucked` not set to false |

## Android Specific Issues

**For Android 12+**:
- Exact alarm permission might need manual grant in settings
- Battery optimization might need to be disabled manually

**For Android 13+**:
- Full screen intent permission needed for Adhan notifications
- Already configured in AndroidManifest.xml

**For Android 31+**:
- `SCHEDULE_EXACT_ALARM` permission required
- Already declared in manifest

## Next Steps if Still Not Working

1. **Collect Logs**:
   - Run: `flutter run` with app
   - Filter logs: `[AdhanScheduler]` and `[AudioPlayer]`
   - Save the full log output

2. **Check Permissions**:
   - Go to app settings
   - Check all permissions granted
   - Disable battery optimization

3. **Test Manual Audio**:
   - Try playing Adhan manually from prayer times screen
   - If manual works but automatic doesn't, it's an alarm scheduling issue

4. **Check Device Settings**:
   - Ensure device time/date is correct
   - Ensure alarms are not muted in system settings
   - Check if "Do Not Disturb" is interfering

## Android Permissions Already Configured

All necessary permissions are in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
```

## Audio Services Involved

1. **AndroidAlarmManager**: Schedules the alarm at prayer time
2. **AudioPlayer (just_audio)**: Plays the Adhan audio
3. **AudioSession**: Manages audio focus and interruptions
4. **NotificationService**: Shows notification about the prayer
