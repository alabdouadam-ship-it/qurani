import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qurani/services/media_item_compat.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_constants.dart';
import 'package:qurani/services/quran_repository.dart';
import 'util/arabic_font_utils.dart';
import 'util/tajweed_parser.dart';
import 'util/text_normalizer.dart';
import 'services/net_utils.dart';
import 'util/debug_error_display.dart';

import 'package:pdfrx/pdfrx.dart';
import 'package:qurani/services/mushaf_pdf_service.dart';
import 'package:dio/dio.dart'; // For CancelToken if needed

import 'responsive_config.dart';
import 'util/settings_sheet_utils.dart';
import 'services/reciter_config_service.dart';

class ReadQuranScreen extends StatefulWidget {
  const ReadQuranScreen({super.key});

  @override
  State<ReadQuranScreen> createState() => _ReadQuranScreenState();
}

class _ReadQuranScreenState extends State<ReadQuranScreen> {
  static const int _totalPages = 604;

  final QuranRepository _repository = QuranRepository.instance;
  late final PageController _pageController;

  int _currentPage = 1;
  QuranEdition _edition = QuranEdition.simple;
  final Set<int> _highlightedAyahs = <int>{};
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
  final Map<String, PageData> _pageCache = <String, PageData>{}; // Cache for loaded pages

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
    _highlightedAyahs.addAll(PreferencesService.getHighlightedAyahs());
    _arabicFontKey = PreferencesService.getArabicFontFamily();
    _autoFlip = PreferencesService.getAutoFlipPage();
    PreferencesService.arabicFontNotifier.addListener(_onArabicFontChanged);
    
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

    _pagePlayer = AudioPlayer();
    _playerStateSub = _pagePlayer.playerStateStream.listen((state) {
      final completed =
          state.processingState == ProcessingState.completed;
      final isPlaying = state.playing && !completed;
      if (mounted) {
        setState(() {
          _isPlayingPage = isPlaying;
        });
      } else {
        _isPlayingPage = isPlaying;
      }
      if (completed) {
        debugPrint('[ReadQuran] Audio completed on page $_currentPage, autoFlip: $_autoFlip');
        if (_autoFlip && _currentPage < _totalPages && mounted) {
          // Store the next page BEFORE any async operations
          final nextPage = _currentPage + 1;
          debugPrint('[ReadQuran] Auto-flipping from $_currentPage to $nextPage');
          
          // Stop current audio before flipping
          unawaited(_stopPageAudio());
          
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;
            
            debugPrint('[ReadQuran] Calling _goToPage($nextPage)');
            _goToPage(nextPage);
            
            // Wait for page to load and onPageChanged to complete
            await Future.delayed(const Duration(milliseconds: 500));
            
            if (!mounted) return;
            
            // Load and play audio for the next page
            try {
              debugPrint('[ReadQuran] Loading audio for page $nextPage');
              final pageData = await _repository.loadPage(nextPage, _edition);
              if (mounted) {
                debugPrint('[ReadQuran] Playing audio for page $nextPage');
                await _playSelectedAyah(page: pageData, showErrors: false);
              }
            } catch (e) {
              debugPrint('[ReadQuran] Error loading next page audio: $e');
            }
          });
        } else {
          unawaited(_stopPageAudio());
        }
      }
    });
     _sequenceStateSub =
        _pagePlayer.sequenceStateStream.listen((sequenceState) {
      if (!mounted) return; // Prevent processing if widget disposed
      
      final index = sequenceState?.currentIndex;
      final page = _currentPageData;
      int? ayahNumber;
      if (index != null && page != null && index >= 0 && index < page.ayahs.length) {
        ayahNumber = page.ayahs[index].number;
      }
      if (mounted) {
        setState(() {
          _currentAyahIndex = index;
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
    PreferencesService.arabicFontNotifier.removeListener(_onArabicFontChanged);
    _playerStateSub?.cancel();
    _sequenceStateSub?.cancel();
    
    // Dispose player safely
    try {
      _pagePlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing audio player: $e');
    }
    _pageController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  void _goToPage(int page, {int? highlightAyah}) {
    final target = page.clamp(1, _totalPages);
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



  void _onArabicFontChanged() {
    if (!mounted) return;
    setState(() {
      _arabicFontKey = PreferencesService.getArabicFontFamily();
    });
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
            duration: immediate ? Duration.zero : const Duration(milliseconds: 350),
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
    final l10n = AppLocalizations.of(context)!;
    final initialIndex = _currentPage - 1;
    final textController = TextEditingController(text: _currentPage.toString());
    
    final selected = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        int tempIndex = initialIndex;
        return SafeArea(
          child: SizedBox(
            height: 380, // Fixed height to prevent overflow
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.goToPage,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                // Text field for direct input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: TextField(
                    controller: textController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                    decoration: InputDecoration(
                      labelText: l10n.pageNumber,
                      hintText: '1-$_totalPages',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final page = int.tryParse(value);
                      if (page != null && page >= 1 && page <= _totalPages) {
                        tempIndex = page - 1;
                      }
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(height: 1),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 200,
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController:
                        FixedExtentScrollController(initialItem: initialIndex),
                    onSelectedItemChanged: (value) {
                      tempIndex = value;
                      textController.text = (value + 1).toString();
                    },
                    children: List.generate(
                      _totalPages,
                      (i) => Center(
                        child: Text(
                          '${i + 1}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () {
                          final page = int.tryParse(textController.text);
                          if (page != null && page >= 1 && page <= _totalPages) {
                            Navigator.pop<int>(context, page);
                          } else {
                            Navigator.pop<int>(context, tempIndex + 1);
                          }
                        },
                        child: Text(l10n.go),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    textController.dispose();
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
      builder: (context) => _SurahPickerSheet(surahs: surahs),
    );

    if (selected != null) {
      final startPage = surahStartPages[selected.number] ?? 1;
      _goToPage(startPage);
    }
  }

  Future<void> _openJuzPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final entries = juzStartPages.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final selected = await showModalBottomSheet<MapEntry<int, int>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                l10n.chooseJuz,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      title: Text('${l10n.juzLabel} ${entry.key}'),
                      subtitle: Text('${l10n.page} ${entry.value}'),
                      onTap: () => Navigator.pop(context, entry),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: entries.length,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      _goToPage(selected.value);
    }
  }

  void _toggleEdition(QuranEdition edition) {
    if (edition == _edition) return;
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
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.settings,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(l10n.readAutoFlip),
                      subtitle: Text(l10n.readAutoFlipDesc),
                      trailing: Switch(
                        value: _autoFlip,
                        onChanged: (val) async {
                          setSheetState(() => _autoFlip = val);
                          setState(() => _autoFlip = val);
                          await PreferencesService.saveAutoFlipPage(val);
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: Text(l10n.startAtLastPage),
                      subtitle: Text(l10n.startAtLastPageDesc),
                      trailing: Switch(
                        value: PreferencesService.getStartAtLastPage(),
                        onChanged: (val) async {
                           setSheetState(() {});
                           await PreferencesService.saveStartAtLastPage(val);
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: Text(l10n.chooseReciter),
                      subtitle: Text(
                        AudioService.reciterDisplayName(
                          PreferencesService.getReciter(),
                          l10n.localeName,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                         Navigator.pop(context);
                         SettingsSheetUtils.showReciterSelectionSheet(
                             context,
                             onReciterSelected: (key) {
                               PreferencesService.saveReciter(key);
                               setState(() {
                                 if (_pageAudioReciter != key) {
                                    _pageAudioReciter = null;
                                 }
                               });
                             }
                         );
                      },
                    ),
                    if (_isPdfMode) ...[
                      const Divider(),
                      ListTile(
                        title: Text(l10n.mushafStyle),
                        subtitle: Text(
                          _pdfType == MushafType.blue ? l10n.mushafTypeBlue :
                          _pdfType == MushafType.green ? l10n.mushafTypeGreen :
                          l10n.mushafTypeTajweed
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          _showMushafStylePicker();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMushafStylePicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
             padding: const EdgeInsets.symmetric(vertical: 16),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text(
                   l10n.mushafStyle,
                   style: Theme.of(context).textTheme.titleLarge,
                 ),
                 const SizedBox(height: 16),
                 ...MushafType.values.map((type) {
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
                   
                   return ListTile(
                     title: Text(typeName),
                     trailing: _pdfType == type ? const Icon(Icons.check, color: Colors.green) : null,
                     onTap: () async {
                       Navigator.pop(context);
                       if (_pdfType != type) {
                         setState(() {
                           _pdfType = type;
                           // Reset path so we check availability again or download
                           _pdfPath = null;
                           _pdfDocumentFuture = null;
                           _pdfPageController = null;
                         });
                         await PreferencesService.savePdfType(type.name);
                         await _checkPdfAvailability();
                       }
                     },
                   );
                 }),
               ],
             ),
          ),
        );
      },
    );
  }

  Future<void> _openHighlightedAyahsSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final storedHighlights = PreferencesService.getHighlightedAyahs();

    if (mounted &&
        (storedHighlights.length != _highlightedAyahs.length ||
            !_highlightedAyahs.containsAll(storedHighlights))) {
      setState(() {
        _highlightedAyahs
          ..clear()
          ..addAll(storedHighlights);
      });
    }

    if (storedHighlights.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noHighlightsYet)),
        );
      }
      return;
    }

    final ayahNumbers = storedHighlights.toList()..sort();
    final ayahDataList = await Future.wait(
      ayahNumbers
          .map((number) => _repository.lookupAyahByNumber(
                number,
                edition: _edition,
              ))
          .toList(),
    );

    final entries = <_HighlightedAyah>[];
    for (var i = 0; i < ayahNumbers.length; i++) {
      final ayah = ayahDataList[i];
      if (ayah != null) {
        entries.add(
          _HighlightedAyah(
            ayahNumber: ayahNumbers[i],
            ayah: ayah,
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
    final selected = await showModalBottomSheet<_HighlightedAyah>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final height = ((MediaQuery.of(context).size.height * 0.6)
            .clamp(320.0, 520.0)).toDouble();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    l10n.highlightedAyahs,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary
                                .withAlpha((255 * 0.1).round()),
                            foregroundColor: theme.colorScheme.primary,
                            child: Text(
                              entry.ayah.numberInSurah.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            entry.ayah.surah.name,
                            textDirection: TextDirection.rtl,
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            '${entry.ayah.surah.englishName} • ${l10n.page} ${entry.ayah.page}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, entry),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      final textDirection = _edition.isRtl ? TextDirection.rtl : TextDirection.ltr;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: theme.colorScheme.surface.withAlpha((255 * 0.95).round()),
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

  Future<bool> _playSelectedAyah({PageData? page, bool showErrors = false}) async {
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.reciterNotCompatible),
            content: Text(l10n.reciterNotAvailableForVerses(reciter.getDisplayName(PreferencesService.getLanguage()))),
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
      final targetIndex = page.ayahs.indexWhere((a) => a.number == selectedAyahNumber);
      final safeIndex = targetIndex >= 0 ? targetIndex : 0;

      final playingAyahNumber = page.ayahs[safeIndex].number;

      await _pagePlayer.seek(Duration.zero, index: safeIndex);
      if (mounted) {
        setState(() {
          _currentAyahIndex = safeIndex;
        });
        _scheduleScrollToAyah(playingAyahNumber);
      } else {
        _currentAyahIndex = safeIndex;
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
      return _pageAudioPreparation!;
    }

    final needsReload = _currentPageAudioSource == null ||
        _pageAudioReciter != reciterCode ||
        (_currentPageData?.number ?? -1) != page.number;

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

      final sources = await _buildPageAudioSources(page, reciterCode);
      if (sources.isEmpty) {
        completer.complete(false);
        return false;
      }

      final source = ConcatenatingAudioSource(children: sources);
      await _pagePlayer.setAudioSource(
        source,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      _currentPageAudioSource = source;
      _pageAudioReciter = reciterCode;
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
          userMessage = 'Audio permission required. Please grant permission in settings.';
        } else if (error.toString().contains('Network') || error.toString().contains('Connection')) {
          userMessage = l10n.audioInternetRequired;
        } else if (error.toString().contains('Format') || error.toString().contains('Codec')) {
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
      final ayahNumber = page.ayahs[targetIndex].number;
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

  void _selectAyah(AyahData ayah) {
    final wasPlaying = _pagePlayer.playing;
    setState(() {
      _selectedAyah = ayah.number;
    });
    _scheduleScrollToAyah(ayah.number);
    if (wasPlaying) {
      unawaited(_playSelectedAyah(showErrors: false));
    }
  }

  Future<void> _stopPageAudio() async {
    _isLoadingPageAudio = false;
    _pageAudioPreparation = null;
    try {
      await _pagePlayer.stop();
    } catch (_) {
      // Player already stopped or disposed.
    }
    _currentPageAudioSource = null;
    _pageAudioReciter = null;
    _currentAyahIndex = null;

    if (mounted) {
      setState(() {
        _isPlayingPage = false;
      });
    } else {
      _isPlayingPage = false;
    }
  }

  void _toggleHighlight(AyahData ayah) async {
    setState(() {
      if (_highlightedAyahs.contains(ayah.number)) {
        _highlightedAyahs.remove(ayah.number);
      } else {
        _highlightedAyahs.add(ayah.number);
      }
    });
    await PreferencesService.toggleAyahHighlight(ayah.number);
  }

  Future<void> _showAyahOptions(AyahData ayah) async {
    final l10n = AppLocalizations.of(context)!;
    final isHighlighted = _highlightedAyahs.contains(ayah.number);
    final selection = await showModalBottomSheet<_AyahAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(
                  isHighlighted ? Icons.bookmark_remove : Icons.bookmark_add,
                ),
                title: Text(
                  isHighlighted ? l10n.removeHighlight : l10n.addHighlight,
                ),
                onTap: () => Navigator.pop(
                  context,
                  isHighlighted
                      ? _AyahAction.removeHighlight
                      : _AyahAction.highlight,
                ),
              ),
              if (_edition == QuranEdition.english ||
                  _edition == QuranEdition.french)
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.showArabicText),
                  onTap: () =>
                      Navigator.pop(context, _AyahAction.translateArabic),
                ),
              if (_edition != QuranEdition.english)
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(l10n.showEnglishTranslation),
                  onTap: () =>
                      Navigator.pop(context, _AyahAction.translateEnglish),
                ),
              if (_edition != QuranEdition.french)
                ListTile(
                  leading: const Icon(Icons.g_translate),
                  title: Text(l10n.showFrenchTranslation),
                  onTap: () =>
                      Navigator.pop(context, _AyahAction.translateFrench),
                ),
              if (!_edition.isTranslation && !_edition.isTafsir)
                ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: Text(l10n.showTafsir),
                  onTap: () => Navigator.pop(context, _AyahAction.tafsir),
                ),
            ],
          ),
        );
      },
    );

    switch (selection) {
      case _AyahAction.highlight:
        _toggleHighlight(ayah);
        break;
      case _AyahAction.removeHighlight:
        _toggleHighlight(ayah);
        break;
      case _AyahAction.translateEnglish:
        await _showTranslation(ayah, QuranEdition.english);
        break;
      case _AyahAction.translateFrench:
        await _showTranslation(ayah, QuranEdition.french);
        break;
      case _AyahAction.translateArabic:
        await _showTranslation(ayah, QuranEdition.simple);
        break;
      case _AyahAction.tafsir:
        await _showTafsir(ayah);
        break;
      case null:
        break;
    }
  }

  Future<void> _showTranslation(AyahData ayah, QuranEdition edition) async {
    final l10n = AppLocalizations.of(context)!;
    final text = await _repository.loadAyahTranslation(
      ayahNumber: ayah.number,
      edition: edition,
      pageNumber: ayah.page,
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${edition.displayName} - ${ayah.surah.englishName} ${ayah.numberInSurah}',
          ),
          content: SingleChildScrollView(
            child: Text(text ?? l10n.translationNotAvailable),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTafsir(AyahData ayah) async {
    final l10n = AppLocalizations.of(context)!;
    final text = await _repository.loadAyahTafsir(ayah.number);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${l10n.tafsir} - ${ayah.surah.englishName} ${ayah.numberInSurah}',
          ),
          content: SingleChildScrollView(
            child: Text(text ?? l10n.translationNotAvailable),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        );
      },
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
      
      // Save the type as chosen
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
          SnackBar(content: Text('Download failed: ${e.toString()}')),
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

  Future<void> _togglePdfMode() async {
    final newMode = !_isPdfMode;
    await PreferencesService.saveIsPdfMode(newMode);
    setState(() {
      _isPdfMode = newMode;
    });
    
    if (newMode) {
      await _checkPdfAvailability();
      // Wait for build then jump
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Offset logic handled in initialPageNumber
      });
    }
  }

  Widget _buildPdfView() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_isDownloadingPdf) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.downloadingMushaf, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_for_offline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(l10n.downloadMushafPdf, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(l10n.chooseStyleToDownload, style: const TextStyle(color: Colors.grey)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    

    if (_pdfPath == null) return const Center(child: CircularProgressIndicator());
    
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
                   Text(l10n.errorLoadingPdf, style: const TextStyle(fontSize: 18)),
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
            physics: _isPdfZoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            itemCount: document.pages.length,
            onPageChanged: (index) {
               final quranPage = (index - offset) + 1;
               if (quranPage >= 1 && quranPage <= 604 && _currentPage != quranPage) {
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
             return _ZoomablePdfPage(
               document: document,
               pageNumber: index + 1,
               onZoomChanged: (isZoomed) {
                 if (mounted && isZoomed != _isPdfZoomed) {
                    setState(() {
                      _isPdfZoomed = isZoomed;
                    });
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
        unawaited(_stopPageAudio());
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
      children.add(_buildSurahHeader(occurrence.surah, colorScheme));
      for (int i = 0; i < occurrence.ayahCount; i++) {
        final globalIndex = occurrence.startIndex + i;
        final ayah = page.ayahs[globalIndex];
        final bool isPlaying =
            isCurrentPage && _currentAyahIndex != null && globalIndex == _currentAyahIndex;
        children.add(
          _buildAyahTile(
            ayah: ayah,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required TextDirection textDirection,
    required bool isPlaying,
  }) {
    final GlobalKey itemKey =
        _ayahKeys.putIfAbsent(ayah.number, () => GlobalKey());
    final theme = Theme.of(context);
    final bool isHighlighted = _highlightedAyahs.contains(ayah.number);
    final bool isSelected = _selectedAyah == ayah.number;

    final double baseFontSize = _edition.isTranslation
        ? ((PreferencesService.getFontSize() - 4).clamp(12.0, 48.0)).toDouble()
        : PreferencesService.getFontSize();
    final TextStyle baseStyle = _arabicTextStyle(
      fontSize: baseFontSize,
      height: 1.6,
      color: colorScheme.onSurface,
    );
    final TextStyle diacriticStyle =
        baseStyle.copyWith(color: colorScheme.primary);

    final bool isTajweedEdition = _edition == QuranEdition.tajweed;
    final String rawText = ayah.text.trim();
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

    const Color highlightColor = Color(0xFFFFF7C2);
    final Color playingColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2C3C57)
        : const Color(0xFFFFE19C);
    final Color backgroundColor = isPlaying
        ? playingColor
        : isSelected
            ? colorScheme.secondaryContainer.withAlpha((255 * 0.6).round())
            : isHighlighted
                ? highlightColor
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
        onLongPress: () => _showAyahOptions(ayah),
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
                child: RichText(
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
                        child: _AyahNumberBadge(
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
                      color: colorScheme.onSurface.withAlpha((255 * 0.6).round()),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentJuz = page?.juz ?? 1;
    final surahNames = page == null
        ? ''
        : page.surahOccurrences
            .map((occurrence) => occurrence.surah.name)
            .join(' • ');

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.06).round()),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous button (web only)
            if (kIsWeb)
              IconButton(
                onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
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
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            // Next button (web only)
            if (kIsWeb)
              IconButton(
                onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
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
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
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
    );
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    const showPlayButton = true;
    
    // In full screen PDF mode, we hide the AppBar and the BottomBar


    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
        actions: [
          IconButton(
            // Changed icon to differentiate from Editions menu
            icon: Icon(_isPdfMode ? Icons.article : Icons.picture_as_pdf),
            tooltip: _isPdfMode ? l10n.returnToTextView : l10n.downloadMushafPdf,
            onPressed: _togglePdfMode,
          ),
          if (!_isPdfMode)
            IconButton(
              icon: const Icon(Icons.bookmark_outline),
              onPressed: _highlightedAyahs.isEmpty
                  ? null
                  : _openHighlightedAyahsSheet,
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(),
          ),
          if (showPlayButton) ...[
            IconButton(
              icon: Icon(isRtl ? Icons.skip_next : Icons.skip_previous),
              tooltip: l10n.previousAyah,
              onPressed: _isLoadingPageAudio
                  ? null
                  : () async {
                     // Check if we need to load data first
                     if (_currentPageData == null) {
                        setState(() { _isLoadingPageAudio = true; });
                        try {
                          final data = await _repository.loadPage(_currentPage, _edition);
                          if (!mounted) return;
                          
                          setState(() {
                             _currentPageData = data;
                             _isLoadingPageAudio = false;
                          });
                          await _seekToPreviousAyah();
                        } catch (e) {
                          if (mounted) setState(() { _isLoadingPageAudio = false; });
                        }
                     } else {
                       await _seekToPreviousAyah();
                     }
                  },
            ),
            IconButton(
              icon: _isLoadingPageAudio
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Icon(
                      _isPlayingPage
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
              tooltip: _isPlayingPage
                  ? l10n.pausePageAudio
                  : l10n.playPageAudio,
              onPressed: _isLoadingPageAudio
                  ? null
                  : () async {
                      if (_currentPageData != null) {
                        await _togglePageAudio(_currentPageData!);
                      } else {
                        // Lazy load data for PDF mode
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
                           await _togglePageAudio(data);
                        } catch (e) {
                           if (!mounted) return;
                           setState(() {
                             _isLoadingPageAudio = false;
                           });
                           ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Error loading audio data: $e')),
                           );
                        }
                      }
                  },
            ),
          ],
          if (!_isPdfMode) // Only show Editions menu in Text Mode
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
                          Text(_editionLabel(edition, l10n)),
                        ],
                      ),
                    ),
                  )
                    .toList();
              },
            ),
        ],
      ),
      body: Stack(
        children: [
           // Body Content
           if (_isPdfMode)
             _buildPdfView()
           else
             FutureBuilder<PageData>(
                future: _repository.loadPage(_currentPage, _edition),
                builder: (context, snapshot) {
                  // We also need to update _currentPageData for Audio playback context if possible
                  // But in text mode, this is handled by _buildPageView Logic?
                  // Actually the original code had FutureBuilder wrapping the whole body.
                  // The _buildPageView used to load pages individually?
                  // Wait, original code:
                  // body: FutureBuilder<PageData>(... builder: (ctx, snap) { return Column(Expanded(child: _buildPageView()), _buildBottomBar(snap.data)); })
                  // _buildPageView() uses PageView.builder which fetches pages independently.
                  // The FutureBuilder in body was used MAINLY to get data for the BottomBar (Juz/Hizb info for current page)?
                  // AND to initialize _currentPageData?
                  // Let's check _buildPageView again. It has its own FutureBuilder inside itemBuilder!
                  // So the outer FutureBuilder is largely for the BottomBar.
                  // So separating them is correct.
                  
                  // However, we need to handle "Loading" state?
                  // Just show empty or previous?
                  final pageData = snapshot.data;
                  return Column(
                    children: [
                      Expanded(child: _buildPageView()),
                      _buildBottomBar(pageData),
                    ],
                  );
                },
             ),
             
           // we handle BottomBar for PDF mode separately?
           // Or can we merge?
        ],
      ),
      bottomNavigationBar: _isPdfMode
          ? FutureBuilder<PageData>(
              future: _repository.loadPage(_currentPage, _edition),
              builder: (context, snapshot) {
                 return _buildBottomBar(snapshot.data);
              },
            )
          : null,
    );
  }
}

class _SurahPickerSheet extends StatefulWidget {
  final List<SurahMeta> surahs;

  const _SurahPickerSheet({required this.surahs});

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      setState(() {
        _query = TextNormalizer.normalize(_controller.text);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    final filtered = _query.isEmpty
        ? widget.surahs
        : widget.surahs.where((s) {
            final normalizedEnglishName =
                TextNormalizer.normalize(s.englishName);
            final normalizedEnglishTranslation =
                TextNormalizer.normalize(s.englishNameTranslation);
            final normalizedArabicName = TextNormalizer.normalize(s.name);
            final numberText = s.number.toString();
            return normalizedEnglishName.contains(_query) ||
                normalizedEnglishTranslation.contains(_query) ||
                normalizedArabicName.contains(_query) ||
                numberText.contains(_query);
          }).toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                l10n.chooseSurah,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final surah = filtered[index];
                    final startPage = surahStartPages[surah.number] ?? 1;
                    return ListTile(
                      title: Text(
                        surah.name,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 18),
                      ),
                      subtitle: Text(
                        '${surah.number}. ${surah.englishName} • ${l10n.page} $startPage',
                      ),
                      onTap: () => Navigator.pop(context, surah),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: filtered.length,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _AyahNumberBadge extends StatelessWidget {
  const _AyahNumberBadge({
    required this.number,
    required this.rtl,
    required this.colorScheme,
  });

  final int number;
  final bool rtl;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final content = number.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary),
        color: colorScheme.primary.withAlpha((255 * 0.1).round()),
      ),
      child: Text(
        content,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class _HighlightedAyah {
  const _HighlightedAyah({
    required this.ayahNumber,
    required this.ayah,
  });

  final int ayahNumber;
  final AyahData ayah;
}

enum _AyahAction {
  highlight,
  removeHighlight,
  translateArabic,
  translateEnglish,
  translateFrench,
  tafsir,
}

String _editionLabel(QuranEdition edition, AppLocalizations l10n) {
  switch (edition) {
    case QuranEdition.simple:
      return '${l10n.arabic} (${l10n.simple})';
    case QuranEdition.uthmani:
      return '${l10n.arabic} (${l10n.uthmani})';
    case QuranEdition.tajweed:
      return l10n.editionArabicTajweed;
    case QuranEdition.english:
      return l10n.english;
    case QuranEdition.french:
      return l10n.french;
    case QuranEdition.tafsir:
      return l10n.tafsir;
  }
}

Future<List<AudioSource>> _buildPageAudioSources(
    PageData page,
    String reciterCode,
    ) async {
  final sources = <AudioSource>[];
  final langCode = PreferencesService.getLanguage();
  final reciterName = AudioService.reciterDisplayName(reciterCode, langCode);

  for (final ayah in page.ayahs) {
    final mediaItem = MediaItem(
        id: '${reciterCode}_${ayah.surah.number}_${ayah.numberInSurah}',
        title: '${ayah.surah.name} • ${ayah.numberInSurah}',
        album: reciterName,
        artUri: null,
        extras: {
          'surahOrder': ayah.surah.number,
          'verse': ayah.numberInSurah,
          'page': page.number,
        },
      );
    final src = await AudioService.buildVerseAudioSource(
      reciterKeyAr: reciterCode,
      surahOrder: ayah.surah.number,
      verseNumber: ayah.numberInSurah,
      mediaItem: mediaItem,
    );
    if (src != null) sources.add(src);
  }
  return sources;
}

class _ZoomablePdfPage extends StatefulWidget {
  final PdfDocument document;
  final int pageNumber;
  final ValueChanged<bool>? onZoomChanged;

  const _ZoomablePdfPage({
    // super.key,  // Unused parameter
    required this.document,
    required this.pageNumber,
    this.onZoomChanged,
  });

  @override
  State<_ZoomablePdfPage> createState() => _ZoomablePdfPageState();
}

class _ZoomablePdfPageState extends State<_ZoomablePdfPage> with AutomaticKeepAliveClientMixin {
  final TransformationController _transformationController = TransformationController();
  
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ZoomablePdfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset transformation when page number changes
    if (oldWidget.pageNumber != widget.pageNumber) {
      // Use post-frame callback to ensure the widget tree is stable
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transformationController.value = Matrix4.identity();
          // Notify that we're no longer zoomed
          if (widget.onZoomChanged != null) {
            widget.onZoomChanged!(false);
          }
        }
      });
    }
  }

  void _checkZoomState() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (widget.onZoomChanged != null) {
      widget.onZoomChanged!(isZoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Get screen orientation
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    // In landscape, scale up the PDF to make it more readable
    final double scale = isLandscape ? 2.8 : 1.0;
    
    return GestureDetector(
      onDoubleTap: () {
        final currentScale = _transformationController.value.getMaxScaleOnAxis();
        
        if (currentScale > 1.5) {
          // Zoom out to normal
          _transformationController.value = Matrix4.identity();
        } else {
          // Zoom in to 2.5x, positioned at top-right for RTL content
          const targetScale = 2.5;
          
          // Get the render box to calculate positioning
          final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final size = renderBox.size;
            
            // For RTL content, we want to show the top-right corner
            // Calculate the translation needed to show top-right
            final xTranslation = -(size.width * (targetScale - 1));
            const yTranslation = 0.0;
            
            _transformationController.value = Matrix4.identity()
              ..translate(xTranslation, yTranslation)
              ..scale(targetScale);
          } else {
            // Fallback if renderBox is null
            _transformationController.value = Matrix4.identity()..scale(targetScale);
          }
        }
        
        _checkZoomState();
      },
      child: Container(
        color: Colors.white,
        child: isLandscape
            ? InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.5,
                maxScale: 4.0,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionUpdate: (_) => _checkZoomState(),
                onInteractionEnd: (_) => _checkZoomState(),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: PdfPageView(
                    document: widget.document,
                    pageNumber: widget.pageNumber,
                    alignment: Alignment.center,
                  ),
                ),
              )
            : InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 1.0,
                maxScale: 4.0,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionUpdate: (_) => _checkZoomState(),
                onInteractionEnd: (_) => _checkZoomState(),
                child: PdfPageView(
                  document: widget.document,
                  pageNumber: widget.pageNumber,
                  alignment: Alignment.center,
                ),
              ),
      ),
    );
  }
}
