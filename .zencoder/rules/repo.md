---
description: Repository Information Overview
alwaysApply: true
---

# Qurani Flutter App Information

## Summary

**Qurani** is a comprehensive Flutter application providing Islamic content and prayer utilities including Quranic text in multiple languages/translations, audio recitations, prayer time tracking, adhan notifications, and memorization tools. The app supports iOS, Android, and web platforms with offline functionality and local database persistence.

## Structure

### Main Directories
- **`lib/`**: Core application code with screens, services, models, and utilities
  - `audio_player_screen.dart`: Background audio playback with notifications
  - `prayer_times_screen.dart`: Prayer time calculation and display
  - `services/`: Platform-specific services (audio, notifications, prayer times, adhan scheduling)
  - `models/`: Data models for Quranic content
  - `widgets/`: Reusable UI components
  - `l10n/`: Localization files
- **`android/`**: Android-specific native code and Gradle configuration
- **`ios/`**: iOS-specific configuration and native code
- **`web/`**: Web platform assets and configuration
- **`assets/`**: Application resources including Quranic databases, audio, fonts, and translations
- **`tool/`**: Utility scripts for building Quranic database and full-text search indexes
- **`public/`**: Web-accessible HTML and JSON files (legal terms, help docs)

## Language & Runtime

**Language**: Dart (Flutter Framework)
**SDK Version**: >=3.0.0 <4.0.0
**Flutter Minimum**: Managed by `flutter.minSdkVersion` in Android config
**Android**:
- Compile SDK: 36
- Target SDK: 36
- Min SDK: Flutter-managed (typically API 21+)
- Java/Kotlin: Version 17
- Gradle: 8.7.3
- Kotlin: 2.1.0

**iOS**: Standard Flutter iOS configuration (Runner project)

## Dependencies

### Main Production Dependencies (from pubspec.yaml)
- **Audio**: `just_audio` (0.9.39), `just_audio_background` (0.0.1-beta.17), `audio_session` (0.1.16)
- **Notifications**: `flutter_local_notifications` (17.2.2), `timezone` (0.9.2)
- **Platform**: `permission_handler` (11.0.1), `device_info_plus` (12.2.0), `package_info_plus` (9.0.0)
- **Data**: `sqflite` (2.3.3), `path_provider` (2.1.3), `shared_preferences` (2.3.2)
- **Location/Prayer**: `flutter_qiblah` (3.1.0+1), `geocoding` (2.1.1)
- **Networking**: `dio` (5.4.0), `url_launcher` (6.3.1)
- **UI/UX**: `google_fonts` (6.2.1), `cupertino_icons` (1.0.8), `webview_flutter` (4.7.0)
- **Localization**: `intl` (0.20.2), `flutter_localizations` (SDK)
- **Utilities**: `pdf` (3.10.7), `share_plus` (7.2.1), `uuid` (4.5.2), `in_app_update` (4.2.2)
- **Background**: `android_alarm_manager_plus` (5.0.0) for Adhan scheduling

### Development Dependencies
- `flutter_test` (SDK)
- `flutter_lints` (2.0.0)
- `sqlite3` (2.4.0)

### Build Tools
- `flutter_launcher_icons` (0.14.4)
- `flutter_native_splash` (2.4.7)

## Build & Installation

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build Android APK (release)
flutter build apk --release

# Build Android App Bundle
flutter build appbundle --release

# Build iOS app (release)
flutter build ios --release

# Build web app
flutter build web

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## Main Files & Resources

**Application Entry Point**: `lib/main.dart`

**Key Screens** (All screens in `lib/` root):
- `read_quran_screen.dart`: Quranic text reading interface
- `listen_quran_screen.dart`: Audio recitation playback
- `audio_player_screen.dart`: Enhanced audio player with background notifications
- `prayer_times_screen.dart`: Prayer time tracking and display
- `month_prayer_times_screen.dart`: Monthly prayer schedule
- `memorization_test_screen.dart`: Memorization testing and tracking
- `offline_audio_screen.dart`: Downloaded audio management
- `preferences_screen.dart`: User settings and preferences

**Core Services** (all in `lib/services/`):
- Platform-specific services with `.dart` (interface), `_io.dart` (Android/iOS), and `_web.dart` variants
- `adhan_scheduler_io.dart`: Android alarm scheduling for prayer times
- `audio_service_io.dart`: Audio playback control
- `notification_service_io.dart`: Native notification management
- `prayer_times_service_io.dart`: Prayer time calculations
- `quran_repository.dart`: Quranic content data access layer
- `preferences_service.dart`: Persistent user preferences

**Assets**:
- `assets/data/quran.db`: SQLite database with Quranic text
- `assets/data/quran-*`: Multiple translations (simple, Uthmani, English, French, Muyassar)
- `assets/fonts/AmiriQuran-Regular.ttf`: Arabic typography for Quranic text

**Configuration**:
- `pubspec.yaml`: Project dependencies and asset declarations
- `l10n_.yaml`: Localization configuration
- `flutter_launcher_icons.yaml`: App icon configuration
- `flutter_native_splash.yaml`: Splash screen configuration
- `android/app/build.gradle`: Android build configuration with Java 17, desugaring enabled
- `android/gradle.properties`: Gradle JVM settings and AndroidX configuration

## Testing

**Testing Framework**: Flutter Test (SDK) available but not actively configured
**Test Location**: No test directory found
**Status**: Manual testing approach - app includes debug screens for audio/notification testing

## Architecture & Key Features

**Modular Design**: Service layer abstraction with platform-specific implementations (_io for Android/iOS, _web for web)

**Offline Support**: SQLite database with pre-cached Quranic content and audio files

**Background Operations**:
- Background audio playback with persistent notifications
- Android alarm-based Adhan scheduling with `android_alarm_manager_plus`
- Audio session management for proper focus handling

**Multi-Platform**: Single codebase targeting Android (API 21+), iOS, and web with platform-specific optimizations

**State Management**: Appears to use widget-level state management with StatefulWidget components
