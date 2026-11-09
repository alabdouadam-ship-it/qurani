import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/l10n/app_localizations_en.dart';
import 'package:qurani/services/memorization_test_service.dart';
import 'package:qurani/services/quran_repository.dart';

void main() {
  const surah = SurahMeta(
      number: 2,
      name: 'البقرة',
      englishName: 'Al-Baqarah',
      englishNameTranslation: 'The Cow',
      revelationType: 'Medinan');
  PageData page(int pageNumber, {bool empty = false, int offset = 0}) =>
      PageData(
        number: pageNumber,
        surahOccurrences: [],
        ayahs: empty
            ? []
            : [
                AyahData(
                    number: pageNumber + offset,
                    text: 'text $pageNumber',
                    surah: surah,
                    numberInSurah: pageNumber,
                    juz: 1,
                    page: pageNumber)
              ],
      );
  for (final failure in ['exception', 'empty', 'gap']) {
    test('rejects juz with $failure instead of generating partial questions',
        () async {
      final service = MemorizationTestService(loadPage: (number) async {
        if (number == 3 && failure == 'exception') throw StateError('offline');
        return page(number,
            empty: number == 3 && failure == 'empty',
            offset: number >= 3 && failure == 'gap' ? 1 : 0);
      });
      await expectLater(
          service
              .generateQuestions(l10n: AppLocalizationsEn(), juzNumbers: [1]),
          throwsA(isA<IncompleteMemorizationData>()));
    });
  }
  test('complete contiguous juz still generates questions', () async {
    final service =
        MemorizationTestService(loadPage: (number) async => page(number));
    final questions = await service
        .generateQuestions(l10n: AppLocalizationsEn(), juzNumbers: [1]);
    expect(questions, isNotEmpty);
    expect(
        questions.every(
            (q) => q.correctIndex >= 0 && q.correctIndex < q.options.length),
        isTrue);
  });
}
