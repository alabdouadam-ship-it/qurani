import 'surah.dart';

typedef VerseRef = ({int surah, int verse});
typedef RepetitionPassage = ({VerseRef start, VerseRef end});

const openingPassage = (
  start: (surah: 1, verse: 1),
  end: (surah: 1, verse: 7),
);

extension PassageBounds on RepetitionPassage {
  bool contains(int surah, int verse) =>
      surah >= start.surah &&
      surah <= end.surah &&
      (surah != start.surah || verse >= start.verse) &&
      (surah != end.surah || verse <= end.verse);

  bool isValid(List<Surah> surahs) {
    bool exists(VerseRef ref) => surahs.any((s) =>
        s.order == ref.surah && ref.verse >= 1 && ref.verse <= s.totalVerses);
    return exists(start) && exists(end) && contains(start.surah, start.verse);
  }

  RepetitionPassage withStart(VerseRef ref) {
    final moveEnd = end.surah < ref.surah ||
        (end.surah == ref.surah && end.verse < ref.verse);
    return (start: ref, end: moveEnd ? ref : end);
  }
}

typedef RepetitionPosition = ({int verseIndex, int repeat, int pass});

extension RepetitionProgress on RepetitionPosition {
  RepetitionPosition? next(int verses, int repeats, int passes) {
    if (repeat + 1 < repeats) {
      return (verseIndex: verseIndex, repeat: repeat + 1, pass: pass);
    }
    if (verseIndex + 1 < verses) {
      return (verseIndex: verseIndex + 1, repeat: 0, pass: pass);
    }
    if (pass + 1 < passes) return (verseIndex: 0, repeat: 0, pass: pass + 1);
    return null;
  }
}
