// TODO: Replace 'dart:html' with 'package:web/web.dart' when dependencies migrate (analyzer info-level warning only)
// ignore: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class NetUtils {
  static Future<bool> hasInternet() async {
    try {
      // Attempt a lightweight request; allow CORS to fail fast
      final request = await html.HttpRequest.request(
        'https://example.com',
        method: 'HEAD',
      );
      final status = request.status ?? 0;
      return status >= 200 && status < 500;
    } catch (_) {
      // Fallback to navigator.onLine when request fails
      final online = html.window.navigator.onLine;
      return online ?? true;
    }
  }
}


