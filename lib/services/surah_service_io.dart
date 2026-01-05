import 'dart:io';
import 'package:path/path.dart' as p;
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
    if (_db != null && _db!.isOpen) return;
    
    // If database exists but is closed, reset it
    if (_db != null && !_db!.isOpen) {
      _db = null;
    }
    
    // Use sqflite's standard database directory
    final databasesPath = await sqf.getDatabasesPath();
    final dbPath = p.join(databasesPath, 'quran.db');
    
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_dbVersionKey) ?? 0;
    
    // Use sqflite's databaseExists for proper check
    bool dbExists = await sqf.databaseExists(dbPath);
    bool needsCopy = !dbExists || storedVersion < _dbSchemaVersion;
    
    if (!needsCopy && dbExists) {
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
          if (await sqf.databaseExists(dbPath)) {
            await sqf.deleteDatabase(dbPath);
          }
        } catch (_) {}
      }
    }
    
    if (needsCopy) {
      try {
        // Delete old database if exists
        if (await sqf.databaseExists(dbPath)) {
          await sqf.deleteDatabase(dbPath);
        }
        
        // Ensure parent directory exists
        final dbFile = File(dbPath);
        final parentDir = dbFile.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }
        
        // Load and write database file
        final bytes = await rootBundle.load('assets/data/quran.db');
        await dbFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        
        // Verify file was written successfully
        if (!await sqf.databaseExists(dbPath)) {
          throw Exception('Failed to write database file');
        }
        
        // Update stored version
        await prefs.setInt(_dbVersionKey, _dbSchemaVersion);
      } catch (e) {
        // Clean up on error
        try {
          if (await sqf.databaseExists(dbPath)) {
            await sqf.deleteDatabase(dbPath);
          }
        } catch (_) {}
        throw Exception('Failed to copy database: $e');
      }
    }
    
    _db = await sqf.openDatabase(dbPath, readOnly: true);
  }

  static Future<List<Surah>> _loadFromDatabase({bool useEnglishName = false}) async {
    try {
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
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        _clearCache();
        _db = null;
        await _ensureDb();
        return _loadFromDatabase(useEnglishName: useEnglishName);
      }
      rethrow;
    }
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


