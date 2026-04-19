package com.qurani.app

import android.app.NotificationManager
import android.content.Context
import android.media.MediaPlayer
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "qurani/system"
    private val ADHAN_CHANNEL = "qurani/adhan"
    private var adhanPlayer: MediaPlayer? = null
    // Reference held so the native side can invoke Dart callbacks (e.g.
    // `adhanPlaybackEnded`) when playback finishes, allowing the Dart layer
    // to clear its `isPlayingListenable` without polling.
    private var adhanChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                else -> result.notImplemented()
            }
        }
        
        // Adhan playback channel
        adhanChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL)
        adhanChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "playAdhan" -> {
                    val filePath = call.argument<String>("filePath")
                    val volume = call.argument<Double>("volume") ?: 1.0
                    if (filePath != null) {
                        playAdhan(filePath, volume)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                "stopAdhan" -> {
                    stopAdhan()
                    result.success(true)
                }
                "isAdhanPlaying" -> {
                    result.success(adhanPlayer?.isPlaying ?: false)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Notify the Dart side that native playback has ended so it can clear
     * `AdhanAudioManager.isPlayingListenable`. Must run on the UI thread —
     * MethodChannel invocations from background threads are unsafe.
     */
    private fun notifyPlaybackEnded() {
        runOnUiThread {
            try {
                adhanChannel?.invokeMethod("adhanPlaybackEnded", null)
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "Failed to notify adhanPlaybackEnded: ${e.message}")
            }
        }
    }
    
    private fun playAdhan(filePath: String, volume: Double) {
        try {
            stopAdhan() // Stop any existing playback
            
            val file = File(filePath)
            if (!file.exists()) {
                android.util.Log.e("MainActivity", "Adhan file not found: $filePath")
                notifyPlaybackEnded()
                return
            }
            
            adhanPlayer = MediaPlayer().apply {
                setDataSource(filePath)
                setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                prepare()
                setVolume(volume.toFloat(), volume.toFloat())
                start()
                
                setOnCompletionListener {
                    release()
                    adhanPlayer = null
                    notifyPlaybackEnded()
                }
                
                setOnErrorListener { _, what, extra ->
                    android.util.Log.e("MainActivity", "MediaPlayer error: what=$what, extra=$extra")
                    release()
                    adhanPlayer = null
                    notifyPlaybackEnded()
                    true
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error playing Adhan: ${e.message}", e)
            adhanPlayer?.release()
            adhanPlayer = null
            notifyPlaybackEnded()
        }
    }
    
    private fun stopAdhan() {
        adhanPlayer?.let {
            try {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error stopping Adhan: ${e.message}", e)
            }
            adhanPlayer = null
            notifyPlaybackEnded()
        }
    }
    
    override fun onDestroy() {
        stopAdhan()
        adhanChannel = null
        super.onDestroy()
    }

    /**
     * Non-intrusive check for USE_FULL_SCREEN_INTENT. On Android 14+ (API 34)
     * the permission is runtime-gated and revoked by Google Play for apps that
     * don't qualify as calendar/alarm/calling; this returns the current grant
     * state without opening the Settings page. On Android 13 and below the
     * permission is granted at install time, so we return true.
     */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return true
        }
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.canUseFullScreenIntent()
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "canUseFullScreenIntent probe failed: ${e.message}")
            false
        }
    }
}

