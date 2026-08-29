import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:qurani/services/mushaf_pdf_service.dart';
import 'package:qurani/services/preferences_service.dart';

/// Outcome of a mushaf download attempt.
///
/// The controller deliberately returns a result instead of showing UI: it owns
/// no `BuildContext`, which is what makes the download flow unit-testable and
/// keeps every dialog/snackbar decision in the widget layer where it belongs.
enum MushafDownloadResult {
  /// The file was already on disk; the type was switched without downloading.
  alreadyPresent,

  /// Downloaded and adopted successfully.
  downloaded,

  /// The user cancelled via [MushafPdfController.cancelDownload].
  cancelled,

  /// Network/IO failure. The previously-selected type is left untouched.
  failed,
}

/// Owns the mushaf PDF *asset* state for the reader: which style is selected,
/// whether its file is on disk, the opened [PdfDocument], and download
/// progress.
///
/// Extracted from `read_quran_screen.dart`, where these six fields and their
/// ~150 lines of logic sat among forty-odd others. Keeping them here means the
/// screen no longer has to know that "switching mushaf style" can mean either a
/// cheap swap or a 160 MB download, and the state transitions can be reasoned
/// about (and tested) on their own.
///
/// Notify semantics: every mutation that affects rendering calls
/// [notifyListeners], so the host widget can simply rebuild.
class MushafPdfController extends ChangeNotifier {
  MushafPdfController({MushafType? initialType})
      : _type = initialType ?? _typeFromPrefs();

  static MushafType _typeFromPrefs() {
    final stored = PreferencesService.getPdfType();
    return MushafType.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => MushafType.blue,
    );
  }

  MushafType _type;
  String? _path;
  Future<PdfDocument>? _documentFuture;
  bool _isDownloading = false;
  double? _progress;
  CancelToken? _cancelToken;
  bool _disposed = false;

  MushafType get type => _type;

  /// Path to the on-disk PDF, or null when it has not been downloaded.
  String? get path => _path;

  /// True once a file for [type] is present and can be rendered.
  bool get isAvailable => _path != null;

  bool get isDownloading => _isDownloading;

  /// 0.0..1.0 while downloading, null otherwise.
  double? get progress => _progress;

  /// Number of cover pages before Quran page 1 in the current style's PDF.
  int get pageOffset => MushafPdfService.instance.getPageOffset(_type);

  /// Converts a Quran page (1..604) to a zero-based index into the PDF.
  int pdfIndexForQuranPage(int quranPage) => (quranPage - 1) + pageOffset;

  /// Converts a zero-based PDF index back to a Quran page, which may fall
  /// outside 1..604 for the cover pages.
  int quranPageForPdfIndex(int pdfIndex) => (pdfIndex - pageOffset) + 1;

  /// The opened document, opening it lazily if a file is present.
  ///
  /// Returns null when nothing has been downloaded yet.
  Future<PdfDocument>? get documentFuture {
    final path = _path;
    if (_documentFuture == null && path != null) {
      _documentFuture = PdfDocument.openFile(path);
    }
    return _documentFuture;
  }

  /// Re-checks whether the current style's file exists and (re)opens it.
  Future<void> refreshAvailability() async {
    final path = await MushafPdfService.instance.getPdfPath(_type);
    final exists = await File(path).exists();
    if (_disposed) return;

    if (exists && _path != path) {
      // Dispose the previously-opened document before opening another, or the
      // old native handle leaks for the rest of the session.
      _closeDocument();
      _documentFuture = PdfDocument.openFile(path);
    } else if (!exists) {
      _closeDocument();
    }
    _path = exists ? path : null;
    _safeNotify();
  }

  /// Selects [type], downloading it first if its file is absent.
  ///
  /// Callers that need to confirm a large download with the user should check
  /// [existsFor] first and prompt before calling this.
  Future<MushafDownloadResult> select(MushafType type) async {
    if (await existsFor(type)) {
      await _adopt(type);
      return MushafDownloadResult.alreadyPresent;
    }

    _isDownloading = true;
    _progress = 0;
    _cancelToken = CancelToken();
    _safeNotify();

    try {
      await MushafPdfService.instance.downloadMushaf(
        type,
        onProgress: (received, total) {
          if (_disposed || total <= 0) return;
          _progress = received / total;
          _safeNotify();
        },
        cancelToken: _cancelToken,
      );
      // Persist the choice ONLY after a successful download, so a failed or
      // cancelled attempt never leaves the reader pointing at a missing file.
      await _adopt(type);
      return MushafDownloadResult.downloaded;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return MushafDownloadResult.cancelled;
      }
      if (kDebugMode) debugPrint('[MushafPdf] download failed: $e');
      return MushafDownloadResult.failed;
    } finally {
      _isDownloading = false;
      _progress = null;
      _cancelToken = null;
      _safeNotify();
    }
  }

  /// Whether [type]'s file is already on disk.
  Future<bool> existsFor(MushafType type) async {
    final path = await MushafPdfService.instance.getPdfPath(type);
    return File(path).exists();
  }

  void cancelDownload() => _cancelToken?.cancel();

  /// Switches the selected style without touching the filesystem, clearing the
  /// cached path/document so the next render re-resolves them.
  ///
  /// Kept synchronous and IO-free so the state transition is unit-testable;
  /// [chooseStyle] is the composed version callers normally want.
  void resetTo(MushafType type) {
    _closeDocument();
    _type = type;
    _path = null;
    _safeNotify();
  }

  /// Selects [type] as the active style, persists it, and re-checks whether its
  /// file is present.
  ///
  /// Note the deliberate asymmetry with [select]: this persists the choice
  /// immediately, so picking a style that has not been downloaded leaves the
  /// reader showing that style's download prompt. [select] persists only after a
  /// successful download, so a failed or cancelled attempt never strands the
  /// reader on a missing file. Both behaviours predate this controller and are
  /// preserved rather than unified, because they serve different entry points:
  /// the style picker (explicit choice) versus the download button (recovery).
  Future<void> chooseStyle(MushafType type) async {
    resetTo(type);
    await PreferencesService.savePdfType(type.id);
    if (_disposed) return;
    await refreshAvailability();
  }

  /// Deletes the current style's file — the "delete and retry" recovery path
  /// for a corrupt download.
  Future<void> deleteCurrentFile() async {
    final path = _path;
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[MushafPdf] delete failed: $e');
    }
    await refreshAvailability();
  }

  Future<void> _adopt(MushafType type) async {
    await PreferencesService.savePdfType(type.id);
    if (_disposed) return;
    _type = type;
    await refreshAvailability();
  }

  /// Closes the opened document once its future resolves. Awaiting the future
  /// rather than ignoring it matters: a document opened but never closed keeps
  /// its native handle, and callers routinely replace the future while the open
  /// is still in flight.
  void _closeDocument() {
    final future = _documentFuture;
    _documentFuture = null;
    if (future == null) return;
    future.then((doc) {
      try {
        doc.dispose();
      } catch (_) {}
    }).catchError((_) {
      // Open failed; nothing to dispose.
    });
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel();
    _closeDocument();
    super.dispose();
  }
}
