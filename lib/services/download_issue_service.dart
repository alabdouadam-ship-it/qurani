import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'download_batch.dart';

class DownloadIssue {
  final String reciter;
  final int surah;
  final int? verse;
  final String status;
  final String reason;
  final int attempts;
  const DownloadIssue(
      {required this.reciter,
      required this.surah,
      this.verse,
      this.status = 'interrupted',
      this.reason = 'unknown',
      this.attempts = 0});
  String get key =>
      '${DownloadIssueService.prefix}${Uri.encodeComponent(reciter)}:$surah:${verse == null ? 'full' : verse}';
  Map<String, Object?> toJson() => {
        'reciter': reciter,
        'surah': surah,
        'verse': verse,
        'status': status,
        'reason': reason,
        'attempts': attempts
      };
  factory DownloadIssue.fromJson(Map<String, dynamic> json) => DownloadIssue(
      reciter: json['reciter'] as String,
      surah: json['surah'] as int,
      verse: json['verse'] as int?,
      status: json['status'] as String,
      reason: json['reason'] as String,
      attempts: json['attempts'] as int);
}

class DownloadIssueService {
  static const prefix = 'download_issue_v1:';
  static final Set<String> _active = {};
  static bool isActive(DownloadIssue issue) => _active.contains(issue.key);
  static Future<List<DownloadIssue>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final items = <DownloadIssue>[];
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final raw = prefs.getString(key);
      if (raw != null) {
        items.add(
            DownloadIssue.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      }
    }
    items.sort((a, b) => a.key.compareTo(b.key));
    return items;
  }

  static Future<T> track<T>(DownloadIssue issue, Future<T> Function() task,
      {CancelToken? cancelToken}) async {
    if (!_active.add(issue.key)) throw StateError('Download already active');
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(issue.key);
      final attempts = previous == null
          ? 1
          : DownloadIssue.fromJson(jsonDecode(previous) as Map<String, dynamic>)
                  .attempts +
              1;
      Future<void> save(String status, String reason) async {
        final row = DownloadIssue(
            reciter: issue.reciter,
            surah: issue.surah,
            verse: issue.verse,
            status: status,
            reason: reason,
            attempts: attempts);
        if (!await prefs.setString(issue.key, jsonEncode(row.toJson()))) {
          throw StateError('Cannot save download state');
        }
      }

      await save('interrupted', 'unknown'); // Survives process termination.
      try {
        checkDownloadCancellation(cancelToken);
        final result = await task();
        if (result is DownloadBatchResult && !result.isComplete) {
          await save(result.cancelled ? 'cancelled' : 'failed', 'file');
        } else {
          await prefs.remove(issue.key);
        }
        return result;
      } catch (error) {
        final cancelled = cancelToken?.isCancelled == true ||
            (error is DioException && CancelToken.isCancel(error));
        final reason = error is DioException
            ? (error.response?.statusCode == null ? 'network' : 'server')
            : 'file';
        await save(cancelled ? 'cancelled' : 'failed', reason);
        rethrow;
      }
    } finally {
      _active.remove(issue.key);
    }
  }
}
