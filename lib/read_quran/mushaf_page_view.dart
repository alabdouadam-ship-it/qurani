import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/mushaf_pdf_service.dart';
import 'package:qurani/widgets/modern_ui.dart';

import 'mushaf_pdf_controller.dart';
import 'zoomable_pdf_page.dart';

/// The mushaf (PDF) reading surface, including its download and error states.
///
/// Extracted from `read_quran_screen.dart`, where this was ~200 lines of
/// `_buildPdfView` interleaved with the text reader's own build methods. The
/// screen still owns the [PageController] because four of its methods jump it
/// programmatically (page picker, surah/juz pickers, auto-flip, and the
/// fullscreen transition, which deliberately recreates it at a new initial
/// page); moving that lifecycle would have meant an imperative handle for no
/// real gain. What does move here is the whole build tree plus the zoom state,
/// which nothing outside this widget ever read.
class MushafPageView extends StatefulWidget {
  const MushafPageView({
    super.key,
    required this.controller,
    required this.pageController,
    required this.currentQuranPage,
    required this.totalQuranPages,
    required this.isFullscreen,
    required this.onQuranPageChanged,
    required this.onRequestDownload,
    required this.onReturnToTextView,
    required this.onLongPressPage,
    required this.onLongPressWhileFullscreen,
  });

  /// Owns which style is selected, whether its file is present, the opened
  /// document, and download progress.
  final MushafPdfController controller;

  /// Owned by the host screen so it can jump pages programmatically.
  final PageController pageController;

  /// 1-based Quran page currently being read.
  final int currentQuranPage;
  final int totalQuranPages;
  final bool isFullscreen;

  /// Fired when the user swipes to a different Quran page. Cover pages at the
  /// front of the PDF are filtered out before this is called.
  final ValueChanged<int> onQuranPageChanged;

  final ValueChanged<MushafType> onRequestDownload;
  final VoidCallback onReturnToTextView;

  /// Long-press on a page while not in fullscreen — opens the page's options.
  final ValueChanged<int> onLongPressPage;

  /// Long-press while in fullscreen reveals the hidden controls instead.
  final VoidCallback onLongPressWhileFullscreen;

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  /// True while a page is pinch/double-tap zoomed, which locks horizontal
  /// paging so a pan gesture doesn't flip the page out from under the user.
  bool _isZoomed = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (controller.isDownloading) {
      return _DownloadProgress(
        progress: controller.progress,
        onCancel: controller.cancelDownload,
      );
    }

    if (!controller.isAvailable) {
      return _DownloadPrompt(
        onRequestDownload: widget.onRequestDownload,
        onReturnToTextView: widget.onReturnToTextView,
      );
    }

    return FutureBuilder<PdfDocument>(
      future: controller.documentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PdfLoadError(
            error: snapshot.error,
            onDeleteAndRetry: controller.deleteCurrentFile,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final document = snapshot.data!;
        final currentPdfIndex =
            controller.pdfIndexForQuranPage(widget.currentQuranPage);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: PageView.builder(
            controller: widget.pageController,
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: document.pages.length,
            onPageChanged: (index) {
              final quranPage = controller.quranPageForPdfIndex(index);
              // The first few PDF pages are covers, so they map to page numbers
              // below 1 and must not be reported as a reading position.
              if (quranPage >= 1 &&
                  quranPage <= widget.totalQuranPages &&
                  quranPage != widget.currentQuranPage) {
                widget.onQuranPageChanged(quranPage);
              }
            },
            itemBuilder: (context, index) {
              return ZoomablePdfPage(
                document: document,
                pageNumber: index + 1,
                isFullscreen: widget.isFullscreen,
                mushafType: controller.type,
                // Keep only the current page and its immediate neighbours
                // alive. See ZoomablePdfPage.keepAlive: unconditional
                // keep-alive across a ~613-page PageView retained a rasterised
                // bitmap for every page visited in the session.
                keepAlive: (index - currentPdfIndex).abs() <= 1,
                onZoomChanged: (isZoomed) {
                  if (mounted && isZoomed != _isZoomed) {
                    setState(() => _isZoomed = isZoomed);
                  }
                },
                onLongPress: () {
                  if (widget.isFullscreen) {
                    widget.onLongPressWhileFullscreen();
                    return;
                  }
                  final quranPage = controller.quranPageForPdfIndex(index);
                  if (quranPage >= 1 && quranPage <= widget.totalQuranPages) {
                    widget.onLongPressPage(quranPage);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Localized display name for a mushaf style.
String mushafTypeLabel(AppLocalizations l10n, MushafType type) {
  switch (type) {
    case MushafType.blue:
      return l10n.mushafTypeBlue;
    case MushafType.green:
      return l10n.mushafTypeGreen;
    case MushafType.tajweed:
      return l10n.mushafTypeTajweed;
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress, required this.onCancel});

  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ModernSurfaceCard(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.downloadingMushaf,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text('${((progress ?? 0) * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onCancel,
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadPrompt extends StatelessWidget {
  const _DownloadPrompt({
    required this.onRequestDownload,
    required this.onReturnToTextView,
  });

  final ValueChanged<MushafType> onRequestDownload;
  final VoidCallback onReturnToTextView;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ModernSurfaceCard(
        margin: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_for_offline,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(l10n.downloadMushafPdf,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(l10n.chooseStyleToDownload,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: MushafType.values.map((type) {
                  return ElevatedButton.icon(
                    icon: const Icon(Icons.file_download),
                    label: Text(mushafTypeLabel(l10n, type)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => onRequestDownload(type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: onReturnToTextView,
                child: Text(l10n.returnToTextView),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfLoadError extends StatelessWidget {
  const _PdfLoadError({required this.error, required this.onDeleteAndRetry});

  final Object? error;
  final VoidCallback onDeleteAndRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(l10n.errorLoadingPdf, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onDeleteAndRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.deleteAndRetry),
            )
          ],
        ),
      ),
    );
  }
}
