import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/providers/reader_prefs_providers.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_constants.dart';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/services/irab_service.dart';
import 'package:qurani/widgets/irab_verse_widget.dart';
import 'util/arabic_font_utils.dart';

import 'widgets/share_ayah_sheet.dart';
import 'util/tajweed_parser.dart';
import 'services/net_utils.dart';
import 'util/debug_error_display.dart';

import 'package:pdfrx/pdfrx.dart';
import 'package:qurani/services/mushaf_pdf_service.dart';
import 'package:dio/dio.dart'; // For CancelToken if needed
import 'package:wakelock_plus/wakelock_plus.dart';

import 'util/settings_sheet_utils.dart';
import 'services/reciter_config_service.dart';
import 'widgets/modern_ui.dart';

import 'read_quran/ayah_color_picker_sheet.dart';
import 'read_quran/ayah_number_badge.dart';
import 'read_quran/ayah_options_sheet.dart';
import 'read_quran/ayah_text_dialog.dart';
import 'read_quran/basmalah_header.dart';
import 'read_quran/basmalah_text_utils.dart';
import 'read_quran/edition_label.dart';
import 'read_quran/highlight_models.dart';
import 'read_quran/highlighted_ayahs_sheet.dart';
import 'read_quran/highlighted_pdf_pages_sheet.dart';
import 'read_quran/juz_picker_sheet.dart';
import 'read_quran/mushaf_style_picker.dart';
import 'read_quran/page_audio_sources.dart';
import 'read_quran/page_picker_sheet.dart';
import 'read_quran/pdf_page_options_sheet.dart';
import 'read_quran/reader_settings_sheet.dart';
import 'read_quran/surah_picker_sheet.dart';
import 'read_quran/zoomable_pdf_page.dart';

const String kBasmalah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

class ReadQuranScreen extends ConsumerStatefulWidget {
  const ReadQuranScreen({super.key});

  @override
  ConsumerState<ReadQuranScreen> createState() => _ReadQuranScreenState();
}

class _ReadQuranScreenState extends ConsumerState<ReadQuranScreen> {
  static const int _totalPages = 604;

  final QuranRepository _repository = QuranRepository.instance;
  late PageController _pageController;

  int _currentPage = 1;
  QuranEdition _edition = QuranEdition.simple;
  final Map<int, int> _highlightedAyahs = <int, int>{};
  final Set<int> _highlightedPdfPages = <int>{};
  int? _selectedAyah;
  late Future<List<SurahMeta>> _surahListFuture;
  PageData? _currentPageData;

  late final AudioPlayer _pagePlayer;
  bool _isPlayingPage = false;
  bool _isLoadingPageAudio = false;
  int? _currentAyahIndex;
  ConcatenatingAudioSource? _currentPageAudioSource;
  String? _pageAudioReciter;
  Future<bool>? _pageAudioPreparation;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<SequenceState?>? _sequenceStateSub;
  final ScrollController _pageScrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = <int, GlobalKey>{};
  int? _pendingScrollAyah;
  late String _arabicFontKey;
  bool _autoFlip = false;
  final Map<String, PageData> _pageCache =
      <String, PageData>{}; // Cache for loaded pages

  // ── Fix: independent audio tracking to prevent race conditions ──
  /// Monotonic counter; incremented on user actions to cancel stale auto-flip.
  int _autoFlipGeneration = 0;
  /// Page number the current ConcatenatingAudioSource was built for.
  int? _audioSourcePageNumber;
  /// Maps each audio source index → page.ayahs index (handles skipped nulls).
  List<int> _sourceIndexToAyahIndex = <int>[];
  /// True while _goToPageForAutoFlip is executing, suppresses onPageChanged.
  bool _isAutoFlipping = false;

  // PDF Mode State
  bool _isPdfMode = false;
  bool _isPdfZoomed = false;
  Future<PdfDocument>? _pdfDocumentFuture;
  MushafType _pdfType = MushafType.blue;
  PageController? _pdfPageController;
  bool _isDownloadingPdf = false;
  double? _downloadProgress;
  String? _pdfPath;
  CancelToken? _downloadCancelToken;
  bool _isFullscreen = false;
  bool _fullscreenControlsVisible = false;
  bool _fullscreenButtonVisible = false;
  Timer? _fullscreenButtonTimer;

  @override
  void initState() {
    super.initState();
    final savedEdition = PreferencesService.getLastReadEdition();
    try {
      _edition = QuranEdition.values.firstWhere(
        (e) => e.name == savedEdition,
        orElse: () => QuranEdition.simple,
      );
    } catch (_) {
      _edition = QuranEdition.simple;
    }

    // Check start at last page preference
    final startAtLastPage = PreferencesService.getStartAtLastPage();
    if (startAtLastPage) {
      _currentPage = PreferencesService.getLastReadPage(_edition.name);
    }

    if (_currentPage > _totalPages) {
      _currentPage = 1;
    }

    _pageController = PageController(initialPage: _currentPage - 1);
    _surahListFuture = _repository.loadAllSurahs();
    // Load highlights
    _highlightedAyahs.addAll(PreferencesService.getHighlightedAyahs());
    _highlightedPdfPages.addAll(PreferencesService.getHighlightedPdfPages());

    // Load initial data
    _arabicFontKey = ref.read(arabicFontProvider);
    _autoFlip = PreferencesService.getAutoFlipPage();

    // Initialize PDF Mode
    _isPdfMode = PreferencesService.getIsPdfMode();
    final pdfTypeStr = PreferencesService.getPdfType();
    _pdfType = MushafType.values.firstWhere(
      (e) => e.name == pdfTypeStr,
      orElse: () => MushafType.blue,
    );
    if (_isPdfMode) {
      _checkPdfAvailability();
    }
    unawaited(_setKeepScreenAwake(true));

    _pagePlayer = AudioPlayer();
    _playerStateSub = _pagePlayer.playerStateStream.listen((state) {
      final completed = state.processingState == ProcessingState.completed;
      final isPlaying = state.playing && !completed;
      if (mounted) {
        setState(() {
          _isPlayingPage = isPlaying;
        });
      } else {
        _isPlayingPage = isPlaying;
      }

      // Fix 1+4: Only auto-flip when the ENTIRE sequence is done (not a
      // single-item buffering timeout). Use a generation counter so that
      // any user action (swipe, tap, stop) cancels stale auto-flip chains.
      if (completed && !_pagePlayer.hasNext) {
        debugPrint(
            '[ReadQuran] Audio completed on page $_currentPage, autoFlip: $_autoFlip');
        if (_autoFlip && _currentPage < _totalPages && mounted) {
          final nextPage = _currentPage + 1;
          final generation = _autoFlipGeneration;
          debugPrint(
              '[ReadQuran] Auto-flipping from $_currentPage to $nextPage (gen=$generation)');

          unawaited(_stopPageAudioSilent());
          _handleAutoFlip(nextPage, generation);
        } else {
          unawaited(_stopPageAudio());
        }
      }
    });

    // Fix 3: Use _sourceIndexToAyahIndex mapping so that skipped null
    // sources don't cause index→ayah misalignment.
    _sequenceStateSub = _pagePlayer.sequenceStateStream.listen((sequenceState) {
      if (!mounted) return;

      final sourceIndex = sequenceState?.currentIndex;
      final page = _currentPageData;
      final sourcePage = _audioSourcePageNumber;
      int? ayahNumber;

      if (sourceIndex != null &&
          page != null &&
          sourcePage == page.number &&
          sourceIndex >= 0) {
        // Resolve through the mapping (handles skipped null sources)
        final ayahIdx = (sourceIndex < _sourceIndexToAyahIndex.length)
            ? _sourceIndexToAyahIndex[sourceIndex]
            : sourceIndex;
        if (ayahIdx >= 0 && ayahIdx < page.ayahs.length) {
          ayahNumber = page.ayahs[ayahIdx].number;
        }
      }

      if (mounted) {
        setState(() {
          _currentAyahIndex = sourceIndex;
          if (ayahNumber != null) {
            _selectedAyah = ayahNumber;
          }
        });
        if (ayahNumber != null) {
          _scheduleScrollToAyah(ayahNumber);
        }
      }
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _sequenceStateSub?.cancel();
    unawaited(_restoreReadingScreenUi());

    // Dispose player safely
    try {
      _pagePlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing audio player: $e');
    }
    _pageController.dispose();
    _pageScrollController.dispose();
    _fullscreenButtonTimer?.cancel();
    super.dispose();
  }

  void _goToPage(int page, {int? highlightAyah}) {
    final target = page.clamp(1, _totalPages);
    _autoFlipGeneration++; // Cancel any pending auto-flip
    unawaited(_stopPageAudio());
    setState(() {
      _currentPage = target;
      _selectedAyah = highlightAyah;
      _currentPageData = null;
      _ayahKeys.clear();
      _pendingScrollAyah = highlightAyah;
    });

    // Jump PDF controller if in PDF mode
    if (_isPdfMode && _pdfPath != null) {
      final offset = MushafPdfService.instance.getPageOffset(_pdfType);
      // PDF Page Index = (Target Quran Page - 1) + Offset
      // But wait, the offset logic:
      // Text Page 1 (Fatiha) -> PDF Page 4.
      // PDF Page 4 is Index 3 (if 0-based).
      // My PageView.builder is 0-based.
      // item 0 is PDF Page 1.
      // item 3 is PDF Page 4.
      // So Target Index = (Target - 1) + Offset.
      // Example: Go to Page 1. Target=1. Offset=3. Index = 0 + 3 = 3. Correct (Page 4).

      final targetIndex = (target - 1) + offset;

      if (_pdfPageController?.hasClients == true) {
        _pdfPageController!.jumpToPage(targetIndex);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageScrollController.hasClients) {
          _pageScrollController.jumpTo(0);
        }
        if (highlightAyah != null) {
          _scheduleScrollToAyah(highlightAyah, immediate: true);
        }
      });
      try {
        _pageController.jumpToPage(target - 1);
      } catch (_) {
        // Fallback to animated navigation if jump fails due to controller state
        _pageController.animateToPage(
          target - 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _setKeepScreenAwake(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (_) {}
  }

  Future<void> _applyFullscreenSystemUi() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        _isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } catch (_) {}
  }

  void _setFullscreenControlsVisible(bool visible) {
    if (!_isFullscreen || _fullscreenControlsVisible == visible) return;

    if (mounted) {
      setState(() {
        _fullscreenControlsVisible = visible;
      });
    } else {
      _fullscreenControlsVisible = visible;
    }
  }

  void _showFullscreenControls() {
    _setFullscreenControlsVisible(true);
    // Also reveal the exit button while audio controls are open
    _autoShowFullscreenButton();
  }

  void _hideFullscreenControls() {
    _setFullscreenControlsVisible(false);
    // Schedule the button to auto-hide after controls close
    _scheduleHideFullscreenButton();
  }

  /// Shows the fullscreen exit button and schedules it to auto-hide after a delay.
  void _autoShowFullscreenButton() {
    _fullscreenButtonTimer?.cancel();
    if (!_isFullscreen) return;
    if (mounted) {
      setState(() => _fullscreenButtonVisible = true);
    }
    _scheduleHideFullscreenButton();
  }

  /// Tap-toggle: shows button if hidden (resets timer), hides immediately if visible.
  void _toggleFullscreenButton() {
    if (!_isFullscreen) return;
    if (_fullscreenButtonVisible) {
      _fullscreenButtonTimer?.cancel();
      if (mounted) setState(() => _fullscreenButtonVisible = false);
    } else {
      _autoShowFullscreenButton();
    }
  }

  /// Schedules the exit button to slide away after [delay].
  void _scheduleHideFullscreenButton({
    Duration delay = const Duration(milliseconds: 3500),
  }) {
    _fullscreenButtonTimer?.cancel();
    _fullscreenButtonTimer = Timer(delay, () {
      if (mounted && _isFullscreen && !_fullscreenControlsVisible) {
        setState(() => _fullscreenButtonVisible = false);
      }
    });
  }


  void _syncActiveReaderPage() {
    final targetPage = _currentPage.clamp(1, _totalPages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_isPdfMode) {
        final offset = MushafPdfService.instance.getPageOffset(_pdfType);
        final targetIndex = (targetPage - 1) + offset;
        final controller = _pdfPageController;
        if (controller?.hasClients == true) {
          try {
            controller!.jumpToPage(targetIndex);
          } catch (_) {}
        }
        return;
      }

      if (_pageController.hasClients) {
        try {
          _pageController.jumpToPage(targetPage - 1);
        } catch (_) {}
      }
    });
  }

  Future<void> _setFullscreen(bool value) async {
    if (_isFullscreen == value) return;

    final targetPage = _currentPage.clamp(1, _totalPages);
    PageController? oldPdfController;
    PageController? oldPageController;

    if (_isPdfMode) {
      final offset = MushafPdfService.instance.getPageOffset(_pdfType);
      final targetIndex = (targetPage - 1) + offset;
      oldPdfController = _pdfPageController;
      _pdfPageController = PageController(initialPage: targetIndex);
    } else {
      oldPageController = _pageController;
      _pageController = PageController(initialPage: targetPage - 1);
    }

    if (mounted) {
      setState(() {
        _isFullscreen = value;
        _fullscreenControlsVisible = false;
        _fullscreenButtonVisible = false;
      });
    } else {
      _isFullscreen = value;
      _fullscreenControlsVisible = false;
      _fullscreenButtonVisible = false;
    }

    // Auto-show the exit button briefly when entering fullscreen
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoShowFullscreenButton());
    } else {
      _fullscreenButtonTimer?.cancel();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        oldPdfController?.dispose();
      } catch (_) {}
      try {
        oldPageController?.dispose();
      } catch (_) {}
    });

    await _applyFullscreenSystemUi();
    _syncActiveReaderPage();
  }

  Future<void> _toggleFullscreen() async {
    await _setFullscreen(!_isFullscreen);
  }

  Future<void> _restoreReadingScreenUi() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  Future<void> _handlePopInvoked(bool didPop) async {
    if (!didPop && _isFullscreen) {
      await _setFullscreen(false);
    }
  }

  String _fullscreenTooltip(AppLocalizations l10n, {required bool exiting}) {
    if (l10n.localeName == 'ar') {
      return exiting ? 'الخروج من ملء الشاشة' : 'ملء الشاشة';
    }
    if (l10n.localeName == 'fr') {
      return exiting ? 'Quitter le plein écran' : 'Plein écran';
    }
    return exiting ? 'Exit fullscreen' : 'Fullscreen';
  }

  Widget _buildFullscreenExitButton() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // NOTE: This returns the button content only — NO PositionedDirectional.
    // Positioning is handled at the Stack level so Positioned is always a direct child.
    return Material(
      color: theme.colorScheme.surface.withAlpha(
        theme.brightness == Brightness.dark ? 205 : 232,
      ),
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      child: Tooltip(
        message: _fullscreenTooltip(l10n, exiting: true),
        child: InkWell(
          onTap: () => unawaited(_setFullscreen(false)),
          borderRadius: BorderRadius.circular(18),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.fullscreen_exit_rounded),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePreviousAyahPressed() async {
    if (_isLoadingPageAudio) return;

    if (_currentPageData == null) {
      setState(() {
        _isLoadingPageAudio = true;
      });
      try {
        final data = await _repository.loadPage(_currentPage, _edition);
        if (!mounted) return;

        setState(() {
          _currentPageData = data;
          _isLoadingPageAudio = false;
        });
        await _seekToPreviousAyah();
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoadingPageAudio = false;
          });
        }
      }
      return;
    }

    await _seekToPreviousAyah();
  }

  Future<void> _handlePlayPausePressed() async {
    if (_isLoadingPageAudio) return;

    if (_currentPageData != null) {
      await _togglePageAudio(_currentPageData!);
      return;
    }

    setState(() {
      _isLoadingPageAudio = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await _repository.loadPage(_currentPage, _edition);
      if (!mounted) return;

      setState(() {
        _currentPageData = data;
        _isLoadingPageAudio = false;
      });
      await _togglePageAudio(data);
    } catch (e, st) {
      debugPrint('[ReadQuranScreen] loadPage audio error: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoadingPageAudio = false;
        });
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorLoadingAudio)),
      );
    }
  }

  Widget _buildFullscreenPlaybackControls() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return PositionedDirectional(
      bottom: bottomInset + 16,
      start: 16,
      end: 16,
      child: Center(
        child: Material(
          color: theme.colorScheme.surface.withAlpha(
            theme.brightness == Brightness.dark ? 220 : 238,
          ),
          borderRadius: BorderRadius.circular(24),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isRtl ? Icons.skip_next : Icons.skip_previous),
                  tooltip: l10n.previousAyah,
                  onPressed: _isLoadingPageAudio
                      ? null
                      : () => unawaited(_handlePreviousAyahPressed()),
                ),
                IconButton(
                  iconSize: 34,
                  icon: _isLoadingPageAudio
                      ? SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.onSurface,
                            ),
                          ),
                        )
                      : Icon(
                          _isPlayingPage
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                  tooltip:
                      _isPlayingPage ? l10n.pausePageAudio : l10n.playPageAudio,
                  onPressed: _isLoadingPageAudio
                      ? null
                      : () => unawaited(_handlePlayPausePressed()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderContent() {
    Widget content = _isPdfMode
        ? _buildPdfView()
        : FutureBuilder<PageData>(
            future: _repository.loadPage(_currentPage, _edition),
            builder: (context, snapshot) {
              final pageData = snapshot.data;
              return Column(
                children: [
                  Expanded(child: _buildPageView()),
                  if (!_isFullscreen) _buildBottomBar(pageData),
                ],
              );
            },
          );

    if (_isFullscreen) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _toggleFullscreenButton,
        onLongPress: _showFullscreenControls,
        child: content,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (_isFullscreen && _fullscreenControlsVisible)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideFullscreenControls,
              child: const SizedBox.expand(),
            ),
          ),
        if (_isFullscreen && _fullscreenControlsVisible)
          _buildFullscreenPlaybackControls(),
        if (_isFullscreen)
          // PositionedDirectional MUST be a direct Stack child — never inside
          // AnimatedSlide/AnimatedOpacity. IgnorePointer is outermost to ensure
          // the invisible full-screen widget never absorbs pointer events.
          PositionedDirectional(
            top: MediaQuery.of(context).viewPadding.top + 10,
            end: 10,
            child: IgnorePointer(
              ignoring: !_fullscreenButtonVisible,
              child: AnimatedSlide(
                offset: _fullscreenButtonVisible
                    ? Offset.zero
                    : const Offset(0, -2.0),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  opacity: _fullscreenButtonVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildFullscreenExitButton(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  TextStyle _arabicTextStyle({
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return ArabicFontUtils.buildTextStyle(
      _arabicFontKey,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      color: color,
    );
  }

  String _resolveReciterCodeForEdition([QuranEdition? edition]) {
    final target = edition ?? _edition;
    switch (target) {
      case QuranEdition.english:
        return 'arabic_english';
      case QuranEdition.french:
        return 'arabic_french';
      case QuranEdition.tafsir:
        return 'muyassar';
      case QuranEdition.simple:
      case QuranEdition.uthmani:
      case QuranEdition.tajweed:
      case QuranEdition.irab:
        return PreferencesService.getReciter();
    }
  }

  void _scheduleScrollToAyah(int ayahNumber,
      {bool immediate = false, int attempt = 0}) {
    // In PDF mode, we don't use the item scrolling logic
    if (_isPdfMode) return;

    if (attempt > 8) return;
    _pendingScrollAyah = ayahNumber;
    final key = _ayahKeys[ayahNumber];
    if (key == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleScrollToAyah(ayahNumber,
            immediate: immediate, attempt: attempt + 1);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final context = key.currentContext;
      if (context == null) {
        _scheduleScrollToAyah(ayahNumber,
            immediate: immediate, attempt: attempt + 1);
        return;
      }
      if (!immediate) {
        await Future.delayed(const Duration(milliseconds: 24));
      }
      if (!mounted) return;
      try {
        if (context.mounted) {
          await Scrollable.ensureVisible(
            context,
            duration:
                immediate ? Duration.zero : const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.2,
          );
        }
        _pendingScrollAyah = null;
      } catch (_) {
        _scheduleScrollToAyah(ayahNumber,
            immediate: immediate, attempt: attempt + 1);
      }
    });
  }

  Future<void> _openPagePicker() async {
    final selected = await showPagePickerSheet(
      context,
      currentPage: _currentPage,
      totalPages: _totalPages,
    );
    if (selected != null) {
      _goToPage(selected);
    }
  }

  Future<void> _openSurahPicker(List<SurahMeta> surahs) async {
    final selected = await showModalBottomSheet<SurahMeta>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SurahPickerSheet(surahs: surahs),
    );

    if (selected != null) {
      final startPage = surahStartPages[selected.number] ?? 1;
      _goToPage(startPage);
    }
  }

  Future<void> _openJuzPicker() async {
    final targetPage = await showJuzPickerSheet(context);
    if (targetPage != null) {
      _goToPage(targetPage);
    }
  }

  Future<void> _toggleEdition(QuranEdition edition) async {
    if (edition == _edition) return;

    if (edition == QuranEdition.irab) {
      final available = await IrabService().isDataAvailable();
      if (!available) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.download),
            content: Text(l10n.irabDataNotAvailable),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.download),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        if (!mounted) return;
        final ValueNotifier<double> downloadProgress = ValueNotifier(0.0);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Expanded(child: Text(l10n.irabDownloading)),
                  ],
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<double>(
                  valueListenable: downloadProgress,
                  builder: (context, value, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(value: value),
                        const SizedBox(height: 8),
                        Text(
                          '${(value * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.end,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );

        try {
          await IrabService().downloadData(
            onProgress: (received, total) {
              if (total != -1) {
                downloadProgress.value = received / total;
              }
            },
          );
          if (mounted) Navigator.pop(context); // Close loading
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.downloadFailed)),
            );
          }
          return;
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(AppLocalizations.of(context)!.irabLoading)),
            ],
          ),
        ),
      );
      final loaded = await IrabService().loadData();
      if (mounted) Navigator.pop(context); // Close loading

      if (!loaded) return;
    }

    _autoFlipGeneration++;
    unawaited(_stopPageAudio());
    PreferencesService.saveLastReadEdition(edition.name);
    setState(() {
      _edition = edition;
      _selectedAyah = null;
      _currentPageData = null;
      _pageCache.clear(); // Clear cache when edition changes
    });
  }

  void _showSettingsSheet() {
    showReaderSettingsSheet(
      context,
      autoFlip: _autoFlip,
      onAutoFlipChanged: (val) {
        if (!mounted) return;
        setState(() => _autoFlip = val);
      },
      isPdfMode: _isPdfMode,
      pdfType: _pdfType,
      onOpenReciterPicker: () {
        SettingsSheetUtils.showReciterSelectionSheet(
          context,
          requireVerseByVerse: true,
          onReciterSelected: (key) {
            PreferencesService.saveReciter(key);
            if (!mounted) return;
            setState(() {
              if (_pageAudioReciter != key) {
                _pageAudioReciter = null;
              }
            });
          },
        );
      },
      onOpenMushafStylePicker: _showMushafStylePicker,
      onFontSizeChanged: () {
        if (!mounted) return;
        setState(() {});
      },
    );
  }

  void _showMushafStylePicker() {
    showMushafStylePickerSheet(
      context,
      currentType: _pdfType,
      onSelected: (type) async {
        if (!mounted) return;
        setState(() {
          _pdfType = type;
          // Reset path so we check availability again or download.
          _pdfPath = null;
          _pdfDocumentFuture = null;
          _pdfPageController = null;
        });
        await PreferencesService.savePdfType(type.name);
        await _checkPdfAvailability();
      },
    );
  }

  Future<void> _openHighlightedAyahsSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final storedHighlightsMap = PreferencesService.getHighlightedAyahs();

    if (mounted &&
        (storedHighlightsMap.length != _highlightedAyahs.length ||
            !_highlightedAyahs.keys
                .toSet()
                .containsAll(storedHighlightsMap.keys))) {
      setState(() {
        _highlightedAyahs
          ..clear()
          ..addAll(storedHighlightsMap);
      });
    }

    if (storedHighlightsMap.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noHighlightsYet)),
        );
      }
      return;
    }

    final ayahNumbers = storedHighlightsMap.keys.toList()..sort();
    final ayahDataList = await Future.wait(
      ayahNumbers
          .map((number) => _repository.lookupAyahByNumber(
                number,
                edition: _edition,
              ))
          .toList(),
    );

    final entries = <HighlightedAyah>[];
    for (var i = 0; i < ayahNumbers.length; i++) {
      final ayah = ayahDataList[i];
      if (ayah != null) {
        entries.add(
          HighlightedAyah(
            ayahNumber: ayahNumbers[i],
            ayah: ayah,
            color: storedHighlightsMap[ayahNumbers[i]] ?? 0xFFFFF7C2,
          ),
        );
      }
    }

    if (entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noHighlightsYet)),
      );
      return;
    }

    entries.sort((a, b) {
      final pageCompare = a.ayah.page.compareTo(b.ayah.page);
      if (pageCompare != 0) return pageCompare;
      return a.ayah.numberInSurah.compareTo(b.ayah.numberInSurah);
    });

    if (!mounted) return;
    final selected = await showHighlightedAyahsSheet(
      context,
      entries: entries,
    );

    if (selected != null && mounted) {
      final page = selected.ayah.page;
      final ayahNumber = selected.ayahNumber;
      final verseInSurah = selected.ayah.numberInSurah;

      _goToPage(page, highlightAyah: ayahNumber);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleScrollToAyah(ayahNumber);
      });

      final theme = Theme.of(context);
      final textDirection =
          _edition.isRtl ? TextDirection.rtl : TextDirection.ltr;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor:
              theme.colorScheme.surface.withAlpha((255 * 0.95).round()),
          content: Text(
            '${selected.ayah.surah.name} • $verseInSurah',
            textDirection: textDirection,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }
  }

  Future<void> _togglePageAudio(PageData page) async {
    if (_isLoadingPageAudio) return;

    if (_pagePlayer.playing) {
      await _pagePlayer.pause();
      if (mounted) {
        setState(() {
          _isPlayingPage = false;
        });
      } else {
        _isPlayingPage = false;
      }
      return;
    }

    final success = await _playSelectedAyah(page: page, showErrors: true);
    if (!success && mounted) {
      setState(() {
        _isPlayingPage = false;
      });
    }
  }

  Future<bool> _playSelectedAyah(
      {PageData? page, bool showErrors = false}) async {
    page ??= _currentPageData;
    if (page == null || page.ayahs.isEmpty) {
      return false;
    }

    final l10n = AppLocalizations.of(context)!;
    final reciterCode = _resolveReciterCodeForEdition();

    // Validate if reciter supports verse-by-verse audio
    final reciter = await ReciterConfigService.getReciterByCode(reciterCode);
    if (reciter != null && !reciter.hasVerseByVerse()) {
      if (showErrors && mounted) {
        final langCode = Localizations.localeOf(context).languageCode;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.reciterNotCompatible),
            content: Text(l10n.reciterNotAvailableForVerses(
                reciter.getDisplayName(langCode))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await SettingsSheetUtils.showReciterSelectionSheet(
                    context,
                    requireVerseByVerse: true,
                    onReciterSelected: (newCode) async {
                      await PreferencesService.saveReciter(newCode);
                      if (mounted) {
                        setState(() {
                          // Trigger re-render or re-computation if needed
                        });
                        // Retry playback
                        _playSelectedAyah(page: page, showErrors: true);
                      }
                    },
                  );
                },
                child: Text(l10n.chooseReciter),
              ),
            ],
          ),
        );
      }
      return false;
    }

    try {
      final prepared = await _preparePageAudio(page, reciterCode);
      if (!prepared) {
        if (showErrors && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.surahUnavailable)),
          );
        }
        return false;
      }

      final selectedAyahNumber = _selectedAyah ?? page.ayahs.first.number;
      final targetAyahIndex =
          page.ayahs.indexWhere((a) => a.number == selectedAyahNumber);
      final safeAyahIndex = targetAyahIndex >= 0 ? targetAyahIndex : 0;

      // Translate ayah-level index → source-level index via the mapping.
      // This handles the case where some audio sources were null and skipped.
      final sourceIndex = _sourceIndexToAyahIndex.indexOf(safeAyahIndex);
      final safeSourceIndex = sourceIndex >= 0 ? sourceIndex : 0;

      final playingAyahNumber = page.ayahs[safeAyahIndex].number;

      await _pagePlayer.seek(Duration.zero, index: safeSourceIndex);
      if (mounted) {
        setState(() {
          _currentAyahIndex = safeSourceIndex;
        });
        _scheduleScrollToAyah(playingAyahNumber);
      } else {
        _currentAyahIndex = safeSourceIndex;
      }
      await _pagePlayer.play();

      if (mounted) {
        setState(() {
          _isPlayingPage = true;
        });
      } else {
        _isPlayingPage = true;
      }

      return true;
    } catch (_) {
      if (showErrors && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorLoadingAudio)),
        );
      }
      if (mounted) {
        setState(() {
          _isPlayingPage = false;
        });
      } else {
        _isPlayingPage = false;
      }
      return false;
    }
  }

  Future<bool> _preparePageAudio(PageData page, String reciterCode) async {
    if (_pageAudioPreparation != null) {
      // Fix 7: If a prior concurrent call failed, catch its error and
      // retry fresh instead of propagating a stale exception.
      try {
        return await _pageAudioPreparation!;
      } catch (_) {
        _pageAudioPreparation = null;
        // Fall through to retry below
      }
    }

    // Fix 2: Use independent _audioSourcePageNumber instead of volatile
    // _currentPageData which can be nulled during page transitions.
    final needsReload = _currentPageAudioSource == null ||
        _pageAudioReciter != reciterCode ||
        _audioSourcePageNumber != page.number;

    if (!needsReload) {
      return true;
    }

    _isLoadingPageAudio = true;

    final completer = Completer<bool>();
    _pageAudioPreparation = completer.future;

    try {
      // Offline handling: if first ayah is not downloaded and no internet, abort early
      try {
        if (page.ayahs.isNotEmpty) {
          final first = page.ayahs.first;
          final hasLocal = await AudioService.isLocalAyahAvailable(
            reciterKeyAr: reciterCode,
            surahOrder: first.surah.number,
            verseNumber: first.numberInSurah,
          );
          final hasNet = await _hasInternet();
          if (!hasLocal && !hasNet) {
            return false;
          }
        }
      } catch (_) {}

      // Fix 3: Build sources + index mapping together so skipped null
      // sources don't break _sequenceStateSub index resolution.
      final result = await buildPageAudioSourcesWithMapping(page, reciterCode);
      if (result.sources.isEmpty) {
        completer.complete(false);
        return false;
      }

      final source = ConcatenatingAudioSource(children: result.sources);
      await _pagePlayer.setAudioSource(
        source,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      _currentPageAudioSource = source;
      _pageAudioReciter = reciterCode;
      _audioSourcePageNumber = page.number;
      _sourceIndexToAyahIndex = result.indexMapping;
      if (mounted) {
        setState(() {
          _currentAyahIndex = 0;
        });
        if (page.ayahs.isNotEmpty) {
          _scheduleScrollToAyah(page.ayahs.first.number, immediate: true);
        }
      } else {
        _currentAyahIndex = 0;
      }
      completer.complete(true);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[ReadQuran] CRITICAL ERROR loading page audio: $error');
      debugPrint('[ReadQuran] Stack trace: $stackTrace');

      // Show debug error dialog
      if (mounted) {
        DebugErrorDisplay.showError(
          context,
          screen: 'Read Quran',
          operation: 'Load Page $_currentPage Audio',
          error: error.toString(),
          stackTrace: stackTrace.toString(),
        );
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        String userMessage = l10n.errorLoadingAudio;

        if (error.toString().contains('Permission')) {
          userMessage =
              'Audio permission required. Please grant permission in settings.';
        } else if (error.toString().contains('Network') ||
            error.toString().contains('Connection')) {
          userMessage = l10n.audioInternetRequired;
        } else if (error.toString().contains('Format') ||
            error.toString().contains('Codec')) {
          userMessage = 'Audio format not supported on this device.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      completer.completeError(error);
      rethrow;
    } finally {
      _isLoadingPageAudio = false;
      _pageAudioPreparation = null;
    }
  }

  Future<bool> _hasInternet() => NetUtils.hasInternet();

  Future<void> _seekToPreviousAyah() async {
    final page = _currentPageData;
    if (page == null) return;

    final reciterCode = _resolveReciterCodeForEdition();
    final l10n = AppLocalizations.of(context)!;

    try {
      final prepared = await _preparePageAudio(page, reciterCode);
      if (!prepared) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.surahUnavailable)),
        );
        return;
      }

      final wasPlaying = _pagePlayer.playing;
      final currentIndex = _pagePlayer.currentIndex ?? _currentAyahIndex ?? 0;
      final targetIndex = currentIndex > 0 ? currentIndex - 1 : 0;
      await _pagePlayer.seek(Duration.zero, index: targetIndex);
      // Map source-level index → ayah-level index via the mapping
      final ayahIdx = (targetIndex < _sourceIndexToAyahIndex.length)
          ? _sourceIndexToAyahIndex[targetIndex]
          : targetIndex;
      final ayahNumber = (ayahIdx >= 0 && ayahIdx < page.ayahs.length)
          ? page.ayahs[ayahIdx].number
          : page.ayahs.first.number;
      if (mounted) {
        setState(() {
          _currentAyahIndex = targetIndex;
          _selectedAyah = ayahNumber;
        });
        _scheduleScrollToAyah(ayahNumber);
      } else {
        _currentAyahIndex = targetIndex;
        _selectedAyah = ayahNumber;
      }
      if (wasPlaying) {
        await _pagePlayer.play();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorLoadingAudio)),
        );
      }
    }
  }

  // Fix 5: When audio is already playing, seek directly instead of
  // re-preparing the entire source (avoids position reset on multi-surah pages).
  void _selectAyah(AyahData ayah) {
    final wasPlaying = _pagePlayer.playing;
    setState(() {
      _selectedAyah = ayah.number;
    });
    _scheduleScrollToAyah(ayah.number);
    if (wasPlaying && _currentPageData != null && _audioSourcePageNumber == _currentPageData!.number) {
      // Source already matches current page — seek only.
      final targetAyahIdx = _currentPageData!.ayahs.indexWhere((a) => a.number == ayah.number);
      if (targetAyahIdx >= 0) {
        // Reverse-lookup: find source index from ayah index
        final sourceIdx = _sourceIndexToAyahIndex.indexOf(targetAyahIdx);
        if (sourceIdx >= 0) {
          unawaited(_pagePlayer.seek(Duration.zero, index: sourceIdx));
          return;
        }
      }
      // Fallback: full replay if mapping lookup fails
      unawaited(_playSelectedAyah(showErrors: false));
    } else if (wasPlaying) {
      unawaited(_playSelectedAyah(showErrors: false));
    }
  }

  Future<void> _stopPageAudio() async {
    _autoFlipGeneration++;
    _isLoadingPageAudio = false;
    _pageAudioPreparation = null;
    try {
      await _pagePlayer.stop();
    } catch (_) {
      // Player already stopped or disposed.
    }
    _currentPageAudioSource = null;
    _pageAudioReciter = null;
    _audioSourcePageNumber = null;
    _sourceIndexToAyahIndex = <int>[];
    _currentAyahIndex = null;

    if (mounted) {
      setState(() {
        _isPlayingPage = false;
      });
    } else {
      _isPlayingPage = false;
    }
  }

  /// Stops audio without incrementing the auto-flip generation counter.
  /// Used exclusively within the auto-flip flow itself.
  Future<void> _stopPageAudioSilent() async {
    _isLoadingPageAudio = false;
    _pageAudioPreparation = null;
    try {
      await _pagePlayer.stop();
    } catch (_) {}
    _currentPageAudioSource = null;
    _pageAudioReciter = null;
    _audioSourcePageNumber = null;
    _sourceIndexToAyahIndex = <int>[];
    _currentAyahIndex = null;
    if (mounted) {
      setState(() {
        _isPlayingPage = false;
      });
    } else {
      _isPlayingPage = false;
    }
  }

  /// Handles auto-flip to [nextPage]. Aborts if the generation counter
  /// has changed (meaning the user interacted).
  Future<void> _handleAutoFlip(int nextPage, int generation) async {
    // Brief delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _autoFlipGeneration != generation) return;

    debugPrint('[ReadQuran] Auto-flip: navigating to page $nextPage');
    _goToPageForAutoFlip(nextPage);

    // Wait for page animation to settle
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _autoFlipGeneration != generation) return;

    try {
      final pageData = await _repository.loadPage(nextPage, _edition);
      if (!mounted || _autoFlipGeneration != generation) return;

      if (mounted) {
        setState(() {
          _currentPageData = pageData;
        });
      }

      debugPrint('[ReadQuran] Auto-flip: playing audio for page $nextPage');
      await _playSelectedAyah(page: pageData, showErrors: false);
    } catch (e) {
      debugPrint('[ReadQuran] Auto-flip error: $e');
    }
  }

  /// Navigates to [page] without incrementing the auto-flip generation.
  void _goToPageForAutoFlip(int page) {
    final target = page.clamp(1, _totalPages);
    _isAutoFlipping = true; // Suppress onPageChanged side-effects
    setState(() {
      _currentPage = target;
      _selectedAyah = null;
      _currentPageData = null;
      _ayahKeys.clear();
    });

    if (_isPdfMode && _pdfPath != null) {
      final offset = MushafPdfService.instance.getPageOffset(_pdfType);
      final targetIndex = (target - 1) + offset;
      if (_pdfPageController?.hasClients == true) {
        _pdfPageController!.jumpToPage(targetIndex);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageScrollController.hasClients) {
          _pageScrollController.jumpTo(0);
        }
      });
      try {
        _pageController.jumpToPage(target - 1);
      } catch (_) {
        _pageController.animateToPage(
          target - 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
    _isAutoFlipping = false;
    PreferencesService.saveLastReadPage(_edition.name, target);
  }

  Future<void> _showAyahOptions(AyahData ayah) async {
    final selection = await showAyahOptionsSheet(
      context,
      ayah: ayah,
      isHighlighted: _highlightedAyahs.containsKey(ayah.number),
      edition: _edition,
    );

    if (selection == null) return;
    if (!mounted) return;

    switch (selection) {
      case AyahAction.pickColor:
        _showColorPicker(ayah);
        break;
      case AyahAction.highlight: // Legacy fallback
        _setAyahHighlight(ayah, 0xFFFFF7C2);
        break;
      case AyahAction.removeHighlight:
        _removeAyahHighlight(ayah);
        break;
      case AyahAction.translateEnglish:
        await _showTranslation(ayah, QuranEdition.english);
        break;
      case AyahAction.translateFrench:
        await _showTranslation(ayah, QuranEdition.french);
        break;
      case AyahAction.translateArabic:
        await _showTranslation(ayah, QuranEdition.simple);
        break;
      case AyahAction.tafsir:
        await _showTafsir(ayah);
        break;
      case AyahAction.share:
        ShareAyahUtils.shareAyahAsText(
          context,
          surah: ayah.surah,
          ayah: ayah,
          isTranslation: _edition.isTranslation,
          reciterIdentifier: _pageAudioReciter,
        );
        break;
    }
  }

  Future<void> _setAyahHighlight(AyahData ayah, int color) async {
    await PreferencesService.saveAyahHighlight(ayah.number, color);
    if (mounted) {
      setState(() {
        _highlightedAyahs[ayah.number] = color;
      });
    }
  }

  Future<void> _removeAyahHighlight(AyahData ayah) async {
    await PreferencesService.removeAyahHighlight(ayah.number);
    if (mounted) {
      setState(() {
        _highlightedAyahs.remove(ayah.number);
      });
    }
  }

  void _showColorPicker(AyahData ayah) {
    showAyahColorPickerSheet(
      context,
      onColorPicked: (colorValue) {
        _setAyahHighlight(ayah, colorValue);
      },
    );
  }

  Future<void> _showTranslation(AyahData ayah, QuranEdition edition) async {
    final l10n = AppLocalizations.of(context)!;
    final text = await _repository.loadAyahTranslation(
      ayahNumber: ayah.number,
      edition: edition,
      pageNumber: ayah.page,
    );

    if (!mounted) return;

    await showAyahTextDialog(
      context,
      title:
          '${edition.displayName} - ${ayah.surah.englishName} ${ayah.numberInSurah}',
      body: text ?? l10n.translationNotAvailable,
    );
  }

  Future<void> _showTafsir(AyahData ayah) async {
    final l10n = AppLocalizations.of(context)!;
    final text = await _repository.loadAyahTafsir(ayah.number);
    if (!mounted) return;
    await showAyahTextDialog(
      context,
      title:
          '${l10n.tafsir} - ${ayah.surah.englishName} ${ayah.numberInSurah}',
      body: text ?? l10n.translationNotAvailable,
    );
  }

  Future<void> _checkPdfAvailability() async {
    final path = await MushafPdfService.instance.getPdfPath(_pdfType);
    final exists = await File(path).exists();
    if (mounted) {
      setState(() {
        if (exists && _pdfPath != path) {
          _pdfDocumentFuture = PdfDocument.openFile(path);
        } else if (!exists) {
          _pdfDocumentFuture = null;
        }
        _pdfPath = exists ? path : null;
      });
    }
  }

  Future<void> _downloadPdf(MushafType type) async {
    final l10n = AppLocalizations.of(context)!;

    // Check if files exist first
    final path = await MushafPdfService.instance.getPdfPath(type);
    final exists = await File(path).exists();

    if (exists) {
      // Just switch
      await PreferencesService.savePdfType(type.id);
      if (mounted) {
        setState(() {
          _pdfType = type;
        });
        await _checkPdfAvailability();
      }
      return;
    }

    // Prepare for download
    // If we are currently viewing a PDF (not the download screen), prompt for confirmation
    if (_pdfPath != null) {
      String typeName;
      switch (type) {
        case MushafType.blue:
          typeName = l10n.mushafTypeBlue;
          break;
        case MushafType.green:
          typeName = l10n.mushafTypeGreen;
          break;
        case MushafType.tajweed:
          typeName = l10n.mushafTypeTajweed;
          break;
      }

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.downloadConfirmation),
          content: Text(l10n.downloadConfirmationMsg(typeName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.download),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      _isDownloadingPdf = true;
      _downloadProgress = 0;
      _downloadCancelToken = CancelToken();
    });

    try {
      await MushafPdfService.instance.downloadMushaf(
        type,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
        cancelToken: _downloadCancelToken,
      );

      // Save the type as chosen ONLY after successful download
      await PreferencesService.savePdfType(type.id);

      if (mounted) {
        setState(() {
          _pdfType = type;
        });
        await _checkPdfAvailability();
      }
    } catch (e) {
      if (mounted && e is DioException && CancelToken.isCancel(e)) {
        // Download cancelled, do nothing
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.downloadFailedReverting)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
          _downloadProgress = null;
          _downloadCancelToken = null;
        });
      }
    }
  }

  void _cancelDownload() {
    _downloadCancelToken?.cancel();
  }

  void _showPdfPageOptions(int page) {
    if (!mounted) return;
    showPdfPageOptionsSheet(
      context,
      isHighlighted: _highlightedPdfPages.contains(page),
      onToggleBookmark: () => _togglePdfPageHighlightParam(page),
    );
  }

  Future<void> _togglePdfPageHighlightParam(int page) async {
    await PreferencesService.togglePdfPageHighlight(page);
    setState(() {
      if (_highlightedPdfPages.contains(page)) {
        _highlightedPdfPages.remove(page);
      } else {
        _highlightedPdfPages.add(page);
      }
    });
  }

  void _openHighlightedPdfPagesSheet() {
    final sortedPages = _highlightedPdfPages.toList()..sort();
    showHighlightedPdfPagesSheet(
      context,
      sortedPages: sortedPages,
      surahListFuture: _surahListFuture,
      onOpenPage: _goToPage,
      onDeletePage: _togglePdfPageHighlightParam,
    );
  }

  Future<void> _togglePdfMode() async {
    final newMode = !_isPdfMode;
    await PreferencesService.saveIsPdfMode(newMode);

    // Stop audio when switching modes
    await _stopPageAudio();

    setState(() {
      _isPdfMode = newMode;
    });

    if (newMode) {
      // Switching TO PDF
      // Dispose old PDF controller to force recreation with correct initial page
      try {
        _pdfPageController?.dispose();
      } catch (_) {}
      _pdfPageController = null;

      await _checkPdfAvailability();
    } else {
      // Switching TO Text
      // Re-create controller with correct initial page to ensure sync without animation jump
      try {
        _pageController.dispose();
      } catch (_) {}
      _pageController = PageController(initialPage: _currentPage - 1);

      // Reset scroll controller for text view
      if (_pageScrollController.hasClients) {
        _pageScrollController.jumpTo(0);
      }
    }
  }

  Widget _buildPdfView() {
    final l10n = AppLocalizations.of(context)!;

    if (_isDownloadingPdf) {
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
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text('${((_downloadProgress ?? 0) * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _cancelDownload,
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_pdfPath == null) {
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
                    String typeName;
                    switch (type) {
                      case MushafType.blue:
                        typeName = l10n.mushafTypeBlue;
                        break;
                      case MushafType.green:
                        typeName = l10n.mushafTypeGreen;
                        break;
                      case MushafType.tajweed:
                        typeName = l10n.mushafTypeTajweed;
                        break;
                    }

                    return ElevatedButton.icon(
                      icon: const Icon(Icons.file_download),
                      label: Text(typeName),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: () => _downloadPdf(type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: _togglePdfMode,
                  child: Text(l10n.returnToTextView),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final offset = MushafPdfService.instance.getPageOffset(_pdfType);

    // Calculate initial index for PageView
    // _currentPage is 1-based Quran page.
    // initialIndex = (_currentPage - 1) + offset.
    final initialIndex = (_currentPage - 1) + offset;

    // We recreate controller only if needed to avoid jumpy behavior,
    // but PageView needs controller with initialPage set correctly on first build.

    // Actually, simply always use the state controller if it exists, or create one.
    _pdfPageController ??= PageController(initialPage: initialIndex);

    if (_pdfPath == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ensure future is initialized if path exists
    if (_pdfDocumentFuture == null && _pdfPath != null) {
      _pdfDocumentFuture = PdfDocument.openFile(_pdfPath!);
    }

    return FutureBuilder<PdfDocument>(
      future: _pdfDocumentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(l10n.errorLoadingPdf,
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        if (_pdfPath != null) {
                          await File(_pdfPath!).delete();
                        }
                      } catch (e) {
                        debugPrint('Error deleting file: $e');
                      }
                      await _checkPdfAvailability();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.deleteAndRetry),
                  )
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final document = snapshot.data!;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: PageView.builder(
            controller: _pdfPageController,
            physics: _isPdfZoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: document.pages.length,
            onPageChanged: (index) {
              final quranPage = (index - offset) + 1;
              if (quranPage >= 1 &&
                  quranPage <= 604 &&
                  _currentPage != quranPage) {
                _autoFlipGeneration++; // Cancel pending auto-flip
                unawaited(_stopPageAudio());
                setState(() {
                  _currentPage = quranPage;
                  _currentPageData = null;
                  _selectedAyah = null;
                });
                PreferencesService.saveLastReadPage(_edition.name, quranPage);
                _repository.loadPage(quranPage, _edition).then((data) {
                  if (mounted && _currentPage == quranPage) {
                    setState(() {
                      _currentPageData = data;
                    });
                  }
                });
              }
            },
            itemBuilder: (context, index) {
              return ZoomablePdfPage(
                document: document,
                pageNumber: index + 1,
                isFullscreen: _isFullscreen,
                mushafType: _pdfType,
                onZoomChanged: (isZoomed) {
                  if (mounted && isZoomed != _isPdfZoomed) {
                    setState(() {
                      _isPdfZoomed = isZoomed;
                    });
                  }
                },
                onLongPress: () {
                  if (_isFullscreen) {
                    _showFullscreenControls();
                    return;
                  }
                  // Calculate Quran page
                  final quranPage = (index - offset) + 1;
                  if (quranPage >= 1 && quranPage <= 604) {
                    _showPdfPageOptions(quranPage);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _totalPages,
      onPageChanged: (index) {
        // During auto-flip, _goToPageForAutoFlip already handles state.
        // Only cancel audio & increment generation on USER-initiated swipes.
        if (!_isAutoFlipping) {
          _autoFlipGeneration++;
          unawaited(_stopPageAudio());
        }
        setState(() {
          _currentPage = index + 1;
          _selectedAyah = null;
          _currentPageData = null;
          _ayahKeys.clear();
        });

        // Save last read page
        PreferencesService.saveLastReadPage(_edition.name, index + 1);
      },
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final cacheKey = '${pageNumber}_${_edition.name}';

        // Check cache first
        if (_pageCache.containsKey(cacheKey)) {
          final cachedData = _pageCache[cacheKey]!;
          if (pageNumber == _currentPage) {
            _currentPageData = cachedData;
            if (_selectedAyah == null && cachedData.ayahs.isNotEmpty) {
              final firstAyahNumber = cachedData.ayahs.first.number;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_selectedAyah != firstAyahNumber) {
                  setState(() {
                    _selectedAyah = firstAyahNumber;
                  });
                }
              });
            }
          }
          // Wrap in RepaintBoundary to isolate repaints
          return RepaintBoundary(
            child: _buildPageContent(cachedData),
          );
        }

        // Load from repository if not cached
        return FutureBuilder<PageData>(
          future: _repository.loadPage(pageNumber, _edition),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              if (pageNumber == _currentPage) {
                _currentPageData = null;
              }
              return const SizedBox.shrink();
            }

            // Cache the loaded page
            _pageCache[cacheKey] = data;

            if (pageNumber == _currentPage) {
              _currentPageData = data;
              if (_selectedAyah == null && data.ayahs.isNotEmpty) {
                final firstAyahNumber = data.ayahs.first.number;
                if (_selectedAyah != firstAyahNumber) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _selectedAyah = firstAyahNumber;
                    });
                    _scheduleScrollToAyah(firstAyahNumber, immediate: true);
                  });
                }
              } else if (_pendingScrollAyah != null) {
                final pending = _pendingScrollAyah!;
                final contains =
                    data.ayahs.any((ayah) => ayah.number == pending);
                if (contains) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scheduleScrollToAyah(pending, immediate: true);
                  });
                }
              }
            }
            // Wrap in RepaintBoundary to isolate repaints
            return RepaintBoundary(
              child: _buildPageContent(data),
            );
          },
        );
      },
    );
  }

  Widget _buildPageContent(PageData page) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textDirection =
        _edition.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final bool isCurrentPage = _currentPageData?.number == page.number;

    final children = <Widget>[];
    for (final occurrence in page.surahOccurrences) {
      final firstAyah = page.ayahs[occurrence.startIndex];

      // Only show header if this is the start of the surah (Ayah 1)
      if (firstAyah.numberInSurah == 1) {
        children.add(_buildSurahHeader(occurrence.surah, colorScheme));

        if (occurrence.surah.number != 1 && occurrence.surah.number != 9) {
          children.add(const BasmalahHeader());
        }
      }

      for (int i = 0; i < occurrence.ayahCount; i++) {
        final globalIndex = occurrence.startIndex + i;
        final ayah = page.ayahs[globalIndex];
        final bool isPlaying = isCurrentPage &&
            _currentAyahIndex != null &&
            globalIndex == _currentAyahIndex;

        String? displayText;
        // Strip Basmalah from first verse text if present
        // Strip Basmalah from first verse text if present
        if (ayah.numberInSurah == 1 &&
            occurrence.surah.number != 1 &&
            occurrence.surah.number != 9) {
          displayText = removeBasmalah(ayah.text.trim());
        }

        children.add(
          _buildAyahTile(
            ayah: ayah,
            displayText: displayText,
            textTheme: textTheme,
            colorScheme: colorScheme,
            textDirection: textDirection,
            isPlaying: isPlaying,
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surfaceContainerHighest.withAlpha((255 * 0.35).round()),
            colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _isFullscreen ? 8 : 12,
            vertical: _isFullscreen ? 8 : 16,
          ),
          child: SingleChildScrollView(
            controller: _pageScrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurahHeader(SurahMeta surah, ColorScheme colorScheme) {
    String? revelationLabelAr;
    String? revelationLabelEn;
    switch (surah.revelationType) {
      case 'Meccan':
        revelationLabelAr = 'مكية';
        revelationLabelEn = 'Meccan';
        break;
      case 'Medinan':
        revelationLabelAr = 'مدنية';
        revelationLabelEn = 'Medinan';
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withAlpha((255 * 0.85).round()),
            colorScheme.primary.withAlpha((255 * 0.65).round()),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha((255 * 0.3).round()),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            revelationLabelAr == null
                ? surah.name
                : '${surah.name} ($revelationLabelAr)',
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            revelationLabelEn == null
                ? '${surah.englishName} • ${surah.englishNameTranslation}'
                : '${surah.englishName} • ${surah.englishNameTranslation} ($revelationLabelEn)',
            style: const TextStyle(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAyahTile({
    required AyahData ayah,
    String? displayText,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required TextDirection textDirection,
    required bool isPlaying,
  }) {
    final GlobalKey itemKey =
        _ayahKeys.putIfAbsent(ayah.number, () => GlobalKey());
    final theme = Theme.of(context);
    final int? highlightColorValue = _highlightedAyahs[ayah.number];
    final bool isHighlighted = highlightColorValue != null;
    final bool isSelected = _selectedAyah == ayah.number;

    final double baseFontSize = _edition.isTranslation
        ? ((PreferencesService.getFontSize() - 4).clamp(12.0, 48.0)).toDouble()
        : PreferencesService.getFontSize();
    final TextStyle baseStyle = _arabicTextStyle(
      fontSize: baseFontSize,
      height: 2.5,
      color: colorScheme.onSurface,
    );
    final TextStyle diacriticStyle =
        baseStyle.copyWith(color: colorScheme.primary);

    final bool isTajweedEdition = _edition == QuranEdition.tajweed;
    final String rawText = displayText ?? ayah.text.trim();
    final List<InlineSpan> ayahContentSpans = isTajweedEdition
        ? TajweedParser.parseSpans(
            rawText,
            baseStyle,
            diacriticStyle: diacriticStyle,
          )
        : TajweedParser.buildPlainSpans(
            rawText,
            baseStyle,
            diacriticStyle: diacriticStyle,
          );

    final Color playingColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2C3C57)
        : const Color(0xFFFFE19C);
    final Color backgroundColor = isPlaying
        ? playingColor
        : isSelected
            ? colorScheme.secondaryContainer.withAlpha((255 * 0.6).round())
            : isHighlighted
                ? Color(highlightColorValue)
                : colorScheme.surface.withAlpha((255 * 0.4).round());
    final Color borderColor = isPlaying || isHighlighted
        ? colorScheme.primary
        : colorScheme.outlineVariant.withAlpha((255 * 0.5).round());
    final List<BoxShadow>? boxShadow = isPlaying
        ? [
            BoxShadow(
              color: colorScheme.primary.withAlpha((255 * 0.25).round()),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
        : null;
    return TweenAnimationBuilder<Color?>(
      key: itemKey,
      tween: ColorTween(end: backgroundColor),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, animatedColor, child) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: animatedColor ?? backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
            boxShadow: boxShadow,
          ),
          child: child,
        );
      },
      child: InkWell(
        onTap: () => _selectAyah(ayah),
        onLongPress: () {
          if (_isFullscreen) {
            _showFullscreenControls();
            return;
          }
          _showAyahOptions(ayah);
        },
        child: Directionality(
          textDirection: textDirection,
          child: Column(
            crossAxisAlignment: textDirection == TextDirection.rtl
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Align(
                alignment: textDirection == TextDirection.rtl
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: _edition == QuranEdition.irab && IrabService().isLoaded
                    ? Wrap(
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IrabVerseWidget(
                            verse: IrabService().getVerse(ayah.surah.number, ayah.numberInSurah) ?? 
                                IrabVerse(surahNumber: ayah.surah.number, verseNumber: ayah.numberInSurah, words: []),
                            fontSize: baseFontSize,
                          ),
                          const SizedBox(width: 8),
                          AyahNumberBadge(
                            number: ayah.numberInSurah,
                            rtl: _edition.isRtl,
                            colorScheme: colorScheme,
                          ),
                        ],
                      )
                    : RichText(
                        textAlign: textDirection == TextDirection.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        textDirection: textDirection,
                        text: TextSpan(
                          style: baseStyle,
                          children: [
                            ...ayahContentSpans,
                            const TextSpan(text: '  '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: AyahNumberBadge(
                                number: ayah.numberInSurah,
                                rtl: _edition.isRtl,
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (_edition.isTranslation)
                Align(
                  alignment: textDirection == TextDirection.rtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    '${ayah.surah.englishName} ${ayah.numberInSurah}',
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                    textAlign: textDirection == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(PageData? page) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final currentJuz = page?.juz ?? 1;
    final surahNames = page == null
        ? ''
        : page.surahOccurrences
            .map((occurrence) => occurrence.surah.name)
            .join(' • ');

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ModernSurfaceCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (kIsWeb)
                IconButton(
                  onPressed: _currentPage > 1
                      ? () => _goToPage(_currentPage - 1)
                      : null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: l10n.previousPage,
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openPagePicker,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${l10n.page} $_currentPage',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.tapToChange,
                        style: textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              if (kIsWeb)
                IconButton(
                  onPressed: _currentPage < _totalPages
                      ? () => _goToPage(_currentPage + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: l10n.nextPage,
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openJuzPicker,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${l10n.juzLabel} $currentJuz',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.tapToChange,
                        style: textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<SurahMeta>>(
                  future: _surahListFuture,
                  builder: (context, snapshot) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: snapshot.hasData
                          ? () => _openSurahPicker(snapshot.data!)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            surahNames.isEmpty ? l10n.surah : surahNames,
                            textDirection: TextDirection.rtl,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.tapToChange,
                            style: textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(arabicFontProvider, (prev, next) {
      if (_arabicFontKey != next) {
        setState(() => _arabicFontKey = next);
      }
    });
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    const showPlayButton = true;

    final screen = _isFullscreen
        ? Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: _buildReaderContent(),
          )
        : ModernPageScaffold(
            title: l10n.readQuran,
            icon: Icons.menu_book_rounded,
            subtitle: _isPdfMode
                ? (l10n.localeName == 'ar'
                    ? 'عرض المصحف مع التنقل السريع والإشارات المرجعية والصوت.'
                    : l10n.localeName == 'fr'
                        ? 'Affichage du mushaf avec navigation rapide, signets et audio.'
                        : 'Mushaf view with quick navigation, bookmarks, and audio.')
                : (l10n.localeName == 'ar'
                    ? 'اقرأ القرآن مع التصفح الذكي والتظليل والصوت وإعدادات العرض.'
                    : l10n.localeName == 'fr'
                        ? 'Lisez le Coran avec navigation intelligente, mise en évidence et audio.'
                        : 'Read the Quran with smart navigation, highlights, and audio.'),
            actions: [
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded),
                tooltip: _fullscreenTooltip(l10n, exiting: false),
                onPressed: () => unawaited(_toggleFullscreen()),
              ),
              if (!kIsWeb)
                IconButton(
                  icon: Icon(_isPdfMode ? Icons.article : Icons.picture_as_pdf),
                  tooltip: _isPdfMode
                      ? l10n.returnToTextView
                      : l10n.downloadMushafPdf,
                  onPressed: _togglePdfMode,
                ),
              if (_isPdfMode)
                IconButton(
                  icon: const Icon(Icons.bookmarks),
                  onPressed: _openHighlightedPdfPagesSheet,
                  tooltip: l10n.bookmarks,
                ),
              if (!_isPdfMode)
                IconButton(
                  icon: const Icon(Icons.bookmark_outline),
                  onPressed: _highlightedAyahs.isEmpty
                      ? null
                      : _openHighlightedAyahsSheet,
                ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => _showSettingsSheet(),
              ),
              if (showPlayButton) ...[
                IconButton(
                  icon: Icon(isRtl ? Icons.skip_next : Icons.skip_previous),
                  tooltip: l10n.previousAyah,
                  onPressed: _isLoadingPageAudio
                      ? null
                      : () => unawaited(_handlePreviousAyahPressed()),
                ),
                IconButton(
                  icon: _isLoadingPageAudio
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        )
                      : Icon(
                          _isPlayingPage
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                  tooltip:
                      _isPlayingPage ? l10n.pausePageAudio : l10n.playPageAudio,
                  onPressed: _isLoadingPageAudio
                      ? null
                      : () => unawaited(_handlePlayPausePressed()),
                ),
              ],
              if (!_isPdfMode)
                PopupMenuButton<QuranEdition>(
                  icon: const Icon(Icons.menu_book_outlined),
                  onSelected: _toggleEdition,
                  itemBuilder: (context) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return QuranEdition.values
                        .map(
                          (edition) => PopupMenuItem<QuranEdition>(
                            value: edition,
                            child: Row(
                              children: [
                                if (edition == _edition)
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: colorScheme.primary,
                                  )
                                else
                                  const SizedBox(width: 18),
                                const SizedBox(width: 8),
                                Text(editionLabel(edition, l10n)),
                              ],
                            ),
                          ),
                        )
                        .toList();
                  },
                ),
              if (_isPdfMode)
                PopupMenuButton<MushafType>(
                  icon: const Icon(Icons.style),
                  tooltip: l10n.chooseStyleToDownload,
                  onSelected: _downloadPdf,
                  itemBuilder: (context) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return MushafType.values.map((type) {
                      String typeName;
                      switch (type) {
                        case MushafType.blue:
                          typeName = l10n.mushafTypeBlue;
                          break;
                        case MushafType.green:
                          typeName = l10n.mushafTypeGreen;
                          break;
                        case MushafType.tajweed:
                          typeName = l10n.mushafTypeTajweed;
                          break;
                      }

                      return PopupMenuItem<MushafType>(
                        value: type,
                        child: Row(
                          children: [
                            if (type == _pdfType)
                              Icon(
                                Icons.check,
                                size: 18,
                                color: colorScheme.primary,
                              )
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 8),
                            Text(typeName),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
            ],
            body: _buildReaderContent(),
            bottomNavigationBar: _isPdfMode
                ? FutureBuilder<PageData>(
                    future: _repository.loadPage(_currentPage, _edition),
                    builder: (context, snapshot) {
                      return _buildBottomBar(snapshot.data);
                    },
                  )
                : null,
          );

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) async {
        await _handlePopInvoked(didPop);
      },
      child: screen,
    );
  }
}
