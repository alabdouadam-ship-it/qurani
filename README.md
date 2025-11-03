# Qurani Flutter App

A Flutter application that wraps the Qurani.info website in a WebView with a custom app bar and refresh functionality.

## Features

- **WebView Integration**: Displays the Qurani.info website seamlessly
- **Custom App Bar**: Clean, minimal app bar with app title
- **Smart Refresh**: Refresh button that clears cache, local storage, cookies, and IndexedDB before reloading
- **No Browser UI**: Completely hides browser toolbars and navigation elements
- **Loading Indicator**: Shows loading spinner while pages load
- **Cross-Platform**: Works on both Android and iOS

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Android Studio / Xcode (for device testing)
- VS Code or Android Studio (for development)

### Installation

1. Clone or download this project
2. Navigate to the project directory:
   ```bash
   cd Qurani
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

### Building for Release

#### Android
```bash
flutter build apk --release
```

#### iOS
```bash
flutter build ios --release
```

## App Structure

- `lib/main.dart`: Main application file with WebView implementation
- `pubspec.yaml`: Dependencies and project configuration
- `android/`: Android-specific configuration
- `ios/`: iOS-specific configuration

## Key Features Explained

### WebView Configuration
- JavaScript is enabled for full website functionality
- Navigation delegate handles page loading states
- Cache and local storage clearing functionality

### Refresh Functionality
The refresh button performs a comprehensive cleanup:
- Clears WebView cache
- Clears local storage
- Clears session storage
- Clears all cookies
- Clears IndexedDB data
- Reloads the page

### UI Design
- Material Design 3 with green color scheme
- Minimal app bar with refresh icon
- Loading indicator during page loads
- No browser UI elements visible

## Dependencies

- `webview_flutter`: ^4.4.2 - For WebView functionality
- `cupertino_icons`: ^1.0.2 - For iOS-style icons

## Notes

- The app requires internet connection to load the Qurani.info website
- All website functionality is preserved through the WebView
- The refresh functionality ensures a clean state when needed
- The app is optimized for both portrait and landscape orientations
