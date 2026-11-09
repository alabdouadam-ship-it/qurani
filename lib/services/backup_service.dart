import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_bookmark.dart';
import '../models/quran_bounds.dart';
import 'spaced_review_service.dart';
import 'backup_tables.dart';

class BackupData {
  final Map<String, dynamic> preferences;
  final Map<String, dynamic>? tables;
  final DateTime createdAt;
  BackupData(this.preferences, this.tables, this.createdAt);
  Map<String, Object?> toJson() => {
        'format': 'qurani-backup',
        'version': 1,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'preferences': preferences,
        'tables': tables
      };
  int get records =>
      preferences.length +
      (tables?.values.fold<int>(0, (n, rows) => n + (rows as List).length) ??
          0);
}

class BackupService {
  BackupService(
      {Future<Map<String, dynamic>?> Function()? readTables,
      Future<void> Function(Map<String, dynamic>?)? writeTables})
      : _readTables = readTables ?? readBackupTables,
        _writeTables = writeTables ?? writeBackupTables;
  static final instance = BackupService();
  final Future<Map<String, dynamic>?> Function() _readTables;
  final Future<void> Function(Map<String, dynamic>?) _writeTables;
  bool _restoring = false;
  static const maxBytes = 10 * 1024 * 1024;
  static const journalKey = 'backup_restore_rollback_v1';
  static const _strings = {
    'reciter',
    'theme',
    'language',
    'arabic_font_family',
    'last_read_edition',
    'last_repetition_edition',
    'adhan_sound',
    'pdf_type',
    'secondary_edition_id',
    'secondary_edition_fallback_id'
  };
  static const _bools = {
    'reciter_rotation_enabled_v1',
    'auto_flip_page',
    'always_start_from_beginning',
    'auto_play_next_surah',
    'is_repeat',
    'is_pdf_mode',
    'time_format_12h',
    'start_at_last_page',
    'secondary_edition_enabled',
    'adhan_fajr',
    'adhan_dhuhr',
    'adhan_asr',
    'adhan_maghrib',
    'adhan_isha'
  };
  static const _ints = {
    'verse_repeat_count',
    'range_repetition_count',
    'user_prayer_method',
    'memorization_question_limit',
    'memorization_total_score',
    'memorization_total_tests',
    'memorization_total_correct_sum',
    'memorization_total_questions_sum'
  };
  static const _lists = {
    'listen_featured_surahs',
    'disabled_screens_v1',
    'highlighted_pdf_pages',
    'highlighted_ayahs',
    'news_saved_ids',
    'repetition_passage_v1'
  };
  static const _jsonMaps = {
    'highlighted_ayahs_colors',
    'prayer_time_adjustments',
    'memorization_surah_mastery',
    'memorization_last_surah_map',
    'memorization_best_surah_map',
    'memorization_last_juz_map',
    'memorization_best_juz_map',
    'memorization_surah_agg',
    'memorization_juz_agg'
  };
  static const _jsonLists = {
    'audio_bookmarks_list_v1',
    'reciter_rotation_order_v1',
    'memorization_test_history',
    SpacedReviewService.storageKey
  };
  static bool allowed(String key) =>
      _strings.contains(key) ||
      _bools.contains(key) ||
      _ints.contains(key) ||
      _lists.contains(key) ||
      _jsonMaps.contains(key) ||
      _jsonLists.contains(key) ||
      key == 'font_size' ||
      key == 'adhan_volume' ||
      RegExp(r'^last_playback_position_([1-9]|[1-9][0-9]|10[0-9]|11[0-4])$')
          .hasMatch(key) ||
      RegExp(r'^last_read_page_[a-zA-Z0-9_.-]+$').hasMatch(key);

  static void validatePreference(String key, dynamic value) {
    if (!allowed(key)) throw FormatException('Unsupported preference: $key');
    if (_bools.contains(key)) {
      if (value is! bool) throw const FormatException('Expected boolean');
      return;
    }
    if (_ints.contains(key) ||
        key.startsWith('last_playback_position_') ||
        key.startsWith('last_read_page_')) {
      if (value is! int || value < 0 || value > 1000000000) {
        throw const FormatException('Invalid integer');
      }
      if (key.startsWith('last_read_page_') && (value < 1 || value > 604)) {
        throw const FormatException('Invalid page');
      }
      if ((key == 'verse_repeat_count' || key == 'range_repetition_count') &&
          (value < 1 || value > (key == 'verse_repeat_count' ? 50 : 20))) {
        throw const FormatException('Invalid repeat count');
      }
      if (key == 'memorization_question_limit' &&
          ![10, 15, 20, 25, 30, 40, 50, 75, 100, 200].contains(value)) {
        throw const FormatException('Invalid question limit');
      }
      return;
    }
    if (key == 'font_size' || key == 'adhan_volume') {
      if (value is! num ||
          !value.isFinite ||
          (key == 'font_size'
              ? value < 8 || value > 100
              : value < 0 || value > 1)) {
        throw const FormatException('Invalid number');
      }
      return;
    }
    if (_lists.contains(key)) {
      if (value is! List ||
          value.any((e) => e is! String) ||
          value.length > 10000) {
        throw const FormatException('Invalid list');
      }
      if (key == 'repetition_passage_v1' && value.isNotEmpty) {
        if (value.length != 4) throw const FormatException('Invalid passage');
        final n = value.map((e) => int.parse(e as String)).toList();
        if (!validPassage((
          start: (surah: n[0], verse: n[1]),
          end: (surah: n[2], verse: n[3])
        ))) {
          throw const FormatException('Invalid passage');
        }
      }
      if (key == 'highlighted_pdf_pages' &&
          value.any((e) =>
              int.tryParse(e as String) == null ||
              int.parse(e) < 1 ||
              int.parse(e) > 604)) {
        throw const FormatException('Invalid page');
      }
      return;
    }
    if (value is! String || value.length > maxBytes) {
      throw const FormatException('Expected string');
    }
    if (key == 'language' && !['ar', 'en', 'fr'].contains(value)) {
      throw const FormatException('Invalid language');
    }
    if ((key == 'reciter' || key == 'adhan_sound') &&
        (value.isEmpty ||
            value.contains('/') ||
            value.contains('\\') ||
            value.contains('..'))) {
      throw const FormatException('Invalid audio key');
    }
    if (_jsonMaps.contains(key) || _jsonLists.contains(key)) {
      final decoded = jsonDecode(value);
      if (_jsonMaps.contains(key) ? decoded is! Map : decoded is! List) {
        throw const FormatException('Invalid structured preference');
      }
      if (key == SpacedReviewService.storageKey) {
        SpacedReviewService.decode(value);
      }
      if (key == 'audio_bookmarks_list_v1') {
        for (final row in decoded as List) {
          final b =
              AudioBookmark.fromJson(Map<String, dynamic>.from(row as Map));
          if (b.reciterId != null) validatePreference('reciter', b.reciterId);
          if (b.surahId < 1 || b.surahId > 114 || b.positionMs < 0) {
            throw const FormatException('Invalid bookmark');
          }
        }
      }
      if (key == 'reciter_rotation_order_v1' &&
          (decoded as List).any((e) => e is! String)) {
        throw const FormatException('Invalid reciters');
      }
      if (key == 'highlighted_ayahs_colors' ||
          key == 'prayer_time_adjustments' ||
          key == 'memorization_surah_mastery') {
        if ((decoded as Map).values.any((v) => v is! int)) {
          throw const FormatException('Invalid mapping');
        }
      }
      if (key.startsWith('memorization_')) _validateStats(decoded);
      if (key == 'highlighted_ayahs_colors' ||
          key == 'memorization_surah_mastery') {
        final max = key == 'highlighted_ayahs_colors' ? 6236 : 114;
        if ((decoded as Map).keys.any((k) =>
            int.tryParse(k as String) == null ||
            int.parse(k) < 1 ||
            int.parse(k) > max)) {
          throw const FormatException('Invalid Quran reference');
        }
      }
      if (key == 'memorization_test_history') {
        for (final row in decoded as List) {
          for (final field in [
            'correctAnswers',
            'totalQuestions',
            'score',
            'percentage',
            'timestamp'
          ]) {
            if (row[field] is! int) {
              throw const FormatException('Invalid test history');
            }
          }
          if (row['totalQuestions'] < 1 ||
              row['correctAnswers'] > row['totalQuestions'] ||
              row['percentage'] > 100) {
            throw const FormatException('Invalid score');
          }
          for (final field in ['surahNumber', 'juzNumber']) {
            final n = row[field];
            if (n != null &&
                (n is! int ||
                    n < 1 ||
                    n > (field == 'surahNumber' ? 114 : 30))) {
              throw const FormatException('Invalid test scope');
            }
          }
        }
      }
      if (key.startsWith('memorization_') &&
          key != 'memorization_test_history' &&
          key != 'memorization_surah_mastery') {
        for (final row in (decoded as Map).values) {
          if (row is! Map || row.values.any((v) => v is! int)) {
            throw const FormatException('Invalid statistics map');
          }
        }
      }
    }
  }

  static void _validateStats(dynamic value) {
    if (value == null) return;
    if (value is Map) {
      for (final v in value.values) {
        _validateStats(v);
      }
      return;
    }
    if (value is List) {
      for (final v in value) {
        if (v is! Map) throw const FormatException('Invalid history');
        _validateStats(v);
      }
      return;
    }
    if (value is! num || !value.isFinite || value < 0) {
      throw const FormatException('Invalid statistics');
    }
  }

  static const _tableFields = {
    'tasbeeh_groups': {
      'id': 's',
      'name': 's',
      'is_custom': 'i',
      'position': 'i'
    },
    'tasbeeh_items': {
      'id': 's',
      'group_id': 's',
      'text': 's',
      'count': 'i',
      'position': 'i'
    },
    'wirds': {
      'id': 's',
      'title': 's',
      'dhikr_text': 's',
      'target_count': 'i',
      'current_count': 'i',
      'days_of_week': 's',
      'notifications_enabled': 'i',
      'notification_time': 's',
      'last_updated_date': 's?',
      'is_deleted': 'i',
      'created_at': 's',
      'position': 'i'
    },
  };
  static void validateTables(Map<String, dynamic>? tables) {
    if (tables == null) return;
    if (tables.length != _tableFields.length) {
      throw const FormatException('Invalid tables');
    }
    final groups = <String>{};
    for (final table in _tableFields.keys) {
      final rows = tables[table];
      if (rows is! List || rows.length > 20000) {
        throw const FormatException('Invalid rows');
      }
      final ids = <String>{};
      for (final row in rows) {
        if (row is! Map || row.length != _tableFields[table]!.length) {
          throw const FormatException('Invalid row');
        }
        for (final field in _tableFields[table]!.entries) {
          final value = row[field.key];
          if (field.value == 's?' && value == null) continue;
          if (field.value.startsWith('s')
              ? value is! String
              : value is! int || value < 0) {
            throw const FormatException('Invalid field');
          }
        }
        if ((row['id'] as String).isEmpty || !ids.add(row['id'] as String)) {
          throw const FormatException('Invalid id');
        }
        if (table == 'tasbeeh_groups') groups.add(row['id'] as String);
        if (table == 'tasbeeh_items' && !groups.contains(row['group_id'])) {
          throw const FormatException('Orphan item');
        }
        if (table == 'wirds') {
          if (row['target_count'] < 1 ||
              !RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$')
                  .hasMatch(row['notification_time'] as String) ||
              !RegExp(r'^[1-7](,[1-7])*$')
                  .hasMatch(row['days_of_week'] as String) ||
              DateTime.tryParse(row['created_at'] as String) == null) {
            throw const FormatException('Invalid Wird');
          }
        }
      }
    }
  }

  static BackupData parse(String raw) {
    if (utf8.encode(raw).length > maxBytes) {
      throw const FormatException('Backup too large');
    }
    final root = jsonDecode(raw);
    if (root is! Map ||
        root['format'] != 'qurani-backup' ||
        root['version'] != 1 ||
        root['preferences'] is! Map) {
      throw const FormatException('Unsupported backup');
    }
    final prefs = Map<String, dynamic>.from(root['preferences'] as Map);
    for (final e in prefs.entries) {
      validatePreference(e.key, e.value);
    }
    final tables = root['tables'] == null
        ? null
        : Map<String, dynamic>.from(root['tables'] as Map);
    validateTables(tables);
    final date = DateTime.tryParse(root['createdAt'] as String? ?? '');
    if (date == null) throw const FormatException('Invalid date');
    return BackupData(prefs, tables, date);
  }

  Future<BackupData> capture() async {
    final tables = await _readTables();
    final prefs = await SharedPreferences.getInstance();
    final values = <String, dynamic>{
      for (final key in prefs.getKeys().where(allowed)) key: prefs.get(key)
    };
    final data = BackupData(values, tables, DateTime.now());
    return parse(jsonEncode(data.toJson()));
  }

  Future<void> _apply(BackupData data) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeTables(data.tables);
    for (final key in prefs.getKeys().where(allowed).toList()) {
      if (!data.preferences.containsKey(key) && !await prefs.remove(key)) {
        throw StateError('Cannot remove preference');
      }
    }
    for (final e in data.preferences.entries) {
      final v = e.value;
      final ok = e.key == 'font_size' || e.key == 'adhan_volume'
          ? await prefs.setDouble(e.key, (v as num).toDouble())
          : v is bool
              ? await prefs.setBool(e.key, v)
              : v is int
                  ? await prefs.setInt(e.key, v)
                  : v is num
                      ? await prefs.setDouble(e.key, v.toDouble())
                      : v is List
                          ? await prefs.setStringList(e.key, v.cast<String>())
                          : await prefs.setString(e.key, v as String);
      if (!ok) throw StateError('Cannot restore preference');
    }
  }

  Future<void> restore(BackupData data) async {
    if (_restoring) throw StateError('Restore already active');
    _restoring = true;
    try {
      await _restore(data);
    } finally {
      _restoring = false;
    }
  }

  Future<void> _restore(BackupData data) async {
    final validated =
        parse(jsonEncode(data.toJson())); // Validate before any write.
    final previous = await capture();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(journalKey, jsonEncode(previous.toJson()))) {
      throw StateError('Cannot save rollback');
    }
    try {
      await _apply(validated);
      if (!await prefs.remove(journalKey)) {
        throw StateError('Cannot commit restore');
      }
    } catch (_) {
      await _apply(previous);
      await prefs.remove(journalKey);
      rethrow;
    }
  }

  Future<void> recoverInterruptedRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(journalKey);
    if (raw == null) return;
    await _apply(parse(raw));
    await prefs.remove(journalKey);
  }
}
