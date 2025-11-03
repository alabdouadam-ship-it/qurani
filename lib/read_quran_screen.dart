import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_constants.dart';
import 'package:qurani/services/quran_repository.dart';
import 'util/arabic_font_utils.dart';

import 'responsive_config.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage - 1);
    _surahListFuture = _repository.loadAllSurahs();
    _highlightedAyahs.addAll(PreferencesService.getHighlightedAyahs());
    _arabicFontKey = PreferencesService.getArabicFontFamily();
    PreferencesService.arabicFontNotifier.addListener(_onArabicFontChanged);
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
        unawaited(_stopPageAudio());
      }
    });
    _sequenceStateSub =
        _pagePlayer.sequenceStateStream.listen((sequenceState) {
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
      } else {
        _currentAyahIndex = index;
        if (ayahNumber != null) {
          _selectedAyah = ayahNumber;
        }
      }
    });
  }

  @override
  void dispose() {
    PreferencesService.arabicFontNotifier.removeListener(_onArabicFontChanged);
    _playerStateSub?.cancel();
    _sequenceStateSub?.cancel();
    _pagePlayer.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageScrollController.hasClients) {
        _pageScrollController.jumpTo(0);
      }
      if (highlightAyah != null) {
        _scheduleScrollToAyah(highlightAyah, immediate: true);
      }
    });
    _pageController.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
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
        return 'arabic-english';
      case QuranEdition.french:
        return 'arabic-french';
      case QuranEdition.tafsir:
        return 'muyassar';
      case QuranEdition.simple:
      case QuranEdition.uthmani:
      default:
        return PreferencesService.getReciter();
    }
  }

  void _scheduleScrollToAyah(int ayahNumber,
      {bool immediate = false, int attempt = 0}) {
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
        await Scrollable.ensureVisible(
          context,
          duration: immediate ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.2,
        );
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
    final selected = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        int tempIndex = initialIndex;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.goToPage,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 200,
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController:
                      FixedExtentScrollController(initialItem: initialIndex),
                  onSelectedItemChanged: (value) {
                    tempIndex = value;
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop<int>(context, tempIndex + 1),
                      child: Text(l10n.go),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      _goToPage(selected);
    }
  }

  Future<void> _openSurahPicker(List<SurahMeta> surahs) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<SurahMeta>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final controller = TextEditingController();
        final ValueNotifier<String> query = ValueNotifier<String>('');
        controller.addListener(() {
          query.value = controller.text.toLowerCase();
        });
        return SafeArea(
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
                  controller: controller,
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
                  child: ValueListenableBuilder<String>(
                    valueListenable: query,
                    builder: (context, value, _) {
                      final queryText = value.trim().toLowerCase();
                      final filtered = queryText.isEmpty
                          ? surahs
                          : surahs.where((s) {
                              final englishName =
                                  s.englishName.toLowerCase();
                              final englishTranslation =
                                  s.englishNameTranslation.toLowerCase();
                              final arabicName = s.name.toLowerCase();
                              final numberText = s.number.toString();
                              return englishName.contains(queryText) ||
                                  englishTranslation.contains(queryText) ||
                                  arabicName.contains(queryText) ||
                                  numberText.contains(queryText);
                            }).toList();
                      return ListView.separated(
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final surah = filtered[index];
                          final startPage =
                              surahStartPages[surah.number] ?? 1;
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
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
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
    setState(() {
      _edition = edition;
      _selectedAyah = null;
      _currentPageData = null;
    });
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
          .map((number) => _repository.lookupAyahByNumber(number))
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

    final selected = await showModalBottomSheet<_HighlightedAyah>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final height = ((MediaQuery.of(context).size.height * 0.6)
            .clamp(320.0, 520.0)) as double;
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
                                .withOpacity(0.1),
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
          backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
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
    } catch (error) {
      completer.completeError(error);
      rethrow;
    } finally {
      _isLoadingPageAudio = false;
      _pageAudioPreparation = null;
    }
  }

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
      },
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
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
            return _buildPageContent(data);
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
            colorScheme.surfaceVariant.withOpacity(0.35),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.85),
            colorScheme.primary.withOpacity(0.65),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            surah.name,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${surah.englishName} • ${surah.englishNameTranslation}',
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
        ? ((PreferencesService.getFontSize() - 4).clamp(12.0, 48.0) as double)
        : PreferencesService.getFontSize();
    final TextStyle baseStyle = _arabicTextStyle(
      fontSize: baseFontSize,
      height: 1.6,
      color: colorScheme.onSurface,
    );

    final Color highlightColor = const Color(0xFFFFF7C2);
    final Color playingColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2C3C57)
        : const Color(0xFFFFE19C);
    final Color backgroundColor = isPlaying
        ? playingColor
        : isSelected
            ? colorScheme.secondaryContainer.withOpacity(0.6)
            : isHighlighted
                ? highlightColor
                : colorScheme.surface.withOpacity(0.4);
    final Color borderColor = isPlaying || isHighlighted
        ? colorScheme.primary
        : colorScheme.outlineVariant.withOpacity(0.5);
    final List<BoxShadow>? boxShadow = isPlaying
        ? [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
        : null;
    return AnimatedContainer(
      key: itemKey,
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: boxShadow,
      ),
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
                      TextSpan(
                        text: ayah.text.trim(),
                        style: baseStyle,
                      ),
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
                      color: colorScheme.onSurface.withOpacity(0.6),
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
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: l10n.highlightedAyahs,
            onPressed: _highlightedAyahs.isEmpty
                ? null
                : _openHighlightedAyahsSheet,
          ),
          if (showPlayButton) ...[
            IconButton(
              icon: Icon(isRtl ? Icons.skip_next : Icons.skip_previous),
              tooltip: l10n.previousAyah,
              onPressed: (_currentPageData == null || _isLoadingPageAudio)
                  ? null
                  : () => _seekToPreviousAyah(),
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
              onPressed: _currentPageData == null || _isLoadingPageAudio
                  ? null
                  : () => _togglePageAudio(_currentPageData!),
            ),
          ],
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
      body: FutureBuilder<PageData>(
        future: _repository.loadPage(_currentPage, _edition),
        builder: (context, snapshot) {
          final pageData = snapshot.data;
          return Column(
            children: [
              Expanded(child: _buildPageView()),
              _buildBottomBar(pageData),
            ],
          );
        },
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
        color: colorScheme.primary.withOpacity(0.1),
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
    final url = AudioService.buildVerseUrl(
      reciterKeyAr: reciterCode,
      surahOrder: ayah.surah.number,
      verseNumber: ayah.numberInSurah,
    );
    if (url != null) {
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
      sources.add(
        AudioSource.uri(
          Uri.parse(url),
          tag: mediaItem,
        ),
      );
    }
  }
  return sources;
}
