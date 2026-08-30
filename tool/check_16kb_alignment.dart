// Verifies that every 64-bit native library inside a built app bundle supports
// 16 KB memory pages, which Google Play requires for apps targeting Android 15
// (API 35) and above. From 1 February 2027 an update that fails this check can
// no longer be released.
//
// The requirement is that each PT_LOAD segment of every shared library shipped
// for a 64-bit ABI is aligned to at least 16384 bytes. Only 64-bit ABIs are in
// scope: no 16 KB page device runs 32-bit code, so a 4 KB aligned
// armeabi-v7a library is not a problem and is reported as informational.
//
// This reads the ELF program headers directly rather than shelling out to
// llvm-readelf, so it runs on any machine with a Dart SDK and does not need the
// Android NDK to be installed or on PATH.
//
// Usage:
//   dart run tool/check_16kb_alignment.dart [path/to/app-release.aab]
//
// Defaults to build/app/outputs/bundle/release/app-release.aab. Also accepts an
// .apk, since both are zips that hold their libraries under lib/<abi>/.
//
// Exits 0 when every 64-bit library passes, 1 on a violation or a bad argument.
//
// NOTE: This is a DEV tool. It is never shipped in the app.

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const String _defaultBundlePath =
    'build/app/outputs/bundle/release/app-release.aab';

/// Play's threshold. A segment aligned to more than this (Flutter's own
/// libraries use 65536) is also fine.
const int _requiredAlignment = 16 * 1024;

/// ABIs where 16 KB pages can actually occur.
const Set<String> _sixtyFourBitAbis = {'arm64-v8a', 'x86_64'};

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln('Usage: dart run tool/check_16kb_alignment.dart [bundle]');
    exit(1);
  }
  final path = args.isEmpty ? _defaultBundlePath : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Not found: $path');
    stderr.writeln('Build one first: flutter build appbundle --release');
    exit(1);
  }

  final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  final results = <_LibResult>[];

  for (final entry in archive.files) {
    if (!entry.isFile || !entry.name.endsWith('.so')) continue;
    final abi = _abiOf(entry.name);
    if (abi == null) continue;

    final bytes = entry.content as List<int>;
    final report = _minLoadAlignment(Uint8List.fromList(bytes));
    results.add(_LibResult(
      name: entry.name,
      abi: abi,
      sizeBytes: bytes.length,
      loadSegments: report?.loadSegments ?? 0,
      minAlignment: report?.minAlignment,
      is64Bit: report?.is64Bit ?? false,
    ));
  }

  if (results.isEmpty) {
    stderr.writeln('No native libraries found under lib/<abi>/ in $path.');
    stderr.writeln(
        'If this app genuinely ships no native code it already supports '
        '16 KB pages, but that is unexpected for a Flutter build.');
    exit(1);
  }

  results.sort((a, b) => a.name.compareTo(b.name));

  final failures = <_LibResult>[];
  stdout.writeln('16 KB page alignment — ${file.path}');
  stdout.writeln('required: PT_LOAD alignment >= $_requiredAlignment '
      'for ${_sixtyFourBitAbis.join(", ")}');
  stdout.writeln('');

  for (final r in results) {
    final inScope = _sixtyFourBitAbis.contains(r.abi);
    final align = r.minAlignment;
    final String verdict;
    if (align == null) {
      // Could not parse. Treat as a failure in scope so a malformed or
      // unexpected binary is never silently waved through.
      verdict = inScope ? 'UNREADABLE' : 'unreadable (32-bit, not in scope)';
      if (inScope) failures.add(r);
    } else if (align >= _requiredAlignment) {
      verdict = 'ok';
    } else if (inScope) {
      verdict = 'TOO SMALL';
      failures.add(r);
    } else {
      verdict = 'below 16 KB (32-bit, not in scope)';
    }

    stdout.writeln('  ${_pad(r.name, 52)} '
        '${_pad(align == null ? "?" : align.toString(), 9)} '
        '${_pad("${r.loadSegments} LOAD", 8)} $verdict');
  }

  stdout.writeln('');
  if (failures.isEmpty) {
    final inScopeCount =
        results.where((r) => _sixtyFourBitAbis.contains(r.abi)).length;
    stdout.writeln('PASS — all $inScopeCount 64-bit libraries are '
        '16 KB aligned.');
    exit(0);
  }

  stdout.writeln('FAIL — ${failures.length} 64-bit library/libraries are not '
      '16 KB aligned:');
  for (final f in failures) {
    stdout.writeln('  ${f.name} (${f.minAlignment ?? "unreadable"})');
  }
  stdout.writeln('');
  stdout.writeln('Fix by rebuilding the offending dependency against NDK r27+, '
      'or upgrading the Flutter plugin that vendors it.');
  stdout.writeln('See https://developer.android.com/guide/practices/page-sizes');
  exit(1);
}

/// Extracts the ABI directory from a bundle/apk entry path.
///
/// AABs store libraries at `base/lib/<abi>/foo.so` (and
/// `<feature>/lib/<abi>/foo.so` for feature modules); APKs use `lib/<abi>/foo.so`.
String? _abiOf(String entryName) {
  final parts = entryName.split('/');
  final libIndex = parts.lastIndexOf('lib');
  if (libIndex < 0 || libIndex + 2 > parts.length - 1) return null;
  return parts[libIndex + 1];
}

class _LibResult {
  _LibResult({
    required this.name,
    required this.abi,
    required this.sizeBytes,
    required this.loadSegments,
    required this.minAlignment,
    required this.is64Bit,
  });

  final String name;
  final String abi;
  final int sizeBytes;
  final int loadSegments;
  final int? minAlignment;
  final bool is64Bit;
}

class _ElfReport {
  _ElfReport(this.minAlignment, this.loadSegments, this.is64Bit);

  final int minAlignment;
  final int loadSegments;
  final bool is64Bit;
}

const int _ptLoad = 1;

/// Parses the ELF program header table and returns the smallest `p_align`
/// across all PT_LOAD segments, or null if [bytes] is not an ELF we understand.
_ElfReport? _minLoadAlignment(Uint8List bytes) {
  // ELF identification: 0x7F 'E' 'L' 'F'.
  if (bytes.length < 64 ||
      bytes[0] != 0x7F ||
      bytes[1] != 0x45 ||
      bytes[2] != 0x4C ||
      bytes[3] != 0x46) {
    return null;
  }

  final elfClass = bytes[4]; // 1 = ELF32, 2 = ELF64
  final endianness = bytes[5]; // 1 = little, 2 = big
  if (elfClass != 1 && elfClass != 2) return null;
  // Every Android ABI is little-endian; refuse anything else rather than
  // guessing at byte order.
  if (endianness != 1) return null;

  final is64Bit = elfClass == 2;
  final data = ByteData.sublistView(bytes);

  final int phOff;
  final int phEntSize;
  final int phNum;
  if (is64Bit) {
    phOff = data.getUint64(0x20, Endian.little);
    phEntSize = data.getUint16(0x36, Endian.little);
    phNum = data.getUint16(0x38, Endian.little);
  } else {
    phOff = data.getUint32(0x1C, Endian.little);
    phEntSize = data.getUint16(0x2A, Endian.little);
    phNum = data.getUint16(0x2C, Endian.little);
  }

  if (phOff <= 0 || phNum == 0) return null;
  if (phOff + phNum * phEntSize > bytes.length) return null;

  // p_align is the last field of the program header in both ELF classes, but at
  // a different offset because the intervening fields differ in width:
  //   Elf64_Phdr: type4 flags4 offset8 vaddr8 paddr8 filesz8 memsz8 align8
  //               -> align at 0x30, header is 0x38 bytes
  //   Elf32_Phdr: type4 offset4 vaddr4 paddr4 filesz4 memsz4 flags4 align4
  //               -> align at 0x1C, header is 0x20 bytes
  final alignOffsetInHeader = is64Bit ? 0x30 : 0x1C;

  int? minAlign;
  var loadCount = 0;
  for (var i = 0; i < phNum; i++) {
    final base = phOff + i * phEntSize;
    if (base + phEntSize > bytes.length) return null;
    final pType = data.getUint32(base, Endian.little);
    if (pType != _ptLoad) continue;
    loadCount++;
    final align = is64Bit
        ? data.getUint64(base + alignOffsetInHeader, Endian.little)
        : data.getUint32(base + alignOffsetInHeader, Endian.little);
    if (minAlign == null || align < minAlign) minAlign = align;
  }

  if (minAlign == null) return null;
  return _ElfReport(minAlign, loadCount, is64Bit);
}

String _pad(String s, int width) =>
    s.length >= width ? s : s + ' ' * (width - s.length);
