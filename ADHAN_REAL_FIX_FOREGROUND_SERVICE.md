# Real Fix: Foreground Service for Reliable Adhan Playback

## The Problem
The current approach fails because:
1. AndroidAlarmManager schedules alarms ✓
2. When alarm fires, Android tries to run callback
3. **App process is killed** → Callback can't execute ✗
4. Result: Alarm fires but nothing plays

## The Solution: Foreground Service
Keep the app alive with a minimal foreground service that:
- Runs continuously in background
- Receives alarm callbacks
- Can restore the app context to play audio
- Shows persistent notification to user

## Implementation Steps

### Step 1: Add Permission to AndroidManifest.xml

```xml
<!-- E:\Flutter\Qurani\android\app\src\main\AndroidManifest.xml -->

<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

*(These are already present in your manifest - no change needed)*

### Step 2: Create Native Foreground Service

Create file: `android/app/src/main/java/com/qurani/app/AdhanForegroundService.java`

```java
package com.qurani.app;

import android.app.Service;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import androidx.core.app.NotificationCompat;

public class AdhanForegroundService extends Service {
    private static final int NOTIFICATION_ID = 8888;
    private static final String CHANNEL_ID = "adhan_service_channel";

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        createNotificationChannel();
        showNotification();
        return START_STICKY;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Adhan Service",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Background Adhan monitoring");
            channel.setShowBadge(false);
            
            NotificationManager manager = 
                (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            manager.createNotificationChannel(channel);
        }
    }

    private void showNotification() {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, 
            notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Qurani Prayer Times")
            .setContentText("Monitoring prayer times...")
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW);

        startForeground(NOTIFICATION_ID, builder.build());
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    public static void startService(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(new Intent(context, AdhanForegroundService.class));
        } else {
            context.startService(new Intent(context, AdhanForegroundService.class));
        }
    }

    public static void stopService(Context context) {
        context.stopService(new Intent(context, AdhanForegroundService.class));
    }
}
```

### Step 3: Register Service in AndroidManifest.xml

```xml
<!-- Inside <application> tag -->
<service
    android:name=".AdhanForegroundService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="false" />
```

### Step 4: Create Dart Wrapper

Create file: `lib/services/adhan_foreground_service_io.dart`

```dart
import 'package:flutter/services.dart';

class AdhanForegroundService {
  static const platform = MethodChannel('com.qurani.app/adhan');

  static Future<void> start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldStart = prefs.getBool('adhan_foreground_service') ?? true;
      
      if (!shouldStart) {
        debugPrint('[AdhanForegroundService] Service disabled by user');
        return;
      }
      
      await platform.invokeMethod('startForegroundService');
      debugPrint('[AdhanForegroundService] ✓ Foreground service started');
    } catch (e) {
      debugPrint('[AdhanForegroundService] Error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await platform.invokeMethod('stopForegroundService');
      debugPrint('[AdhanForegroundService] ✓ Foreground service stopped');
    } catch (e) {
      debugPrint('[AdhanForegroundService] Error: $e');
    }
  }
}
```

### Step 5: Update MainActivity.kt

Add to `android/app/src/main/kotlin/com/qurani/app/MainActivity.kt`:

```kotlin
import android.content.Context

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Start foreground service to keep app alive for alarms
        AdhanForegroundService.startService(this)
        
        // Set up method channel
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, 
            "com.qurani.app/adhan").setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    AdhanForegroundService.startService(this)
                    result.success(null)
                }
                "stopForegroundService" -> {
                    AdhanForegroundService.stopService(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
```

### Step 6: Update AdhanScheduler.init()

```dart
// In lib/services/adhan_scheduler_io.dart

static Future<void> init() async {
  try {
    debugPrint('[AdhanScheduler] INITIALIZING...');
    
    // Start foreground service to keep app alive for alarms
    await AdhanForegroundService.start();
    
    final success = await AndroidAlarmManager.initialize();
    debugPrint('[AdhanScheduler] AndroidAlarmManager initialized: $success');
    
    // ... rest of init code
  }
}
```

---

## Why This Works

1. **Foreground Service runs continuously** ✓
   - Shows persistent notification
   - Android rarely kills services with notification
   - App process stays alive

2. **When alarm fires** ✓
   - App process exists
   - Callback can execute in that process
   - Audio can play

3. **User sees notification** ✓
   - "Qurani Prayer Times" in notification bar
   - Shows app is monitoring
   - Can tap to open app

---

## Battery Impact

- **Foreground service**: ~2-5% additional battery per hour
- **Justification**: Prayer times need reliability
- **User Control**: Add toggle in Settings to disable

```dart
// In preferences_screen.dart or settings
SwitchListTile(
  title: Text('Adhan Background Service'),
  subtitle: Text('Keeps app alive for reliable prayer time notifications'),
  value: PreferencesService.getAdhanBackgroundService(),
  onChanged: (bool value) {
    PreferencesService.setAdhanBackgroundService(value);
    if (value) {
      AdhanForegroundService.start();
    } else {
      AdhanForegroundService.stop();
    }
  },
)
```

---

## Testing After Implementation

### Test 1: Service Shows
```
Settings → Apps → Running apps
Should see "Qurani Prayer Times" in background services
```

### Test 2: Alarm With App Closed
```
Schedule alarm for 5 seconds
Close app
Wait for alarm
Adhan should play with logs showing [AdhanScheduler.Callback]
```

### Test 3: Battery Impact
```
Settings → Battery → App battery usage
Should see minimal impact if service well-implemented
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Service crashes on start | Check R.mipmap.launcher_icon exists |
| Alarm still doesn't work | Verify service is actually running (logs) |
| Battery drain too high | Optimize notification update frequency |
| User complains about notification | Explain it's necessary for reliability |

---

## Alternative: Simpler Approach (Without Foreground Service)

If foreground service is too complex, try simpler workaround:

1. **Use persistent notification** (already added to audio playback)
2. **Launch app in background** when alarm fires
3. **Use WakeLock** to prevent sleep during alarm handling

This is less reliable but easier to implement.

---

## Migration Path

If you want to try the simpler approach first:
1. Test current implementation
2. If alarms don't work → Use foreground service
3. If battery too high → Switch to simpler approach
