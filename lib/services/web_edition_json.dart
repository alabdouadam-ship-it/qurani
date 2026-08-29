/// Web-only loader for the Quran edition JSONs.
///
/// **Only import this from `*_web.dart` implementations.** On io (Android/iOS)
/// every edition is read from the bundled `assets/data/quran.db` via
/// `QuranEdition.dbColumn`, so these JSONs are not shipped there at all.
///
/// ### Why these files are not Flutter assets
/// They used to live in `assets/data/editions/` and be declared in
/// `pubspec.yaml`, which meant ~105 MB of web-only JSON was bundled into every
/// Android and iOS build even though nothing on those platforms reads it. There
/// is no per-platform asset list in `pubspec.yaml`, so the files were moved to
/// `web/data/editions/`: `flutter build web` copies the whole `web/` directory
/// into `build/web`, while the Android/iOS builds ignore it entirely.
///
/// Runtime behaviour on web is unchanged: `rootBundle.loadString('assets/...')`
/// was already an HTTP request for a file served from the same origin. This
/// just changes which URL it lives at.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches and decodes one edition JSON.
///
/// [relativePath] is relative to the deployed web app root (e.g.
/// `data/editions/quran-simple.json`) and is resolved against [Uri.base], so
/// the app keeps working when hosted under a sub-path as well as at the root.
Future<Map<String, dynamic>> loadEditionJson(String relativePath) async {
  final uri = Uri.base.resolve(relativePath);
  final http.Response resp;
  try {
    resp = await http.get(uri);
  } catch (e) {
    throw Exception('Failed to fetch edition JSON $relativePath: $e');
  }

  if (resp.statusCode != 200) {
    throw Exception(
        'Failed to fetch edition JSON $relativePath: HTTP ${resp.statusCode}');
  }

  // Decode as UTF-8 explicitly: `resp.body` guesses latin-1 when the server
  // omits a charset, which mangles Arabic text.
  final body = utf8.decode(resp.bodyBytes);

  // Firebase Hosting rewrites every unmatched path to `/index.html` with a
  // 200, so a typo'd or missing file arrives as HTML rather than a 404. Fail
  // with a clear message instead of an opaque JSON parse error. (Same trap the
  // hadith loader hit when fetching non-bundled books on web.)
  final head = body.trimLeft();
  if (head.startsWith('<')) {
    throw Exception(
        'Expected JSON at $relativePath but got HTML — the file is missing '
        'from web/data/editions/ and the SPA rewrite served index.html.');
  }

  return json.decode(body) as Map<String, dynamic>;
}
