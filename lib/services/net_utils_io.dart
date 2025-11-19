import 'dart:io';

class NetUtils {
  static Future<bool> hasInternet() async {
    try {
      final res = await InternetAddress.lookup('example.com');
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}


