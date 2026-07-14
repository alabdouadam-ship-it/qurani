import 'dart:io';

class NetUtils {
  static Future<bool> hasInternet() async {
    try {
      // Bounded so a slow/broken DNS resolver can never stall callers that
      // gate on connectivity (e.g. audio preparation shows an endless spinner
      // otherwise). Uses google.com — a reliably-resolving host.
      final res = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}


