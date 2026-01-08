import 'package:web/web.dart' as web;

class NetUtils {
  static Future<bool> hasInternet() async {
    try {
      // Attempt a lightweight request using XMLHttpRequest
      final request = web.XMLHttpRequest();
      request.open('HEAD', 'https://example.com');
      
      // Send the request and wait for completion
      // Since XMLHttpRequest is async but doesn't return a Future, 
      // we check navigator.onLine as a primary check first.
      // For a true probe, checking navigator.onLine is usually sufficient for "is connected to a network"
      
      // Simple check first
      return web.window.navigator.onLine;

    } catch (_) {
      return web.window.navigator.onLine;
    }
  }
}


