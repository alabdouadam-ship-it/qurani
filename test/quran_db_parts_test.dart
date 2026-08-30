// Verifies that the gzipped parts produced by `tool/pack_quran_db.dart`
// reassemble into a byte-identical copy of `assets/data/quran.db`.
//
// This is the highest-stakes check in the suite. QuranDatabaseService copies the
// database out of the bundle on first launch (and again after any schema bump,
// i.e. for the entire installed base on that release). If the parts are stale,
// truncated, or fed to the decoder out of order, the app does not merely
// misbehave — it fails to open its database at all.
//
// The test mirrors the runtime path exactly: stream the parts in order through
// `gzip.decoder` into a file, then compare against the source. The only piece it
// cannot exercise is `rootBundle` itself, which needs a real asset bundle; the
// files are read straight from disk instead.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sourcePath = 'assets/data/quran.db';
const String _partsDir = 'assets/data/quran_db';

/// Mirrors `QuranDatabaseService._gzippedParts`.
Stream<List<int>> _partStream(int partCount) async* {
  for (var i = 0; i < partCount; i++) {
    final name = 'part-${i.toString().padLeft(3, '0')}.gz';
    yield await File('$_partsDir/$name').readAsBytes();
  }
}

/// Byte-for-byte comparison in 1 MB blocks. Exact, and never holds more than
/// two blocks in memory — the point of this whole change is not to allocate
/// 104 MB at once, so the test that guards it should not either.
Future<bool> _filesIdentical(File a, File b) async {
  if (a.lengthSync() != b.lengthSync()) return false;
  final ra = await a.open();
  final rb = await b.open();
  try {
    const blockSize = 1 << 20;
    while (true) {
      final x = await ra.read(blockSize);
      final y = await rb.read(blockSize);
      if (x.length != y.length) return false;
      if (x.isEmpty) return true;
      for (var i = 0; i < x.length; i++) {
        if (x[i] != y[i]) return false;
      }
    }
  } finally {
    await ra.close();
    await rb.close();
  }
}

void main() {
  late Map<String, dynamic> manifest;

  setUpAll(() {
    manifest = json.decode(File('$_partsDir/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('manifest describes the parts that are actually present', () {
    final declared = (manifest['parts'] as num).toInt();
    expect(declared, greaterThan(0));

    final onDisk = Directory(_partsDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.gz'))
        .length;
    expect(onDisk, declared,
        reason: 'part count on disk must match the manifest — a leftover part '
            'from a longer previous run would corrupt the copy');

    for (var i = 0; i < declared; i++) {
      final name = 'part-${i.toString().padLeft(3, '0')}.gz';
      expect(File('$_partsDir/$name').existsSync(), isTrue,
          reason: '$name is missing, so the gzip stream has a hole');
    }
  });

  test('declared rawBytes matches the source database', () {
    expect(
      File(_sourcePath).lengthSync(),
      (manifest['rawBytes'] as num).toInt(),
      reason: 'manifest is stale — re-run tool/pack_quran_db.dart',
    );
  });

  test('every part is under the declared part size', () {
    final limit = (manifest['partSizeBytes'] as num).toInt();
    final declared = (manifest['parts'] as num).toInt();
    for (var i = 0; i < declared; i++) {
      final name = 'part-${i.toString().padLeft(3, '0')}.gz';
      expect(File('$_partsDir/$name').lengthSync(), lessThanOrEqualTo(limit),
          reason: '$name exceeds the part size, defeating the point of '
              'splitting (peak heap is one part)');
    }
  });

  test('parts reassemble byte-identically to the source database', () async {
    final declared = (manifest['parts'] as num).toInt();
    final expectedBytes = (manifest['rawBytes'] as num).toInt();

    final tempDir = await Directory.systemTemp.createTemp('quran_db_parts_');
    final rebuilt = File('${tempDir.path}/rebuilt.db');
    try {
      // Exactly what QuranDatabaseService._copyDatabaseFromAssets does.
      final sink = rebuilt.openWrite();
      await _partStream(declared).transform(gzip.decoder).pipe(sink);

      expect(rebuilt.lengthSync(), expectedBytes,
          reason: 'reassembled length must equal the source length');

      expect(await _filesIdentical(rebuilt, File(_sourcePath)), isTrue,
          reason: 'reassembled database must be byte-identical to '
              '$_sourcePath — anything else means the app ships a corrupt DB');
    } finally {
      await tempDir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the unsplit database is NOT declared as a shipped asset', () {
    // Shipping both forms would double the download. The raw file stays in the
    // repo only as the packer's input.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assetLines = pubspec
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('- assets/'))
        .toList();

    expect(assetLines, isNot(contains('- assets/data/quran.db')));
    expect(assetLines, contains('- assets/data/quran_db/'));
    // A bare `- assets/data/` entry would sweep quran.db back in implicitly.
    expect(assetLines, isNot(contains('- assets/data/')),
        reason: 'a bare assets/data/ entry implicitly ships quran.db');
  });
}
