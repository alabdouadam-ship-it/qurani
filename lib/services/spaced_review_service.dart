import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/repetition_passage.dart';
import '../models/quran_bounds.dart';

enum ReviewRating { again, hard, good, easy }

class ReviewPassage {
  final RepetitionPassage passage;
  final DateTime due;
  final DateTime? lastReviewed;
  final int intervalDays;
  final int reviews;
  const ReviewPassage(
      {required this.passage,
      required this.due,
      this.lastReviewed,
      this.intervalDays = 0,
      this.reviews = 0});
  String get id =>
      '${passage.start.surah}:${passage.start.verse}-${passage.end.surah}:${passage.end.verse}';
  bool isDue(DateTime now) =>
      !due.isAfter(DateTime(now.year, now.month, now.day));
  ReviewPassage rate(ReviewRating rating, DateTime now) {
    final next = switch (rating) {
      ReviewRating.again => 1,
      ReviewRating.hard => intervalDays == 0 ? 1 : (intervalDays * 1.2).ceil(),
      ReviewRating.good => intervalDays == 0 ? 3 : (intervalDays * 2).ceil(),
      ReviewRating.easy => intervalDays == 0 ? 7 : (intervalDays * 3).ceil(),
    };
    final days = next.clamp(1, 365);
    return ReviewPassage(
        passage: passage,
        due: DateTime(now.year, now.month, now.day + days),
        lastReviewed: DateTime(now.year, now.month, now.day),
        intervalDays: days,
        reviews: reviews + 1);
  }

  Map<String, Object?> toJson() => {
        'startSurah': passage.start.surah,
        'startVerse': passage.start.verse,
        'endSurah': passage.end.surah,
        'endVerse': passage.end.verse,
        'due': _date(due),
        'lastReviewed': lastReviewed == null ? null : _date(lastReviewed!),
        'intervalDays': intervalDays,
        'reviews': reviews,
      };
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime parseDate(Object? value) {
    if (value is! String) throw const FormatException('Invalid review date');
    final d = DateTime.tryParse(value);
    if (d == null || _date(d) != value) {
      throw const FormatException('Invalid review date');
    }
    return DateTime(d.year, d.month, d.day);
  }

  factory ReviewPassage.fromJson(Map<String, dynamic> json) {
    final p = (
      start: (
        surah: json['startSurah'] as int,
        verse: json['startVerse'] as int
      ),
      end: (surah: json['endSurah'] as int, verse: json['endVerse'] as int)
    );
    final days = json['intervalDays'] as int;
    final reviews = json['reviews'] as int;
    if (!validPassage(p) || days < 0 || days > 365 || reviews < 0) {
      throw const FormatException('Invalid review passage');
    }
    return ReviewPassage(
        passage: p,
        due: parseDate(json['due']),
        lastReviewed: json['lastReviewed'] == null
            ? null
            : parseDate(json['lastReviewed']),
        intervalDays: days,
        reviews: reviews);
  }
}

class SpacedReviewService {
  static const storageKey = 'spaced_reviews_v1';
  static Future<void>? _writes;
  static Future<void> _mutate(Future<void> Function() action) {
    final previous = _writes;
    final result = previous == null
        ? Future<void>.sync(action)
        : previous.then((_) => action());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _writes = tail;
    tail.then((_) {
      if (identical(_writes, tail)) _writes = null;
    });
    return result;
  }

  static List<ReviewPassage> decode(String raw) {
    final list = (jsonDecode(raw) as List)
        .map((e) => ReviewPassage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (list.map((e) => e.id).toSet().length != list.length) {
      throw const FormatException('Duplicate passage');
    }
    return list;
  }

  static Future<List<ReviewPassage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final items = decode(prefs.getString(storageKey) ?? '[]');
    items.sort((a, b) => a.due.compareTo(b.due));
    return items;
  }

  static Future<void> _save(List<ReviewPassage> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
        storageKey, jsonEncode(items.map((e) => e.toJson()).toList()))) {
      throw StateError('Cannot save reviews');
    }
  }

  static Future<void> add(RepetitionPassage passage, {DateTime? now}) =>
      _mutate(() => _add(passage, now: now));
  static Future<void> _add(RepetitionPassage passage, {DateTime? now}) async {
    if (!validPassage(passage)) throw const FormatException('Invalid passage');
    final date = now ?? DateTime.now();
    final item = ReviewPassage(
        passage: passage, due: DateTime(date.year, date.month, date.day));
    final items = await load();
    if (items.any((e) => e.id == item.id)) {
      return; // Never reset existing progress.
    }
    await _save([...items, item]);
  }

  static Future<void> rate(String id, ReviewRating rating, {DateTime? now}) =>
      _mutate(() => _rate(id, rating, now: now));
  static Future<void> _rate(String id, ReviewRating rating,
      {DateTime? now}) async {
    final items = await load();
    final index = items.indexWhere((e) => e.id == id);
    if (index < 0) throw StateError('Unknown passage');
    items[index] = items[index].rate(rating, now ?? DateTime.now());
    await _save(items);
  }

  static Future<void> remove(String id) => _mutate(
      () async => _save((await load()).where((e) => e.id != id).toList()));
}
