import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'logger.dart';
import 'preferences_service.dart';
import 'audio_service.dart';

class DownloadService {
  DownloadService._();
  static final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 60)));

  // Minimum plausible size for a Quran surah recitation in mp3 form. Even the
  // shortest surah (al-Kawthar, ~20s at 64kbps) produces ~160KB files. Anything
  // below ~8KB is almost certainly an HTML error page or a truncated download.
  static const int _minPlausibleBytes = 8 * 1024;

  // Max retry attempts per file — covers transient network blips without
  // hammering misconfigured CDNs.
  static const int _maxAttempts = 3;

  static Future<Directory> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/qurani/full');
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  static Future<String> localSurahPath(String reciter, int order) async {
    final base = await _baseDir();
    final padded = order.toString().padLeft(3, '0');
    final newDir = Directory('${base.path}/$reciter');
    final docs = await getApplicationDocumentsDirectory();
    final oldDir = Directory('${docs.path}/full/$reciter');
    final oldPath = '${oldDir.path}/$padded.mp3';
    if (await File(oldPath).exists()) {
      return oldPath;
    }
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }
    return '${newDir.path}/$padded.mp3';
  }

  static Future<bool> isSurahDownloaded(String reciter, int order) async {
    final path = await localSurahPath(reciter, order);
    return File(path).exists();
  }

  /// Verifies that the downloaded [file] looks like a valid MP3. Performs:
  ///  1. Minimum-size check (rejects HTML error pages / short writes).
  ///  2. Magic-byte sniff — mp3 files start with either the ASCII string
  ///     `ID3` (ID3v2 tag) or the MPEG frame sync `0xFF 0xFA/0xFB/0xF3/0xF2`.
  ///     This catches e.g. a JSON error payload that somehow has the right
  ///     content-type and length but is not actually audio.
  static Future<void> _validateMp3(File file) async {
    final length = await file.length();
    if (length < _minPlausibleBytes) {
      throw Exception(
          'Downloaded file is too small ($length bytes); likely an error response.');
    }
    final raf = await file.open();
    try {
      final head = await raf.read(4);
      final isId3 = head.length >= 3 &&
          head[0] == 0x49 /* I */ &&
          head[1] == 0x44 /* D */ &&
          head[2] == 0x33 /* 3 */;
      final isMpegSync = head.length >= 2 &&
          head[0] == 0xFF &&
          (head[1] == 0xFB ||
              head[1] == 0xFA ||
              head[1] == 0xF3 ||
              head[1] == 0xF2);
      if (!isId3 && !isMpegSync) {
        throw Exception(
            'Downloaded file does not have an MP3 signature; aborting.');
      }
    } finally {
      await raf.close();
    }
  }

  /// Validates that the HTTP response carries audio bytes. Content-Type is
  /// the most reliable signal when the server sets it properly; many Quran
  /// CDNs also use `application/octet-stream`, which we tolerate. An empty
  /// content-type is tolerated because some reciter CDNs omit it entirely.
  static void _validateContentType(Response response, String url) {
    final ct =
        (response.headers.value(Headers.contentTypeHeader) ?? '').toLowerCase();
    if (ct.isEmpty) return; // best-effort: caller will still run _validateMp3
    final ok = ct.startsWith('audio/') ||
        ct.contains('mpeg') ||
        ct.contains('octet-stream');
    if (!ok) {
      throw Exception('Unexpected content-type "$ct" while downloading $url');
    }
  }

  /// Downloads [url] to [target] using a `.part` temp-file strategy with
  /// retries and HTTP Range resume. The target is only created/moved into
  /// place after the full file has been downloaded and sniffed as an MP3 —
  /// so if the app is killed mid-download, the next attempt won't mistake a
  /// truncated file for a completed one, and the `.part` is reused to skip
  /// re-downloading bytes that were already received.
  static Future<void> _downloadWithRetry(
    String url,
    String target, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final tempPath = '$target.part';
    final tempFile = File(tempPath);

    Object? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        // Range-resume: pick up from the current `.part` size rather than
        // starting over on every attempt. On cellular connections this can
        // save megabytes on flaky retries.
        int rangeStart = 0;
        if (await tempFile.exists()) {
          rangeStart = await tempFile.length();
          // Guard against an obviously corrupt pile-up (cap at 500MB — a
          // full recitation tops out around 10-30MB).
          if (rangeStart < 0 || rangeStart > 500 * 1024 * 1024) {
            await tempFile.delete();
            rangeStart = 0;
          }
        }

        final response = await _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: true,
            // Accept 2xx, 3xx, and 416 (range-not-satisfiable we handle
            // below); reject 4xx/5xx so they surface as retryable errors.
            validateStatus: (s) =>
                s != null && ((s >= 200 && s < 400) || s == 416),
            headers: {
              if (rangeStart > 0) 'Range': 'bytes=$rangeStart-',
            },
          ),
        );

        final status = response.statusCode ?? 0;

        if (status == 416) {
          // Server says our requested range is past the end — the `.part`
          // is probably already the complete file. Validate and promote.
          if (await tempFile.exists() && await tempFile.length() > 0) {
            await _validateMp3(tempFile);
            await tempFile.rename(target);
            return;
          }
          // Otherwise the local state is inconsistent; start fresh.
          if (await tempFile.exists()) await tempFile.delete();
          throw Exception('Server 416 with empty local .part');
        }

        // If we asked for a range and the server returned 200 instead of
        // 206, the server ignored Range and sent the full file — we must
        // truncate the `.part` rather than append.
        final isResume = status == 206 && rangeStart > 0;

        _validateContentType(response, url);

        // Derive total-expected bytes for progress reporting.
        int totalBytes = -1;
        if (isResume) {
          // `Content-Range: bytes 1000-4999/5000`
          final cr = response.headers.value('content-range');
          if (cr != null && cr.contains('/')) {
            totalBytes = int.tryParse(cr.split('/').last) ?? -1;
          }
        } else {
          final cl = response.headers.value(Headers.contentLengthHeader);
          if (cl != null) totalBytes = int.tryParse(cl) ?? -1;
        }

        final sink = tempFile.openWrite(
          mode: isResume ? FileMode.append : FileMode.write,
        );
        int received = isResume ? rangeStart : 0;
        try {
          await for (final chunk in response.data!.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (onReceiveProgress != null && totalBytes > 0) {
              onReceiveProgress(received, totalBytes);
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        await _validateMp3(tempFile);
        // Atomic move into place; same-filesystem rename is atomic on Android/iOS.
        await tempFile.rename(target);
        return;
      } catch (e, st) {
        lastError = e;
        Log.w('DownloadService',
            'attempt $attempt/$_maxAttempts for $url failed', e, st);
        // If the failure is an *integrity* error (bad content-type, bad
        // magic bytes, truncated file), the bytes we have are tainted and
        // resuming would pile more bad bytes on top. Nuke the `.part` so
        // the next attempt starts from zero. Transient network errors, by
        // contrast, leave the `.part` intact for Range-resume.
        final msg = e.toString();
        final corrupt = msg.contains('content-type') ||
            msg.contains('MP3 signature') ||
            msg.contains('too small');
        if (corrupt) {
          try {
            if (await tempFile.exists()) await tempFile.delete();
          } catch (_) {}
        }
        if (attempt < _maxAttempts) {
          // Exponential backoff: 500ms, 2s, then fail.
          await Future.delayed(
              Duration(milliseconds: 500 * attempt * attempt));
        }
      }
    }
    // Final failure: drop the `.part` so a future cold-start isn't
    // confused by a partial file of unknown provenance.
    try {
      if (await tempFile.exists()) await tempFile.delete();
    } catch (_) {}
    throw Exception(
        'Download failed after $_maxAttempts attempts for $url: $lastError');
  }

  static Future<void> downloadSurah(String reciter, int order) async {
    final url = await AudioService.buildFullRecitationUrl(reciterKeyAr: reciter, surahOrder: order);
    if (url == null) {
      throw Exception('Unable to resolve download URL for surah $order');
    }
    final target = await localSurahPath(reciter, order);
    final file = File(target);
    if (await file.exists()) {
      return;
    }
    await _downloadWithRetry(url, target);
  }

  /// Downloads the full 114-surah recitation for [reciter] with up to
  /// [concurrency] concurrent HTTP streams. A mobile-friendly default of 4
  /// saturates typical LTE/5G bandwidth without overwhelming shared CDN
  /// connections. Per-surah failures are logged and counted but do not
  /// abort the batch — the user can simply re-run to pick up missing files
  /// (which will resume via the `.part` cache).
  static Future<void> downloadFullReciter(
    String reciter, {
    void Function(double progress)? onProgress,
    int concurrency = 4,
  }) async {
    // Per-surah progress tracking so overall progress aggregates across
    // concurrent downloads. Keyed by surah order (1..114).
    final received = <int, int>{};
    final totals = <int, int>{};
    final done = <int, bool>{};

    void report() {
      double sum = 0;
      for (int i = 1; i <= 114; i++) {
        if (done[i] == true) {
          sum += 1;
        } else {
          final r = received[i] ?? 0;
          final t = totals[i] ?? 0;
          if (t > 0) sum += r / t;
        }
      }
      onProgress?.call((sum / 114.0).clamp(0.0, 1.0));
    }

    Future<void> downloadOne(int order) async {
      final url = await AudioService.buildFullRecitationUrl(
          reciterKeyAr: reciter, surahOrder: order);
      if (url == null) {
        done[order] = true;
        report();
        return;
      }
      final target = await localSurahPath(reciter, order);
      final file = File(target);
      if (await file.exists()) {
        done[order] = true;
        report();
        return;
      }
      try {
        await _downloadWithRetry(
          url,
          target,
          onReceiveProgress: (r, t) {
            received[order] = r;
            if (t > 0) totals[order] = t;
            report();
          },
        );
      } catch (e, st) {
        Log.w('DownloadService', 'Surah $order failed after retries', e, st);
      }
      done[order] = true;
      report();
    }

    // Shared iterator feeds the worker pool — Dart's single-threaded event
    // loop makes `moveNext` atomic, so the workers can safely race on it.
    final queue = List.generate(114, (i) => i + 1).iterator;
    Future<void> worker() async {
      while (queue.moveNext()) {
        await downloadOne(queue.current);
      }
    }

    final workerCount = concurrency < 1 ? 1 : concurrency;
    await Future.wait(List.generate(workerCount, (_) => worker()));

    await PreferencesService.setDownloadedFull(true);
    await PreferencesService.setDownloadedReciter(reciter);
  }
}


