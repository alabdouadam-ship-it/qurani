// Conditional export: use web implementation for web, IO implementation for mobile
export 'surah_service_web.dart' if (dart.library.io) 'surah_service_io.dart';
