// Per-juz sharding generator for the WEB-ONLY Quran edition JSONs.
//
// Usage (from the project root):
//   dart run tool/shard_editions.dart
//
// Re-runnable and idempotent: each edition's shard directory is deleted and
// rewritten, and `index.json` is regenerated from scratch.
//
// ── Why this exists ────────────────────────────────────────────────────────
// The 14 monoliths in `data/editions/*.json` are the editable source of
// truth, but they are unusable as a delivery format on web for three reasons:
//
//  1. jsDelivr — the CDN we serve these from, and which the hadith loader
//     already uses — enforces a HARD 20 MB per-file limit. Measured against
//     our own repo: `ar.waseet.json` (18.44 MB) returns 200 while
//     `ar.qurtubi.json` (20.48 MB) and `ar.miqbas.json` (28.35 MB) return 403
//     with the body "File size exceeded the configured limit of 20 MB." Two of
//     our fourteen editions are literally unservable whole.
//  2. Dart web has no isolates. `compute()` degrades to a same-thread call
//     (see packages/flutter/lib/src/foundation/_isolates_web.dart), so a
//     28 MB `json.decode` blocks the UI thread with no escape hatch. The only
//     fix is to parse less.
//  3. Rendering one page needs ~10 of 6236 ayahs — about 0.17% of the file.
//
// Sharding by juz is the right axis: 604 pages / 30 juz is ~20 pages per
// shard, juz are roughly equal by mushaf length, and the app already has a
// juz picker so it matches how people navigate.
//
// ── Output layout ──────────────────────────────────────────────────────────
//   data/editions/index.json          <- shared, tiny: juz + surah metadata
//   data/editions/<stem>/juz-01.json  <- one shard per juz, per edition
//   ...                    /juz-30.json
//
// The monoliths are intentionally LEFT IN PLACE. They remain the generator
// source, and `quran_search_service_web` still loads whole editions because
// search genuinely needs the full corpus — its four corpora (clean, simple,
// english, french) are all a few MB and comfortably under the 20 MB ceiling.
//
// ── Size wins beyond the juz split ─────────────────────────────────────────
// Shards are written with COMPACT json (the monoliths are pretty-printed with
// 2-space indent, which is a large fraction of their bytes), and the four
// per-ayah fields nothing in the app reads are dropped: `manzil`, `ruku`,
// `hizbQuarter`, `sajda`. Verified against quran_repository_web.dart — AyahData
// only carries number/text/surah/numberInSurah/juz/page, and SurahMeta only
// number/name/englishName/englishNameTranslation/revelationType.
//
// NOTE: This is a DEV tool. It is never shipped in the app.

import 'dart:convert';
import 'dart:io';

const String _editionsDir = 'data/editions';
const String _indexFile = 'index.json';

/// Surah names for `index.json` are taken from this edition, so the shared
/// index carries one canonical copy instead of 14 near-identical ones.
const String _referenceEdition = 'quran-simple.json';

const int _expectedAyahCount = 6236;
const int _expectedPageCount = 604;
const int _juzCount = 30;

/// jsDelivr's hard per-file ceiling. We assert every shard lands under it.
const int _jsDelivrLimitBytes = 20 * 1024 * 1024;

void main(List<String> args) {
  final dir = Directory(_editionsDir);
  if (!dir.existsSync()) {
    stderr.writeln('ERROR: $_editionsDir not found. Run from the project root.');
    exit(1);
  }

  final monoliths = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where((f) => _stem(f) != 'index')
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (monoliths.isEmpty) {
    stderr.writeln('ERROR: no edition JSONs found in $_editionsDir.');
    exit(1);
  }

  stdout.writeln('Sharding ${monoliths.length} editions by juz...\n');

  _SurahIndexData? indexData;
  var totalOut = 0;
  var largestShard = 0;
  String largestShardName = '';
  final editionMeta = <String, Map<String, dynamic>>{};

  for (final file in monoliths) {
    final stem = _stem(file);
    final raw = file.readAsStringSync();
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final surahs = (data['surahs'] as List<dynamic>).cast<Map<String, dynamic>>();
    final edition = (data['edition'] as Map<String, dynamic>?) ?? const {};

    editionMeta[stem] = {
      'identifier': edition['identifier'] ?? stem,
      'language': edition['language'],
      'name': edition['name'],
      'englishName': edition['englishName'],
    };

    // Bucket every surah's ayahs by the juz each ayah belongs to. A surah can
    // appear in several buckets (Al-Baqarah spans juz 1-3), and a mushaf page
    // can straddle two juz (pages 62, 121, 201 and 502) — the loader handles
    // that by fetching both shards, which is why sharding strictly by
    // `ayah.juz` is safe here.
    final byJuz = <int, List<Map<String, dynamic>>>{};

    for (final surah in surahs) {
      final surahNumber = surah['number'] as int;
      final ayahs = (surah['ayahs'] as List<dynamic>).cast<Map<String, dynamic>>();

      final perJuz = <int, List<Map<String, dynamic>>>{};
      for (final ayah in ayahs) {
        final juz = (ayah['juz'] as num?)?.toInt() ?? 1;
        perJuz.putIfAbsent(juz, () => []).add({
          'number': ayah['number'],
          'numberInSurah': ayah['numberInSurah'],
          'juz': juz,
          'page': (ayah['page'] as num?)?.toInt() ?? 1,
          'text': ayah['text'] ?? '',
        });
      }

      for (final entry in perJuz.entries) {
        byJuz.putIfAbsent(entry.key, () => []).add({
          'number': surahNumber,
          'name': surah['name'] ?? '',
          'englishName': surah['englishName'] ?? '',
          'englishNameTranslation': surah['englishNameTranslation'] ?? '',
          'revelationType': surah['revelationType'] ?? '',
          'ayahs': entry.value,
        });
      }
    }

    // The reference edition also supplies the shared index.
    if (file.uri.pathSegments.last == _referenceEdition) {
      indexData = _buildIndexData(surahs);
    }

    // Rewrite the shard directory from scratch so a stale juz file from an
    // earlier run can never survive.
    final outDir = Directory('$_editionsDir/$stem');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);

    var editionOut = 0;
    var editionMax = 0;
    var editionMin = 1 << 62;
    var ayahsWritten = 0;

    for (var juz = 1; juz <= _juzCount; juz++) {
      final surahsInJuz = byJuz[juz] ?? const <Map<String, dynamic>>[];
      // Keep surahs in ascending order so concatenating shards yields ayahs in
      // ascending global order without a re-sort in the client.
      surahsInJuz.sort(
          (a, b) => (a['number'] as int).compareTo(b['number'] as int));
      for (final s in surahsInJuz) {
        ayahsWritten += (s['ayahs'] as List).length;
      }

      final shard = {
        'edition': editionMeta[stem],
        'juz': juz,
        'surahs': surahsInJuz,
      };

      final outFile = File('${outDir.path}/juz-${_pad2(juz)}.json');
      // Compact, not pretty-printed: indentation is dead weight over the wire.
      outFile.writeAsStringSync(json.encode(shard));
      final len = outFile.lengthSync();
      editionOut += len;
      if (len > editionMax) editionMax = len;
      if (len < editionMin) editionMin = len;

      if (len > largestShard) {
        largestShard = len;
        largestShardName = '$stem/juz-${_pad2(juz)}.json';
      }
      if (len > _jsDelivrLimitBytes) {
        stderr.writeln(
            'ERROR: $stem/juz-${_pad2(juz)}.json is ${_mb(len)} MB, over '
            "jsDelivr's 20 MB limit.");
        exit(1);
      }
    }

    if (ayahsWritten != _expectedAyahCount) {
      stderr.writeln(
          'ERROR: $stem wrote $ayahsWritten ayahs, expected $_expectedAyahCount.');
      exit(1);
    }

    totalOut += editionOut;
    // NOTE: report the on-disk BYTE length, not `raw.length` (which is the
    // UTF-16 code-unit count and badly understates multi-byte Arabic).
    stdout.writeln('  ${stem.padRight(20)} '
        'src ${_mb(file.lengthSync()).padLeft(6)} MB  ->  '
        '30 shards, ${_mb(editionOut).padLeft(6)} MB total, '
        'min ${_kb(editionMin)} KB / max ${_kb(editionMax)} KB');
  }

  if (indexData == null) {
    stderr.writeln('ERROR: reference edition $_referenceEdition not found; '
        'cannot build index.json.');
    exit(1);
  }

  final index = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'juzCount': _juzCount,
    'totalAyahs': _expectedAyahCount,
    'totalPages': indexData.totalPages,
    // Per-juz boundaries. `firstPage`/`lastPage` ranges deliberately OVERLAP on
    // the four straddle pages, so "which juz holds page P" naturally returns
    // two entries there and the loader fetches both shards.
    'juz': indexData.juz,
    // Full surah metadata + which juz each surah touches. This lets the app
    // build the surah list and resolve loadSurahAyahs without fetching any
    // edition file at all (it used to pull the whole 2.93 MB quran-simple).
    'surahs': indexData.surahs,
    'editions': editionMeta,
  };
  final indexOut = File('$_editionsDir/$_indexFile');
  indexOut.writeAsStringSync(json.encode(index));
  final indexLen = indexOut.lengthSync();

  stdout.writeln('\n  ${'index.json'.padRight(20)} ${_kb(indexLen)} KB');
  stdout.writeln('\nDone. ${monoliths.length} editions x $_juzCount shards, '
      '${_mb(totalOut)} MB total output.');
  stdout.writeln('Largest shard: $largestShardName at ${_kb(largestShard)} KB '
      '(jsDelivr limit is 20480 KB).');
}

class _SurahIndexData {
  _SurahIndexData({
    required this.juz,
    required this.surahs,
    required this.totalPages,
  });

  final List<Map<String, dynamic>> juz;
  final List<Map<String, dynamic>> surahs;
  final int totalPages;
}

_SurahIndexData _buildIndexData(List<Map<String, dynamic>> surahs) {
  final juzStartAyah = <int, int>{};
  final juzEndAyah = <int, int>{};
  final juzFirstPage = <int, int>{};
  final juzLastPage = <int, int>{};
  final surahJuz = <int, Set<int>>{};
  final surahMeta = <Map<String, dynamic>>[];
  var maxPage = 0;

  for (final surah in surahs) {
    final n = surah['number'] as int;
    final ayahs = (surah['ayahs'] as List<dynamic>).cast<Map<String, dynamic>>();

    for (final ayah in ayahs) {
      final global = (ayah['number'] as num).toInt();
      final juz = (ayah['juz'] as num?)?.toInt() ?? 1;
      final page = (ayah['page'] as num?)?.toInt() ?? 1;

      if (!juzStartAyah.containsKey(juz) || global < juzStartAyah[juz]!) {
        juzStartAyah[juz] = global;
      }
      if (!juzEndAyah.containsKey(juz) || global > juzEndAyah[juz]!) {
        juzEndAyah[juz] = global;
      }
      if (!juzFirstPage.containsKey(juz) || page < juzFirstPage[juz]!) {
        juzFirstPage[juz] = page;
      }
      if (!juzLastPage.containsKey(juz) || page > juzLastPage[juz]!) {
        juzLastPage[juz] = page;
      }
      surahJuz.putIfAbsent(n, () => <int>{}).add(juz);
      if (page > maxPage) maxPage = page;
    }

    surahMeta.add({
      'number': n,
      'name': surah['name'] ?? '',
      'englishName': surah['englishName'] ?? '',
      'englishNameTranslation': surah['englishNameTranslation'] ?? '',
      'revelationType': surah['revelationType'] ?? '',
      'totalVerses': ayahs.length,
      'juz': (surahJuz[n]!.toList()..sort()),
    });
  }

  if (maxPage != _expectedPageCount) {
    stderr.writeln(
        'WARNING: reference edition reports $maxPage pages, expected $_expectedPageCount.');
  }

  final juzList = <Map<String, dynamic>>[];
  for (var j = 1; j <= _juzCount; j++) {
    juzList.add({
      'n': j,
      'startAyah': juzStartAyah[j],
      'endAyah': juzEndAyah[j],
      'firstPage': juzFirstPage[j],
      'lastPage': juzLastPage[j],
    });
  }

  return _SurahIndexData(
    juz: juzList,
    surahs: surahMeta,
    totalPages: maxPage,
  );
}

String _stem(File f) {
  final name = f.uri.pathSegments.last;
  return name.endsWith('.json') ? name.substring(0, name.length - 5) : name;
}

String _pad2(int n) => n.toString().padLeft(2, '0');
String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);
String _kb(int bytes) => (bytes / 1024).toStringAsFixed(0);
