// Conditional export: use web implementation for web, IO implementation for mobile
export 'local_webview_screen_web.dart' if (dart.library.io) 'local_webview_screen_io.dart';
