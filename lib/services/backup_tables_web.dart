import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'backup_native_tables_v1';
Future<Map<String, dynamic>?> readBackupTables() async {
  final raw = (await SharedPreferences.getInstance()).getString(_key);
  return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
}

Future<void> writeBackupTables(Map<String, dynamic>? tables) async {
  final prefs = await SharedPreferences.getInstance();
  if (tables == null) {
    await prefs.remove(_key);
  } else if (!await prefs.setString(_key, jsonEncode(tables))) {
    throw StateError('Cannot save counters');
  }
}
