import 'user_database_service.dart';
import 'tasbeeh_service.dart';
import 'wird_service.dart';

Future<Map<String, dynamic>?> readBackupTables() async {
  await TasbeehService.getGroups();
  await WirdService.getActive();
  final db = await UserDatabaseService.database();
  return db.transaction((txn) async => {
        'tasbeeh_groups': await txn.query('tasbeeh_groups'),
        'tasbeeh_items': await txn.query('tasbeeh_items'),
        'wirds': await txn.query('wirds'),
      });
}

Future<void> writeBackupTables(Map<String, dynamic>? tables) async {
  if (tables == null) return; // A web-only backup has no native counters.
  final db = await UserDatabaseService.database();
  await db.transaction((txn) async {
    for (final table in ['tasbeeh_items', 'tasbeeh_groups', 'wirds']) {
      await txn.delete(table);
    }
    for (final table in ['tasbeeh_groups', 'tasbeeh_items', 'wirds']) {
      for (final row in tables[table] as List) {
        await txn.insert(table, Map<String, Object?>.from(row as Map));
      }
    }
  });
}
