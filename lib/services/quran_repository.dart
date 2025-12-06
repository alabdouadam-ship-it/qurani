// Conditional export: use web implementation for web, IO implementation for mobile
export 'quran_repository_web.dart' if (dart.library.io) 'quran_repository_io.dart';
