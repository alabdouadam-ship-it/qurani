import 'package:sqflite/sqflite.dart' as sqf;
import '../models/surah.dart';
import 'quran_database_service.dart';

class SurahService {
  static List<Surah>? _cachedArabic;
  static sqf.Database? _db;

  static void _clearCache() {
    _cachedArabic = null;
  }

  /// Routes through the shared [QuranDatabaseService] so we're not
  /// opening a second handle to the same `quran.db` file. See that
  /// service for the asset-copy / schema-validation details.
  static Future<void> _ensureDb() async {
    if (_db != null && _db!.isOpen) return;
    _db = await QuranDatabaseService.database();
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


