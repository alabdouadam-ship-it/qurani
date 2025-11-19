package com.qurani.app

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSdkInt") {
                result.success(Build.VERSION.SDK_INT)
            } else {
                result.notImplemented()
            }
        }
        
        // Adhan playback channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL).setMethodCallHandler { call, result ->
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
                else -> result.notImplemented()
            }
        }
    }
    
    private fun playAdhan(filePath: String, volume: Double) {
        try {
            stopAdhan() // Stop any existing playback
            
            val file = File(filePath)
            if (!file.exists()) {
                android.util.Log.e("MainActivity", "Adhan file not found: $filePath")
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
                }
                
                setOnErrorListener { _, what, extra ->
                    android.util.Log.e("MainActivity", "MediaPlayer error: what=$what, extra=$extra")
                    release()
                    adhanPlayer = null
                    true
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error playing Adhan: ${e.message}", e)
            adhanPlayer?.release()
            adhanPlayer = null
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
        }
    }
    
    override fun onDestroy() {
        stopAdhan()
        super.onDestroy()
    }
}

