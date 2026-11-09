import 'download_issue_service.dart';
import 'download_batch.dart';
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

  /// Public accessor for the per-reciter full-surah directory. Used by
  /// `OfflineAudioService` so both services agree on a single layout
  /// (`<docs>/qurani/full/<reciter>/`) and we can't drift apart.
  static Future<Directory> surahsBaseDir(String reciter) async {
    final base = await _baseDir();
    final dir = Directory('${base.path}/$reciter');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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

  // ---------------------------------------------------------------------
  // Public integrity API
  // ---------------------------------------------------------------------

  /// Non-throwing wrapper around [_validateMp3]. Returns `true` if [file]
  /// exists, is large enough, and starts with an MP3 signature.
  static Future<bool> verifyFile(File file) async {
    try {
      if (!await file.exists()) return false;
      await _validateMp3(file);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cached integrity verification. The result is keyed by file size +
  /// mtime in [PreferencesService], so subsequent calls in the same UI
  /// session (or across restarts) are O(1) until the file changes.
  ///
  /// When [forceRefresh] is true, the cache entry is bypassed and the file
  /// is re-sniffed; useful right after a (re)download completes.
  static Future<bool> verifySurahFileCached(
    String reciter,
    int order, {
    bool forceRefresh = false,
  }) async {
    final path = await localSurahPath(reciter, order);
    final file = File(path);
    if (!await file.exists()) {
      // Drop a stale cache entry so the UI badge flips to "missing".
      await PreferencesService.removeVerifiedFullEntry(reciter, order);
      return false;
    }
    final stat = await file.stat();
    final size = stat.size;
    final mtimeMs = stat.modified.millisecondsSinceEpoch;

    if (!forceRefresh) {
      final cache = PreferencesService.getVerifiedFullCache(reciter);
      final padded = order.toString().padLeft(3, '0');
      final entry = cache[padded];
      if (entry != null) {
        final cachedSize = (entry['s'] as num?)?.toInt();
        final cachedMtime = (entry['m'] as num?)?.toInt();
        final cachedOk = entry['ok'] == true;
        if (cachedSize == size && cachedMtime == mtimeMs) {
          return cachedOk;
        }
      }
    }

    final ok = await verifyFile(file);
    await PreferencesService.setVerifiedFullEntry(
      reciter,
      order,
      size: size,
      mtimeMs: mtimeMs,
      ok: ok,
    );
    return ok;
  }

  /// Deletes every full-surah file for [reciter] that fails MP3 validation
  /// (truncated, wrong magic bytes, error-page payload, etc.) and clears
  /// their cache entries. Returns the number of files removed.
  ///
  /// The caller typically follows up with `downloadFullReciter` so the
  /// hole-punched files get re-downloaded on the next bulk run.
  static Future<int> repairCorruptSurahs(String reciter) async {
    int removed = 0;
    for (int order = 1; order <= 114; order++) {
      final path = await localSurahPath(reciter, order);
      final file = File(path);
      if (!await file.exists()) continue;
      // forceRefresh: a "Repair" action should never trust a stale OK.
      final ok = await verifySurahFileCached(reciter, order, forceRefresh: true);
      if (!ok) {
        try {
          await file.delete();
          removed++;
        } catch (e, st) {
          Log.w('DownloadService',
              'repairCorruptSurahs: failed to delete $path', e, st);
        }
        await PreferencesService.removeVerifiedFullEntry(reciter, order);
      }
    }
    return removed;
  }

  /// Aggregate integrity report for a reciter's bulk download. Returns the
  /// counts of `present`, `missing`, and `corrupt` surahs out of 114, so a
  /// UI badge can show e.g. "112/114 verified" at a glance.
  static Future<({int present, int missing, int corrupt})>
      verifyAllSurahs(String reciter) async {
    int present = 0;
    int missing = 0;
    int corrupt = 0;
    for (int order = 1; order <= 114; order++) {
      final path = await localSurahPath(reciter, order);
      if (!await File(path).exists()) {
        missing++;
        continue;
      }
      final ok = await verifySurahFileCached(reciter, order);
      if (ok) {
        present++;
      } else {
        corrupt++;
      }
    }
    return (present: present, missing: missing, corrupt: corrupt);
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
    CancelToken? cancelToken,
  }) async {
    final tempPath = '$target.part';
    final tempFile = File(tempPath);

    Object? lastError;
    StackTrace? lastStack;
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        checkDownloadCancellation(cancelToken);
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
          cancelToken: cancelToken,
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
          // Only promote a partial file when the server confirms its exact size.
          final sizeHeader = response.headers.value('content-range') ?? '';
          final expected = int.tryParse(sizeHeader.split('/').last);
          await response.data?.stream.drain<void>();
          if (expected != null && await tempFile.exists() &&
              await tempFile.length() == expected) {
            await _validateMp3(tempFile);
            checkDownloadCancellation(cancelToken);
            await tempFile.rename(target);
            return;
          }
          if (await tempFile.exists()) await tempFile.delete();
          throw Exception('Server 416 with inconsistent local .part');
        }

        // If we asked for a range and the server returned 200 instead of
        // 206, the server ignored Range and sent the full file — we must
        // truncate the `.part` rather than append.
        final isResume = status == 206 && rangeStart > 0;

        if (status == 206) {
          final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
              .firstMatch(response.headers.value('content-range') ?? '');
          if (range == null || int.parse(range[1]!) != rangeStart) {
            await response.data?.stream.drain<void>();
            throw Exception('Invalid content-range');
          }
        }
        _validateContentType(response, url);

        // Derive total-expected bytes for progress reporting.
        int totalBytes = -1;
        if (status == 206) {
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
            checkDownloadCancellation(cancelToken);
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

        checkDownloadCancellation(cancelToken);
        if (totalBytes >= 0 && received != totalBytes) {
          throw Exception('Incomplete download: $received of $totalBytes bytes');
        }
        await _validateMp3(tempFile);
        checkDownloadCancellation(cancelToken);
        // Atomic move into place; same-filesystem rename is atomic on Android/iOS.
        await tempFile.rename(target);
        return;
      } catch (e, st) {
        // Keep .part for a later resume, without retrying a cancelled request.
        checkDownloadCancellation(cancelToken);
        if (e is DioException && CancelToken.isCancel(e)) rethrow;
        lastError = e;
        lastStack = st;
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
          await Future.any([
            Future<void>.delayed(Duration(milliseconds: 500 * attempt * attempt)),
            if (cancelToken != null) cancelToken.whenCancel,
          ]);
          checkDownloadCancellation(cancelToken);
        }
      }
    }
    // Final failure: drop the `.part` so a future cold-start isn't
    // confused by a partial file of unknown provenance.
    try {
      if (await tempFile.exists()) await tempFile.delete();
    } catch (_) {}
    if (lastError != null && lastStack != null) {
      Error.throwWithStackTrace(lastError, lastStack);
    }
    throw StateError('Download did not complete');
  }

  static Future<void> downloadSurah(String reciter, int order, {CancelToken? cancelToken}) =>
      DownloadIssueService.track(DownloadIssue(reciter: reciter, surah: order),
        () => _downloadSurah(reciter, order, cancelToken: cancelToken), cancelToken: cancelToken);

  static Future<void> _downloadSurah(String reciter, int order, {CancelToken? cancelToken}) async {
    checkDownloadCancellation(cancelToken);
    final url = await AudioService.buildFullRecitationUrl(reciterKeyAr: reciter, surahOrder: order);
    if (url == null) {
      throw Exception('Unable to resolve download URL for surah $order');
    }
    final target = await localSurahPath(reciter, order);
    final file = File(target);
    if (await verifyFile(file)) return;
    if (await file.exists()) await file.delete();
    await _downloadWithRetry(url, target, cancelToken: cancelToken);
    // Refresh the verification cache so the UI doesn't have to wait for
    // the next render to learn the new file is good.
    if (!await verifySurahFileCached(reciter, order, forceRefresh: true)) {
      throw StateError('Downloaded surah failed verification');
    }
  }

  /// Per-ayah download for `OfflineAudioService.downloadAllAyahAudios`.
  /// Reuses [_downloadWithRetry] so ayah downloads inherit the same
  /// `.part`/resume/MP3-validation behaviour as full surahs.
  static Future<void> downloadAyah({required String reciter, required int surahOrder,
    required int verseNumber, CancelToken? cancelToken}) => DownloadIssueService.track(
      DownloadIssue(reciter: reciter, surah: surahOrder, verse: verseNumber),
      () => _downloadAyah(reciter: reciter, surahOrder: surahOrder,
        verseNumber: verseNumber, cancelToken: cancelToken), cancelToken: cancelToken);

  static Future<void> _downloadAyah({
    required String reciter,
    required int surahOrder,
    required int verseNumber,
    CancelToken? cancelToken,
  }) async {
    checkDownloadCancellation(cancelToken);
    final url = await AudioService.buildVerseUrl(
      reciterKeyAr: reciter,
      surahOrder: surahOrder,
      verseNumber: verseNumber,
    );
    if (url == null) {
      throw Exception(
          'Unable to resolve ayah URL for $reciter $surahOrder:$verseNumber');
    }
    final target = await AudioService.localAyahFilePath(
      reciterKeyAr: reciter,
      surahOrder: surahOrder,
      verseNumber: verseNumber,
    );
    final file = File(target);
    if (await verifyFile(file)) return;
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);
    await _downloadWithRetry(url, target, cancelToken: cancelToken);
  }

  /// Downloads the full 114-surah recitation for [reciter] with up to
  /// [concurrency] concurrent HTTP streams. A mobile-friendly default of 4
  /// saturates typical LTE/5G bandwidth without overwhelming shared CDN
  /// connections. Per-surah failures are logged and counted but do not
  /// abort the batch — the user can simply re-run to pick up missing files
  /// (which will resume via the `.part` cache).
  static Future<DownloadBatchResult> downloadFullReciter(String reciter, {
    void Function(double progress)? onProgress, int concurrency = 4, CancelToken? cancelToken,
  }) => DownloadIssueService.track(DownloadIssue(reciter: reciter, surah: 0),
      () => _downloadFullReciter(reciter, onProgress: onProgress, concurrency: concurrency,
          cancelToken: cancelToken), cancelToken: cancelToken);

  static Future<DownloadBatchResult> _downloadFullReciter(
    String reciter, {
    void Function(double progress)? onProgress,
    int concurrency = 4,
    CancelToken? cancelToken,
  }) async {
    // Invalidate any legacy success flag before work starts.
    await PreferencesService.setDownloadedFull(false);
    final result = await runDownloadBatch<int>(
      items: List.generate(114, (i) => i + 1),
      cancelToken: cancelToken,
      concurrency: concurrency,
      onProgress: (completed, total) => onProgress?.call(completed / total),
      download: (order) async {
        if (PreferencesService.isFullSurahPaused(reciter, order)) {
          throw StateError('Surah download is paused');
        }
        await downloadSurah(reciter, order, cancelToken: cancelToken);
      },
    );
    await PreferencesService.setDownloadedFull(result.isComplete);
    await PreferencesService.setDownloadedReciter(reciter);
    return result;
  }
}
