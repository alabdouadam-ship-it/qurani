// Packs the bundled `assets/data/quran.db` into gzipped, size-limited parts so
// the app can copy it out of the bundle WITHOUT loading all 104 MB into memory.
//
// Usage (from the project root):
//   dart run tool/pack_quran_db.dart
//
// Re-runnable and idempotent: the output directory is wiped and rewritten.
// Run this whenever `assets/data/quran.db` changes (i.e. after
// `tool/build_quran_db.dart`), and bump `QuranDatabaseService._schemaVersion`
// if the schema changed so existing installs re-copy.
//
// ── Why ────────────────────────────────────────────────────────────────────
// `QuranDatabaseService` used to do:
//
//     final bytes = await rootBundle.load('assets/data/quran.db');
//     await dbFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
//
// which is a single ~104 MB allocation on first launch (and again after any
// schema bump, i.e. for the whole installed base on that release). Dart has no
// streaming asset API, so the only way to lower the peak is to ship the data in
// pieces small enough to load one at a time.
//
// Gzipping first is free: measured 104.37 MB -> 29.50 MB, which is EXACTLY the
// size the Android App Bundle was already compressing the raw .db down to. So
// the download does not change; we simply move the decompression from the
// packaging layer into our own code, where we can stream it.
//
// Peak heap becomes one part (~8 MB) plus the gzip decoder's internal buffers,
// down from 104 MB. That matters beyond crash-avoidance on low-RAM devices:
// Google Play begins enforcing dynamic-memory thresholds (anonymous RSS + swap)
// in February 2027.
//
// NOTE: This is a DEV tool. It is never shipped in the app.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

const String _sourcePath = 'assets/data/quran.db';
const String _outputDir = 'assets/data/quran_db';
const String _manifestName = 'manifest.json';

/// Target size per part. Small enough that one part in memory is negligible,
/// large enough to keep the part count (and per-part asset overhead) low.
const int _partSizeBytes = 8 * 1024 * 1024;

/// Bumped only if the on-disk part layout changes in a way the reader must know
/// about. Independent of the DB's own schema version.
const int _packFormatVersion = 1;

Future<void> main(List<String> args) async {
  final source = File(_sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('ERROR: $_sourcePath not found. Run from the project root.');
    exit(1);
  }

  final rawBytes = source.lengthSync();
  stdout.writeln('Packing $_sourcePath (${_mb(rawBytes)} MB)...');

  // Rewrite from scratch so a stale part from an earlier, longer run cannot
  // survive and corrupt the reassembled database.
  final outDir = Directory(_outputDir);
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  outDir.createSync(recursive: true);

  // Compress the whole file as ONE gzip stream, then slice that stream into
  // fixed-size parts. The parts are byte ranges of a single stream, not
  // independent gzip members, so the reader must feed them to the decoder in
  // order — which it does.
  var partIndex = 0;
  var gzipBytes = 0;
  final buffer = BytesBuilder(copy: false);
  final partSizes = <int>[];

  Future<void> flushPart({required bool force}) async {
    while (buffer.length >= _partSizeBytes || (force && buffer.length > 0)) {
      final take = buffer.length >= _partSizeBytes ? _partSizeBytes : buffer.length;
      final all = buffer.takeBytes();
      final chunk = all.sublist(0, take);
      if (all.length > take) {
        buffer.add(all.sublist(take));
      }
      final file = File('$_outputDir/${_partName(partIndex)}');
      file.writeAsBytesSync(chunk, flush: true);
      partSizes.add(chunk.length);
      gzipBytes += chunk.length;
      partIndex++;
      if (force && buffer.length == 0) break;
    }
  }

  final encoded = source.openRead().transform(gzip.encoder);
  await for (final chunk in encoded) {
    buffer.add(chunk);
    await flushPart(force: false);
  }
  await flushPart(force: true);

  final manifest = <String, dynamic>{
    'packFormatVersion': _packFormatVersion,
    'parts': partIndex,
    // Used by the reader as a post-write sanity check: a short file means a
    // truncated copy, which must not be handed to sqlite.
    'rawBytes': rawBytes,
    'gzipBytes': gzipBytes,
    'partSizeBytes': _partSizeBytes,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
  };
  File('$_outputDir/$_manifestName')
      .writeAsStringSync(json.encode(manifest), flush: true);

  stdout.writeln('  parts      : $partIndex '
      '(${partSizes.map((s) => '${_mb(s)}MB').join(', ')})');
  stdout.writeln('  gzip total : ${_mb(gzipBytes)} MB '
      '(${(rawBytes / gzipBytes).toStringAsFixed(2)}x smaller than raw)');
  stdout.writeln('  peak heap when copying: ~${_mb(partSizes.isEmpty ? 0 : partSizes.first)} MB '
      '(was ${_mb(rawBytes)} MB)');

  // Verify the parts actually reassemble and decompress back to the original
  // byte length. Cheap insurance against shipping a corrupt database.
  stdout.writeln('Verifying round-trip...');
  final decoded = await _decodedLength(partIndex);
  if (decoded != rawBytes) {
    stderr.writeln('ERROR: round-trip produced $decoded bytes, expected $rawBytes.');
    exit(1);
  }
  stdout.writeln('  OK: decodes back to ${_mb(decoded)} MB exactly.');
  stdout.writeln('\nDone. Remember: bump QuranDatabaseService._schemaVersion if '
      'the schema changed, so installed apps re-copy.');
}

/// Streams the parts through the gzip decoder and returns the total output
/// length, mirroring exactly what the app does at runtime.
Future<int> _decodedLength(int partCount) async {
  var total = 0;
  await for (final chunk in _partStream(partCount).transform(gzip.decoder)) {
    total += chunk.length;
  }
  return total;
}

Stream<List<int>> _partStream(int partCount) async* {
  for (var i = 0; i < partCount; i++) {
    yield await File('$_outputDir/${_partName(i)}').readAsBytes();
  }
}

String _partName(int index) => 'part-${index.toString().padLeft(3, '0')}.gz';

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);
