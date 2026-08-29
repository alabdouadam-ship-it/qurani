import 'quran_edition.dart';
import 'web_edition_json.dart';

export 'quran_edition.dart';

/// Web implementation of the Quran repository.
///
/// Reads **per-juz shards** served from GitHub via jsDelivr (see
/// `web_edition_json.dart` for why that host, and `tool/shard_editions.dart`
/// for the generator). The io variant is the parallel implementation over the
/// bundled `quran.db`; the public API of the two must stay identical.
///
/// ## Why this is sharded and indexed
///
/// This class used to fetch an entire edition JSON, `json.decode` it whole,
/// and keep the raw decoded tree in a never-evicted cache. Two consequences:
///
///  * `ar.miqbas.json` is 28.35 MB. Dart web has no isolates, so that
///    `json.decode` blocked the UI thread outright — `compute()` degrades to a
///    same-thread call on web. The largest shard is now 1,570 KB.
///  * Every method then *scanned* that tree. `loadPage` walked all 114 surahs
///    and all 6236 ayahs to find the ~10 on one page, rebuilding 114 throwaway
///    `SurahMeta` objects each time; `loadAyahTafsir` walked the whole corpus
///    per call. Each shard is now indexed once at parse time into
///    page/ayah/surah maps, so every lookup is O(1).
///
/// Two smaller wins fall out of the shared `index.json` (~24 KB): the surah
/// list no longer requires fetching a 2.93 MB edition, and `simple` and `irab`
/// share cache entries because they resolve to the same `webDataDir`.
class QuranRepository {
  QuranRepository._();

  static final QuranRepository instance = QuranRepository._();

  Future<_EditionIndex>? _indexFuture;

  /// Keyed `<webDataDir>::<juz>` rather than by edition id, so editions that
  /// share a data directory (`simple` and `irab` both use `quran-simple`)
  /// share the fetch and the parsed index.
  final Map<String, Future<_Shard>> _shardCache = {};

  /// Keyed `<webDataDir>::<page>`. Cheap now that it is assembled from indexed
  /// shards rather than a full-corpus scan, but still worth keeping so
  /// re-visiting a page does no map lookups at all.
  final Map<String, Future<PageData>> _pageCache = {};

  Future<_EditionIndex> _index() =>
      _indexFuture ??= loadEditionIndex().then(_EditionIndex.fromJson);

  String _dirOf(QuranEdition edition) {
    final dir = edition.webDataDir;
    if (dir == null || dir.isEmpty) {
      throw Exception('Edition "${edition.id}" has no webDataDir, so it cannot '
          'be read on web.');
    }
    return dir;
  }

  Future<_Shard> _shard(QuranEdition edition, int juz) {
    final dir = _dirOf(edition);
    return _shardCache.putIfAbsent(
      '$dir::$juz',
      () => loadEditionShard(dir, juz).then(_Shard.fromJson),
    );
  }

  /// Resolves one ayah by its global number (1..6236) in [edition].
  Future<AyahData?> _ayahByNumber(int ayahNumber, QuranEdition edition) async {
    final index = await _index();
    final juz = index.juzForAyah(ayahNumber);
    if (juz == null) return null;
    final shard = await _shard(edition, juz);
    return shard.byAyah[ayahNumber];
  }

  Future<PageData> loadPage(int pageNumber, QuranEdition edition) async {
    final key = '${_dirOf(edition)}::$pageNumber';

    return await _pageCache.putIfAbsent(key, () async {
      final index = await _index();
      // Usually one juz. Exactly four mushaf pages (62, 121, 201, 502) straddle
      // a juz boundary and return two, which is why `index.json`'s per-juz page
      // ranges deliberately overlap — no special-casing needed here.
      final juzNumbers = index.juzForPage(pageNumber);
      final shards = await Future.wait(
        juzNumbers.map((juz) => _shard(edition, juz)),
      );

      // `Future.wait` preserves order and `juzForPage` returns ascending juz,
      // so concatenating yields ayahs in ascending global order.
      final ayahs = <AyahData>[];
      for (final shard in shards) {
        final onPage = shard.byPage[pageNumber];
        if (onPage != null) ayahs.addAll(onPage);
      }

      return PageData(
        number: pageNumber,
        ayahs: ayahs,
        surahOccurrences: surahOccurrencesFor(ayahs),
      );
    });
  }

  Future<String?> loadAyahText({
    required int ayahNumber,
    required int pageNumber,
    required QuranEdition edition,
  }) async {
    // `pageNumber` is accepted for API parity with the io variant, which uses
    // it to scope a page query. Here the global ayah number is enough: the
    // index maps it straight to a juz, and the shard maps it straight to text.
    final ayah = await _ayahByNumber(ayahNumber, edition);
    return ayah?.text;
  }

  Future<String?> loadAyahTranslation({
    required int ayahNumber,
    required QuranEdition edition,
    int? pageNumber,
  }) async {
    // The io variant falls back to `loadAyahText` when its column lookup comes
    // back empty. That fallback is redundant here: both paths read the same
    // shard entry, so there is nothing a second lookup could recover.
    final ayah = await _ayahByNumber(ayahNumber, edition);
    final text = ayah?.text;
    return (text == null || text.isEmpty) ? null : text;
  }

  Future<String?> loadAyahTafsir(int ayahNumber,
      {QuranEdition? edition}) async {
    try {
      final ayah = await _ayahByNumber(
        ayahNumber,
        edition ?? QuranEditions.tafsirMuyassar,
      );
      final text = ayah?.text;
      return (text == null || text.isEmpty) ? null : text;
    } catch (_) {
      // A tafsir shard failing to load must not take down the reader.
      return null;
    }
  }

  Future<AyahData?> lookupAyahByNumber(
    int ayahNumber, {
    QuranEdition edition = QuranEditions.simple,
  }) =>
      _ayahByNumber(ayahNumber, edition);

  /// Served entirely from the shared index — no edition data is fetched.
  /// Previously this pulled the whole 2.93 MB `quran-simple.json` just for
  /// 114 names.
  Future<List<SurahMeta>> loadAllSurahs() async {
    final index = await _index();
    return index.surahs;
  }

  Future<List<AyahBrief>> loadSurahAyahs(
      int surahNumber, QuranEdition edition) async {
    final index = await _index();
    // Long surahs span several juz (Al-Baqarah covers 1-3), so fetch every
    // shard the surah touches.
    final juzNumbers = index.juzForSurah(surahNumber);
    if (juzNumbers.isEmpty) return const <AyahBrief>[];

    final shards = await Future.wait(
      juzNumbers.map((juz) => _shard(edition, juz)),
    );

    final out = <AyahBrief>[];
    for (final shard in shards) {
      final inSurah = shard.bySurah[surahNumber];
      if (inSurah == null) continue;
      for (final ayah in inSurah) {
        out.add(AyahBrief(
          number: ayah.number,
          numberInSurah: ayah.numberInSurah,
          text: ayah.text,
          surah: ayah.surah,
        ));
      }
    }
    return out;
  }
}

/// Groups a page's ayahs into runs of consecutive same-surah ayahs.
///
/// Shared by [QuranRepository.loadPage] and [PageData.fromJson] so the two can
/// never disagree about how a page that spans a surah boundary is described.
List<SurahOccurrence> surahOccurrencesFor(List<AyahData> ayahs) {
  final occurrences = <SurahOccurrence>[];
  SurahMeta? current;
  int? startIndex;

  for (var i = 0; i < ayahs.length; i++) {
    final ayah = ayahs[i];
    if (current == null || ayah.surah.number != current.number) {
      if (current != null && startIndex != null) {
        occurrences.add(SurahOccurrence(
          surah: current,
          startIndex: startIndex,
          ayahCount: i - startIndex,
        ));
      }
      current = ayah.surah;
      startIndex = i;
    }
  }
  if (current != null && startIndex != null) {
    occurrences.add(SurahOccurrence(
      surah: current,
      startIndex: startIndex,
      ayahCount: ayahs.length - startIndex,
    ));
  }
  return occurrences;
}

/// One parsed juz shard, indexed at parse time.
///
/// Building all three maps in a single pass is the whole point: it replaces the
/// repeated full-corpus scans the previous implementation did on every page
/// turn and every tafsir lookup.
class _Shard {
  _Shard({
    required this.byPage,
    required this.byAyah,
    required this.bySurah,
  });

  final Map<int, List<AyahData>> byPage;
  final Map<int, AyahData> byAyah;
  final Map<int, List<AyahData>> bySurah;

  factory _Shard.fromJson(Map<String, dynamic> json) {
    final byPage = <int, List<AyahData>>{};
    final byAyah = <int, AyahData>{};
    final bySurah = <int, List<AyahData>>{};

    final surahs = (json['surahs'] as List<dynamic>?) ?? const [];
    for (final entry in surahs) {
      final surahJson = entry as Map<String, dynamic>;
      // One SurahMeta per surah per shard, reused by every ayah in it.
      final meta = SurahMeta(
        number: (surahJson['number'] as num).toInt(),
        name: surahJson['name'] as String? ?? '',
        englishName: surahJson['englishName'] as String? ?? '',
        englishNameTranslation:
            surahJson['englishNameTranslation'] as String? ?? '',
        revelationType: surahJson['revelationType'] as String? ?? '',
      );

      final ayahs = (surahJson['ayahs'] as List<dynamic>?) ?? const [];
      for (final ayahEntry in ayahs) {
        final ayahJson = ayahEntry as Map<String, dynamic>;
        final ayah = AyahData(
          number: (ayahJson['number'] as num).toInt(),
          text: ayahJson['text'] as String? ?? '',
          surah: meta,
          numberInSurah: (ayahJson['numberInSurah'] as num?)?.toInt() ?? 0,
          juz: (ayahJson['juz'] as num?)?.toInt() ?? 1,
          page: (ayahJson['page'] as num?)?.toInt() ?? 1,
        );

        byAyah[ayah.number] = ayah;
        (byPage[ayah.page] ??= <AyahData>[]).add(ayah);
        (bySurah[meta.number] ??= <AyahData>[]).add(ayah);
      }
    }

    return _Shard(byPage: byPage, byAyah: byAyah, bySurah: bySurah);
  }
}

/// Parsed `index.json`: juz boundaries plus full surah metadata.
class _EditionIndex {
  _EditionIndex({
    required this.surahs,
    required this.totalPages,
    required List<_JuzRange> juz,
    required Map<int, List<int>> surahJuz,
  })  : _juz = juz,
        _surahJuz = surahJuz;

  final List<SurahMeta> surahs;
  final int totalPages;
  final List<_JuzRange> _juz;
  final Map<int, List<int>> _surahJuz;

  factory _EditionIndex.fromJson(Map<String, dynamic> json) {
    final juz = <_JuzRange>[];
    for (final entry in (json['juz'] as List<dynamic>?) ?? const []) {
      final m = entry as Map<String, dynamic>;
      juz.add(_JuzRange(
        n: (m['n'] as num).toInt(),
        startAyah: (m['startAyah'] as num).toInt(),
        endAyah: (m['endAyah'] as num).toInt(),
        firstPage: (m['firstPage'] as num).toInt(),
        lastPage: (m['lastPage'] as num).toInt(),
      ));
    }
    juz.sort((a, b) => a.n.compareTo(b.n));

    final surahs = <SurahMeta>[];
    final surahJuz = <int, List<int>>{};
    for (final entry in (json['surahs'] as List<dynamic>?) ?? const []) {
      final m = entry as Map<String, dynamic>;
      final number = (m['number'] as num).toInt();
      surahs.add(SurahMeta(
        number: number,
        name: m['name'] as String? ?? '',
        englishName: m['englishName'] as String? ?? '',
        englishNameTranslation: m['englishNameTranslation'] as String? ?? '',
        revelationType: m['revelationType'] as String? ?? '',
      ));
      surahJuz[number] = ((m['juz'] as List<dynamic>?) ?? const [])
          .map((j) => (j as num).toInt())
          .toList()
        ..sort();
    }
    surahs.sort((a, b) => a.number.compareTo(b.number));

    return _EditionIndex(
      surahs: surahs,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 604,
      juz: juz,
      surahJuz: surahJuz,
    );
  }

  /// Every juz containing [page]. Returns two entries for the four straddle
  /// pages, one otherwise. Only 30 ranges, so a linear scan is free.
  List<int> juzForPage(int page) {
    final hits = <int>[];
    for (final range in _juz) {
      if (page >= range.firstPage && page <= range.lastPage) hits.add(range.n);
    }
    return hits;
  }

  /// The juz containing global ayah number [ayahNumber], or null if out of
  /// range. Juz ayah ranges do not overlap, so there is exactly one.
  int? juzForAyah(int ayahNumber) {
    for (final range in _juz) {
      if (ayahNumber >= range.startAyah && ayahNumber <= range.endAyah) {
        return range.n;
      }
    }
    return null;
  }

  List<int> juzForSurah(int surahNumber) =>
      _surahJuz[surahNumber] ?? const <int>[];
}

class _JuzRange {
  const _JuzRange({
    required this.n,
    required this.startAyah,
    required this.endAyah,
    required this.firstPage,
    required this.lastPage,
  });

  final int n;
  final int startAyah;
  final int endAyah;
  final int firstPage;
  final int lastPage;
}

class PageData {
  PageData({
    required this.number,
    required this.ayahs,
    required this.surahOccurrences,
  });

  final int number;
  final List<AyahData> ayahs;
  final List<SurahOccurrence> surahOccurrences;

  int get juz => ayahs.isNotEmpty ? ayahs.first.juz : 1;

  List<SurahMeta> get surahsOnPage =>
      surahOccurrences.map((o) => o.surah).toList();

  factory PageData.fromJson(Map<String, dynamic> json, QuranEdition edition) {
    final number = json['number'] as int;
    final ayahList = (json['ayahs'] as List<dynamic>)
        .map((entry) =>
            AyahData.fromJson(entry as Map<String, dynamic>, edition))
        .toList();
    return PageData(
      number: number,
      ayahs: ayahList,
      surahOccurrences: surahOccurrencesFor(ayahList),
    );
  }
}

class AyahData {
  AyahData({
    required this.number,
    required this.text,
    required this.surah,
    required this.numberInSurah,
    required this.juz,
    required this.page,
  });

  final int number;
  final String text;
  final SurahMeta surah;
  final int numberInSurah;
  final int juz;
  final int page;

  bool get isSurahBeginning => numberInSurah == 1;

  factory AyahData.fromJson(Map<String, dynamic> json, QuranEdition edition) {
    final surahMap = json['surah'] as Map<String, dynamic>? ?? {};
    return AyahData(
      number: json['number'] as int,
      text: json['text'] as String? ?? '',
      surah: SurahMeta.fromJson(surahMap),
      numberInSurah: json['numberInSurah'] as int? ?? 0,
      juz: json['juz'] as int? ?? 1,
      page: json['page'] as int? ?? 1,
    );
  }
}

class SurahMeta {
  const SurahMeta({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.revelationType,
  });

  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final String revelationType; // 'Meccan' | 'Medinan' | ''

  factory SurahMeta.fromJson(Map<String, dynamic> json) {
    return SurahMeta(
      number: json['number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
      revelationType: json['revelationType'] as String? ?? '',
    );
  }
}

class SurahOccurrence {
  const SurahOccurrence({
    required this.surah,
    required this.startIndex,
    required this.ayahCount,
  });

  final SurahMeta surah;
  final int startIndex;
  final int ayahCount;
}

class AyahBrief {
  AyahBrief({
    required this.number,
    required this.numberInSurah,
    required this.text,
    required this.surah,
  });

  final int number;
  final int numberInSurah;
  final String text;
  final SurahMeta surah;
}
