import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/models/repetition_passage.dart';
import 'package:qurani/services/spaced_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('initial ratings schedule 1, 1, 3 and 7 calendar days', () {
    final now = DateTime(2026, 12, 31, 23, 59);
    final item = ReviewPassage(passage: openingPassage, due: now);
    for (final rating in ReviewRating.values) {
      final result = item.rate(rating, now);
      final days = [1, 1, 3, 7][rating.index];
      expect(result.due, DateTime(2027, 1, days));
      expect(result.reviews, 1);
      expect(result.lastReviewed, DateTime(2026, 12, 31));
    }
  });
  test(
      'again resets interval, growth caps at one year and due ignores time of day',
      () {
    final item = ReviewPassage(
        passage: openingPassage,
        due: DateTime(2026, 11, 4),
        intervalDays: 300,
        reviews: 5);
    expect(item.isDue(DateTime(2026, 11, 4, 1)), isTrue);
    expect(item.isDue(DateTime(2026, 11, 3, 23, 59)), isFalse);
    expect(
        item.rate(ReviewRating.easy, DateTime(2026, 11, 4)).intervalDays, 365);
    expect(
        item.rate(ReviewRating.again, DateTime(2026, 11, 4)).intervalDays, 1);
  });
  test('duplicate add retains learned progress and restart persistence',
      () async {
    await SpacedReviewService.add(openingPassage, now: DateTime(2026, 11, 4));
    final first = (await SpacedReviewService.load()).single;
    await SpacedReviewService.rate(first.id, ReviewRating.good,
        now: DateTime(2026, 11, 4));
    await SpacedReviewService.add(openingPassage, now: DateTime(2026, 11, 5));
    final saved = (await SpacedReviewService.load()).single;
    expect(saved.reviews, 1);
    expect(saved.due, DateTime(2026, 11, 7));
  });
  test(
      'concurrent additions are serialized and remove preserves other passages',
      () async {
    const other = (start: (surah: 2, verse: 280), end: (surah: 3, verse: 10));
    await Future.wait([
      SpacedReviewService.add(openingPassage),
      SpacedReviewService.add(other)
    ]);
    expect((await SpacedReviewService.load()).length, 2);
    await SpacedReviewService.remove('1:1-1:7');
    expect((await SpacedReviewService.load()).single.passage, other);
  });
  test('invalid verse boundaries and invalid persisted dates are rejected',
      () async {
    await expectLater(
        SpacedReviewService.add(
            (start: (surah: 1, verse: 1), end: (surah: 1, verse: 8))),
        throwsFormatException);
    final json =
        ReviewPassage(passage: openingPassage, due: DateTime(2026, 11, 4))
            .toJson();
    expect(() => ReviewPassage.fromJson({...json, 'due': '2026-02-30'}),
        throwsFormatException);
  });
}
