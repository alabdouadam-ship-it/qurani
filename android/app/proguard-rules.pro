# ============================================================================
# R8 / ProGuard keep rules for Qurani release builds.
# Flutter enables R8 by default for --release, which strips generic type
# signatures and unused classes. Some plugins rely on reflection / Gson and
# break without explicit keep rules.
# ============================================================================

# ── flutter_local_notifications ─────────────────────────────────────────────
# The plugin serializes scheduled notifications with Gson. Under R8 the
# generic TypeToken signatures get stripped, causing at runtime:
#   PlatformException(error, Missing type parameter., ...)
#   at FlutterLocalNotificationsPlugin.loadScheduledNotifications
# Keeping the plugin's classes + Gson generic-signature metadata fixes it.
# See: https://github.com/MaikuB/flutter_local_notifications (R8/ProGuard note)
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Gson: preserve generic signatures and annotations used for (de)serialization.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn com.google.gson.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# Gson model classes are accessed reflectively; keep their fields.
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
