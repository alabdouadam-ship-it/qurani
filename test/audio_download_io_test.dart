import 'package:qurani/services/download_issue_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/services/download_service_io.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/reciter_config_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late HttpServer server;
  HttpOverrides? previousOverrides;
  final bytes = List<int>.filled(32768, 0)..setRange(0, 3, [0x49, 0x44, 0x33]);

  setUp(() async {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null; // Only loopback HTTP; no external network.
    directory = await Directory.systemTemp.createTemp('qurani_download_test_');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => directory.path);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    SharedPreferences.setMockInitialValues({
      'reciters_version': 6,
      'reciters_cache': jsonEncode({
        'reciters': [
          {
            'code': 'test',
            'nameAr': 'قارئ',
            'nameLatin': 'Test',
            'ayahsPath': 'http://127.0.0.1:${server.port}/test',
            'surahsPath': 'http://127.0.0.1:${server.port}/test',
          }
        ]
      })
    });
    await PreferencesService.init();
    ReciterConfigService.resetMemoryCache();
  });
  tearDown(() async {
    await server.close(force: true);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), null);
    ReciterConfigService.resetMemoryCache();
    HttpOverrides.global = previousOverrides;
    await directory.delete(recursive: true);
  });

  test('only validated audio is promoted; a corrupt existing file is replaced',
      () async {
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
    final path = await DownloadService.localSurahPath('test', 1);
    await File(path).writeAsString('not audio');
    await DownloadService.downloadSurah('test', 1);
    expect(await File(path).length(), bytes.length);
    expect(await DownloadService.verifySurahFileCached('test', 1), isTrue);
    await DownloadService.downloadSurah('test', 1);
    expect(requests, 1); // Verified files are reused.
    expect(await File('$path.part').exists(), isFalse);
  });

  test('active HTTP cancellation keeps partial bytes and resumes with Range',
      () async {
    var requests = 0;
    final releaseFirstResponse = Completer<void>();
    String? resumeRange;
    server.listen((request) async {
      requests++;
      final response = request.response;
      response.headers.contentType = ContentType('audio', 'mpeg');
      try {
        if (requests == 1) {
          response.contentLength = bytes.length;
          response.add(bytes.sublist(0, 16384));
          await response.flush();
          await releaseFirstResponse.future;
        } else {
          resumeRange = request.headers.value('range');
          final start = int.parse(resumeRange!.substring(6).split('-').first);
          response.statusCode = HttpStatus.partialContent;
          response.headers.set('content-range',
              'bytes $start-${bytes.length - 1}/${bytes.length}');
          response.contentLength = bytes.length - start;
          response.add(bytes.sublist(start));
        }
        await response.close();
      } catch (_) {/* Expected socket close after cancellation. */}
    });
    final path = await DownloadService.localSurahPath('test', 1);
    final token = CancelToken();
    final pending =
        DownloadService.downloadSurah('test', 1, cancelToken: token);
    final expectation = expectLater(pending, throwsA(isA<DioException>()));
    final part = File('$path.part');
    for (var attempt = 0; attempt < 200; attempt++) {
      if (await part.exists() && await part.length() > 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await part.exists(), isTrue);
    token.cancel();
    await expectation.timeout(const Duration(seconds: 3));
    releaseFirstResponse.complete();
    expect(requests, 1); // Cancellation must not retry.
    expect(await File(path).exists(), isFalse);
    expect(await part.length(), greaterThan(0));
    await DownloadService.downloadSurah('test', 1);
    expect(resumeRange, startsWith('bytes='));
    expect(await File(path).readAsBytes(), bytes);
    expect(await part.exists(), isFalse);
  });

  test('HTTP errors never create a completed file', () async {
    server.listen((request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
    });
    final path = await DownloadService.localSurahPath('test', 1);
    await expectLater(
        DownloadService.downloadSurah('test', 1), throwsException);
    expect(await File(path).exists(), isFalse);
    expect((await DownloadIssueService.load()).single.reason, 'server');
  });
  test(
      'one missing surah leaves the full-reciter flag false and progress below 100%',
      () async {
    server.listen((request) async {
      if (request.uri.path.endsWith('/114.mp3')) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
      } else {
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
      }
      await request.response.close();
    });
    await PreferencesService.setDownloadedFull(
        true); // A legacy false positive.
    final progress = <double>[];
    final result = await DownloadService.downloadFullReciter('test',
        onProgress: progress.add);
    expect(result.completed, 113);
    expect(result.failed, 1);
    expect(result.isComplete, isFalse);
    expect(PreferencesService.isDownloadedFull(), isFalse);
    expect(progress.last, 113 / 114);
    expect(progress.every((value) => value < 1), isTrue);
  });
}
