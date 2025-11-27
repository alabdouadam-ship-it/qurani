import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqf;
import 'package:flutter/services.dart' show rootBundle;
import '../models/surah.dart';

class SurahService {
  static const int _dbSchemaVersion = 2;
  static const String _dbVersionKey = 'quran_db_schema_version';
  
  static List<Surah>? _cachedArabic;
  static sqf.Database? _db;

  static void _clearCache() {
    _cachedArabic = null;
  }

  static Future<void> _ensureDb() async {
    if (_db != null) return;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'quran.db');
    
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_dbVersionKey) ?? 0;
    
    final dbFile = File(dbPath);
    bool needsCopy = !dbFile.existsSync() || storedVersion < _dbSchemaVersion;
    
    if (!needsCopy) {
      sqf.Database? tempDb;
      try {
        tempDb = await sqf.openDatabase(dbPath, readOnly: true);
        
        // Check if surah table exists
        final tables = await tempDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='surah'"
        );
        
        if (tables.isEmpty) {
          throw Exception('surah table missing');
        }
        
        // Check if required columns exist
        await tempDb.rawQuery('SELECT name_en, total_verses FROM surah LIMIT 1');
        
        await tempDb.close();
        tempDb = null;
      } catch (e) {
        needsCopy = true;
        
        if (tempDb != null) {
          try {
            await tempDb.close();
          } catch (_) {}
          tempDb = null;
        }
        
        // Clear cached data
        _clearCache();
        _db = null;
        
        await Future.delayed(const Duration(milliseconds: 200));
        
        try {
          if (dbFile.existsSync()) {
            await dbFile.delete();
          }
          // Delete related files
          final shmFile = File('$dbPath-shm');
          final walFile = File('$dbPath-wal');
          if (shmFile.existsSync()) await shmFile.delete();
          if (walFile.existsSync()) await walFile.delete();
        } catch (_) {}
      }
    }
    
    if (needsCopy) {
      // Delete old database if it exists
      if (dbFile.existsSync()) {
        await dbFile.delete();
      }
      final shmFile = File('$dbPath-shm');
      final walFile = File('$dbPath-wal');
      if (shmFile.existsSync()) await shmFile.delete();
      if (walFile.existsSync()) await walFile.delete();
      
      final bytes = await rootBundle.load('assets/data/quran.db');
      await dbFile.parent.create(recursive: true);
      await dbFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      
      // Update stored version
      await prefs.setInt(_dbVersionKey, _dbSchemaVersion);
    }
    
    _db = await sqf.openDatabase(dbPath, readOnly: true);
  }

  static Future<List<Surah>> _loadFromDatabase({bool useEnglishName = false}) async {
    await _ensureDb();
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    final rows = await _db!.query('surah', orderBy: 'order_no');
    
    return rows.map((r) {
      final String name;
      if (useEnglishName) {
        name = (r['name_en'] as String? ?? r['name_ar'] as String? ?? '');
      } else {
        name = (r['name_ar'] as String? ?? '');
      }
      
      return Surah(
        name: name,
        order: (r['order_no'] as int? ?? 0),
        totalVerses: (r['total_verses'] as int? ?? 0),
      );
    }).toList();
  }

  static Future<List<Surah>> getArabicSurahs() async {
    if (_cachedArabic != null) return _cachedArabic!;
    _cachedArabic = await _loadFromDatabase(useEnglishName: false);
    return _cachedArabic!;
  }

  static Future<List<Surah>> getLatinSurahs() async {
    return _loadFromDatabase(useEnglishName: true);
  }

  static Future<List<Surah>> getLocalizedSurahs(String langCode) async {
    if (langCode == 'ar') {
      return getArabicSurahs();
    }
    return _loadFromDatabase(useEnglishName: true);
  }
}


