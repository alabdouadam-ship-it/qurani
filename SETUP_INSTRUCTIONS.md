# 🚀 Qurani App - Quick Start Guide

## For New Developers (Never Used Flutter Before)

This project has been cleaned to minimize size. Follow these steps to get it running.

---

## ⚡ Quick Setup (3 Steps)

### 1️⃣ Install Flutter & Android Studio
- **Flutter SDK**: [Download here](https://flutter.dev/docs/get-started/install)
- **Android Studio**: [Download here](https://developer.android.com/studio)
- Add Flutter to your system PATH
- Run: `flutter doctor --android-licenses` (accept all)

### 2️⃣ Install Project Dependencies
Open terminal in this project folder and run:
```bash
flutter pub get
```

### 3️⃣ Run the App
```bash
flutter run
```

---

## 📋 Detailed Setup Guide

For complete step-by-step instructions, see the full setup guide that was provided with this project.

---

## ✅ Verify Installation

Run this command to check if everything is set up correctly:
```bash
flutter doctor
```

You should see checkmarks (✓) for Flutter and Android toolchain.

---

## 🔧 Common First-Time Issues

**"Flutter not recognized"**
→ Add Flutter to your PATH environment variable

**"No devices found"**
→ Create an Android emulator or connect a physical device with USB debugging enabled

**"Android licenses not accepted"**
→ Run: `flutter doctor --android-licenses`

---

## 📱 Running Options

**On Emulator:**
```bash
flutter emulators --create
flutter emulators --launch <emulator_name>
flutter run
```

**On Physical Device:**
1. Enable Developer Options & USB Debugging on your phone
2. Connect via USB
3. Run: `flutter run`

---

## 🏗️ Building Release Version

**APK (for testing):**
```bash
flutter build apk --release
```

**AAB (for Play Store):**
```bash
flutter build appbundle --release
```

---

## 📚 Project Info

- **Language**: Dart
- **Framework**: Flutter
- **Platforms**: Android, iOS, Web
- **Main Entry**: `lib/main.dart`

---

## 🆘 Need Help?

1. Check `flutter doctor -v` for detailed diagnostics
2. Visit [Flutter Documentation](https://docs.flutter.dev/)
3. Search on [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

---

**Note**: This project was cleaned using `flutter clean` to reduce size. All build artifacts will be regenerated automatically when you run the app.
