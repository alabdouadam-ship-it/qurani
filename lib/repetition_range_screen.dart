import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qurani/providers/reader_prefs_providers.dart';
import 'package:qurani/services/media_item_compat.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/read_quran/edition_picker_sheet.dart';
import 'package:qurani/read_quran/ayah_number_badge.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:qurani/services/irab_service.dart';
import 'package:qurani/widgets/irab_verse_widget.dart';
import 'util/arabic_font_utils.dart';
import 'util/tajweed_parser.dart';
import 'services/net_utils.dart';
import 'models/repetition_passage.dart';
import 'widgets/repetition_passage_editor.dart';
import 'services/surah_service.dart';
import 'models/surah.dart';
import 'util/settings_sheet_utils.dart'; // Import utility
import 'services/reciter_config_service.dart';

class RepetitionRangeScreen extends ConsumerStatefulWidget {
  const RepetitionRangeScreen({super.key, this.initialPassage});
  final RepetitionPassage? initialPassage;

  @override
  ConsumerState<RepetitionRangeScreen> createState() =>
      _RepetitionRangeScreenState();
}

class _RepetitionRangeScreenState extends ConsumerState<RepetitionRangeScreen> {
  final AudioPlayer _player = AudioPlayer();
  QuranEdition _edition = QuranEditions.simple;
  late Future<List<AyahBrief>> _ayahsFuture;
  RepetitionPassage _passage = openingPassage;
  List<Surah> _surahs = [];
  bool _remember = PreferencesService.rememberPassage;
  bool _isPreparing = false;
  bool _isPlaying = false;
  bool _reciterRotationEnabled = false;
  List<String> _reciterRotationOrder = [];
  List<String> _sessionReciters = [];
  int _sessionRepeats = 1;
  RepetitionPosition? _position;
  bool _awaitingCompletion = false;
  List<AyahBrief> _currentAyahs = [];
  int? _selectedAyah;
  int _verseRepeatCount = 10;
  int _rangeRepeatCount = 1;
  int? _currentPlayingVerseNumber;

  final ScrollController _ayahScrollController = ScrollController();
  final Map<int, GlobalKey> _ayahTileKeys = <int, GlobalKey>{};
  // Memoized ayah span parsing (mirrors ReadQuranScreen for visual + perf
  // parity). Keyed so theme/font/edition/size changes invalidate entries.
  final Map<String, List<InlineSpan>> _spanCache = <String, List<InlineSpan>>{};
  static const int _spanCacheMaxEntries = 200;
  late String _arabicFontKey;

  StreamSubscription<PlayerState>? _playerStateSub;

  /// True when playback was paused by the user while a still-valid playlist is
  /// loaded. Lets pause → play resume from the paused position instead of
  /// rebuilding and restarting the whole range. Cleared whenever the loaded
  /// playlist becomes stale (range/reciter/repeat/edition change, reload, or an
  /// explicit verse selection).
  bool _pausedForResume = false;

  /// Monotonic counter; incremented on playlist changes to cancel stale
  /// completion chains.
  int _playbackGeneration = 0;

  @override
  void initState() {
    super.initState();
    final savedEdition = PreferencesService.getLastRepetitionEdition();
    _edition = QuranEditions.byId(savedEdition);
    _verseRepeatCount = PreferencesService.getVerseRepeatCount();
    _rangeRepeatCount = PreferencesService.getRangeRepetitionCount();
    _reciterRotationEnabled = PreferencesService.getReciterRotationEnabled();
    _reciterRotationOrder = PreferencesService.getReciterRotationOrder();

    _arabicFontKey = ref.read(arabicFontProvider);
    _playerStateSub = _player.playerStateStream.listen((state) {
      final completed = state.processingState == ProcessingState.completed;
      final isPlaying = state.playing && !completed;
      if (mounted) {
        setState(() => _isPlaying = isPlaying);
      } else {
        _isPlaying = isPlaying;
      }
      // Keep the screen awake while playing so the OS doesn't lock the phone
      // and throttle the completion handler that advances to the next verse.
      _updateWakelock(isPlaying);
      if (completed && _awaitingCompletion) {
        _awaitingCompletion = false;
        unawaited(_advance(_playbackGeneration));
      }
    });
  }

  String? _catalogLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (_catalogLanguage != null) return;
    _catalogLanguage = lang;
    _ayahsFuture = _initializePassage();
  }

  Future<List<AyahBrief>> _initializePassage() async {
    final surahs = await SurahService.getLocalizedSurahs(_catalogLanguage!);
    if (!mounted) return [];
    if (surahs.isEmpty) throw StateError('Missing surah catalog');
    setState(() => _surahs = surahs);
    final saved = PreferencesService.lastPassage;
    final initial = widget.initialPassage;
    _passage = initial != null && initial.isValid(_surahs) ? initial
        : _remember && saved.isValid(_surahs) ? saved : openingPassage;
    return _loadPassage(_passage, _edition);
  }

  Future<List<AyahBrief>> _loadPassage(
      RepetitionPassage passage, QuranEdition edition) async {
    final result = <AyahBrief>[];
    for (var surah = passage.start.surah; surah <= passage.end.surah; surah++) {
      if (!mounted || passage != _passage || edition != _edition) return [];
      final ayahs =
          await QuranRepository.instance.loadSurahAyahs(surah, edition);
      if (ayahs.isEmpty) throw StateError('Missing surah $surah');
      result
          .addAll(ayahs.where((a) => passage.contains(surah, a.numberInSurah)));
    }
    return result;
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _playbackGeneration++;
    _player.dispose();
    _ayahScrollController.dispose();
    // Release the wakelock when leaving the screen.
    if (_wakelockEnabled) {
      unawaited(WakelockPlus.disable());
      _wakelockEnabled = false;
    }
    super.dispose();
  }

  /// Toggles the screen-awake wakelock, only issuing a platform call when the
  /// desired state actually changes.
  bool _wakelockEnabled = false;
  void _updateWakelock(bool keepAwake) {
    if (keepAwake == _wakelockEnabled) return;
    _wakelockEnabled = keepAwake;
    unawaited(WakelockPlus.toggle(enable: keepAwake).catchError((_) {}));
  }

  Future<void> _reloadAyahs() async {
    _playbackGeneration++;
    _awaitingCompletion = false;
    setState(() {
      _ayahsFuture = _loadPassage(_passage, _edition);
      _position = null;
      _selectedAyah = null;
      _currentPlayingVerseNumber = null;
      _currentAyahs = [];
      _ayahTileKeys.clear();
      _spanCache.clear();

      _pausedForResume = false;
      _isPreparing = false;
    });
    if (_ayahScrollController.hasClients) _ayahScrollController.jumpTo(0);
    await _player.stop();
  }

  Future<void> _togglePlay() async {
    if (_isPreparing || _currentAyahs.isEmpty) return;
    if (_isPlaying) {
      _pausedForResume = true;
      await _player.pause();
    } else if (_pausedForResume) {
      _pausedForResume = false;
      unawaited(_runPlayer(_playbackGeneration));
    } else {
      await _start();
    }
  }

  void _scrollToMemorizationVerse(int verseInSurah,
      {bool immediate = false, int attempt = 0}) {
    if (!mounted) return;
    if (_currentAyahs.isNotEmpty &&
        _currentAyahs.first.number == verseInSurah &&
        _ayahScrollController.hasClients &&
        _ayahTileKeys[verseInSurah]?.currentContext == null) {
      _ayahScrollController.jumpTo(0);
    }
    if (attempt > 8) return;
    if (_currentAyahs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMemorizationVerse(
          verseInSurah,
          immediate: immediate,
          attempt: attempt + 1,
        );
      });
      return;
    }
    final key = _ayahTileKeys[verseInSurah];
    if (key == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMemorizationVerse(verseInSurah,
            immediate: immediate, attempt: attempt + 1);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final context = key.currentContext;
      if (context == null) {
        _scrollToMemorizationVerse(verseInSurah,
            immediate: immediate, attempt: attempt + 1);
        return;
      }
      if (!immediate) {
        await Future.delayed(const Duration(milliseconds: 24));
      }
      if (!mounted) return;
      try {
        await Scrollable.ensureVisible(
          // ignore: use_build_context_synchronously
          context,
          duration:
              immediate ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.2,
        );
      } catch (_) {
        _scrollToMemorizationVerse(verseInSurah,
            immediate: immediate, attempt: attempt + 1);
      }
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

  String _resolveReciterKey() {
    // Editions with associated recitation carry an audioReciterKey; others
    // fall back to the user's selected Arabic reciter (read translation/tafsir,
    // hear the Arabic ayah).
    final key = _edition.audioReciterKey;
    if (key != null) return key;
    final reciter = PreferencesService.getReciter();
    return reciter.isNotEmpty ? reciter : 'afs';
  }

  /// Ordered list of reciter keys to rotate through, one per verse-repeat.
  /// Falls back to a single-element list of the resolved reciter when rotation
  /// is disabled, empty, or the edition pins its own recitation.
  List<String> _resolveReciterOrder() {
    final single = _resolveReciterKey();
    // Editions with a fixed recitation (translation/tafsir) ignore rotation.
    if (_edition.audioReciterKey != null) {
      return <String>[single];
    }
    if (!_reciterRotationEnabled) {
      return <String>[single];
    }
    final order = _reciterRotationOrder.where((e) => e.isNotEmpty).toList();
    if (order.isEmpty) {
      return <String>[single];
    }
    return order;
  }

  Future<void> _start() async {
    final generation = ++_playbackGeneration;
    _awaitingCompletion = false;
    _pausedForResume = false;
    setState(() => _isPreparing = true);
    try {
      await _player.stop();
      if (!mounted || generation != _playbackGeneration) return;
      _sessionReciters = _resolveReciterOrder();
      _sessionRepeats = _verseRepeatCount;
      for (final code in _sessionReciters) {
        final reciter = await ReciterConfigService.getReciterByCode(code);
        if (!mounted || generation != _playbackGeneration) return;
        if (reciter != null && !reciter.hasVerseByVerse()) {
          final l10n = AppLocalizations.of(context)!;
          _audioFailure(
              generation,
              l10n.reciterNotAvailableForVerses(
                  reciter.getDisplayName(l10n.localeName)));
          return;
        }
      }
      final selected =
          _currentAyahs.indexWhere((a) => a.number == _selectedAyah);
      _position = (verseIndex: selected < 0 ? 0 : selected, repeat: 0, pass: 0);
      await _playPosition(generation, checkNetwork: true);
    } catch (_) {
      _audioFailure(generation);
    }
  }

  Future<void> _advance(int generation) async {
    final current = _position;
    if (current == null || !mounted || generation != _playbackGeneration) {
      return;
    }
    _position =
        current.next(_currentAyahs.length, _sessionRepeats, _rangeRepeatCount);
    if (_position == null) {
      setState(() => _currentPlayingVerseNumber = null);
      await _player.stop();
      return;
    }
    await _playPosition(generation);
  }

  Future<void> _playPosition(int generation,
      {bool checkNetwork = false}) async {
    final position = _position;
    if (!mounted || generation != _playbackGeneration || position == null ||
        position.verseIndex >= _currentAyahs.length || _sessionReciters.isEmpty) {
      return;
    }
    final verse = _currentAyahs[position.verseIndex];
    final code = _sessionReciters[position.repeat % _sessionReciters.length];
    setState(() => _isPreparing = true);
    try {
      final uri = await AudioService.getVerseUriPreferLocal(
          reciterKeyAr: code,
          surahOrder: verse.surah.number,
          verseNumber: verse.numberInSurah);
      if (!mounted || generation != _playbackGeneration) return;
      if (uri == null) {
        _audioFailure(generation);
        return;
      }
      if (checkNetwork &&
          uri.scheme != 'file' &&
          !await NetUtils.hasInternet()) {
        if (mounted) {
          _audioFailure(
              generation, AppLocalizations.of(context)!.audioInternetRequired);
        }
        return;
      }
      if (!mounted || generation != _playbackGeneration) return;
      final surah = _surahs.firstWhere((s) => s.order == verse.surah.number);
      final tag = MediaItem(
        id: '$code-${verse.number}-${position.repeat}',
        title: '${surah.name} • ${verse.numberInSurah}',
        album: AudioService.reciterDisplayName(
            code, PreferencesService.getLanguage()),
        extras: {
          'surahOrder': surah.order,
          'verseInSurah': verse.numberInSurah,
          'globalAyah': verse.number,
          'edition': _edition.displayName,
          'repeatIndex': position.repeat,
          'repeatCount': _sessionRepeats,
          'verseMode': true,
          'repetitionMode': true
        },
      );
      await _player.setAudioSource(AudioSource.uri(uri, tag: tag));
      if (!mounted || generation != _playbackGeneration) return;
      _awaitingCompletion = true;
      setState(() {
        _currentPlayingVerseNumber = verse.number;
        _isPreparing = false;
      });
      _scrollToMemorizationVerse(verse.number);
      unawaited(_runPlayer(generation));
    } catch (_) {
      _audioFailure(generation);
    }
  }

  Future<void> _runPlayer(int generation) async {
    try {
      await _player.play();
    } catch (_) {
      _audioFailure(generation);
    }
  }

  void _audioFailure(int generation, [String? message]) {
    if (!mounted || generation != _playbackGeneration) return;
    _playbackGeneration++;
    _awaitingCompletion = false;
    _pausedForResume = false;
    setState(() {
      _isPreparing = false;
      _currentPlayingVerseNumber = null;
      _position = null;
    });
    unawaited(_player.stop());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(message ?? AppLocalizations.of(context)!.errorLoadingAudio)));
  }

  void _selectAyah(AyahBrief ayah) {
    final restart = _isPlaying || _isPreparing;
    setState(() => _selectedAyah = ayah.number);
    _pausedForResume = false;
    if (restart) unawaited(_start());
  }

  Widget _buildPlayControl(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Tooltip(
      message: _isPlaying ? l10n.pauseSurahAudio : l10n.playSurahAudio,
      child: Material(
        color: _isPreparing
            ? theme.colorScheme.primary.withAlpha((255 * 0.6).round())
            : theme.colorScheme.primary,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _isPreparing ? null : _togglePlay,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _isPreparing
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 28,
                    color: theme.colorScheme.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleEdition(QuranEdition edition) async {
    if (edition == _edition) return;

    if (edition == QuranEditions.irab) {
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

    if (!mounted) return;
    setState(() => _edition = edition);
    await PreferencesService.saveLastRepetitionEdition(edition.name);
    if (mounted) await _reloadAyahs();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(arabicFontProvider, (prev, next) {
      if (_arabicFontKey != next) {
        setState(() => _arabicFontKey = next);
      }
    });
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.repetitionMemorization,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: l10n.editionTitle,
            onPressed: _surahs.isEmpty
                ? null
                : () async {
                    final selected = await showEditionPickerSheet(
                      context,
                      current: _edition,
                    );
                    if (mounted && selected != null && selected != _edition) {
                      await _toggleEdition(selected);
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: _surahs.isEmpty ? null : _showSettingsSheet,
          ),
        ],
      ),
      body: FutureBuilder<List<AyahBrief>>(
        future: _ayahsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l10n.passageLoadError),
              TextButton(
                  onPressed: () => setState(() {
                        _ayahsFuture = _surahs.isEmpty
                            ? _initializePassage()
                            : _loadPassage(_passage, _edition);
                      }),
                  child: Text(l10n.retry)),
            ]));
          }
          final ayahs = snapshot.data!;
          _currentAyahs = ayahs;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          '${_surahName(_passage.start.surah)} ${_passage.start.verse} – '
                          '${_surahName(_passage.end.surah)} ${_passage.end.verse}\n'
                          '${l10n.passageVerseCount(ayahs.length)}')),
                  _buildPlayControl(l10n),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withAlpha((255 * 0.35).round()),
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  ),
                  child: ListView.builder(
                    controller: _ayahScrollController,
                    // Add the system nav-bar inset to the bottom so the last
                    // verse isn't hidden behind Android's on-screen controls.
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      12 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: ayahs.length,
                    itemBuilder: (context, index) {
                      final a = ayahs[index];
                      final tile = _buildRepetitionAyahTile(a);
                      if (index > 0 &&
                          ayahs[index - 1].surah.number == a.surah.number) {
                        return tile;
                      }
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                                header: true,
                                child: Text(_surahName(a.surah.number),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium)),
                            tile,
                          ]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Card-style ayah tile mirroring ReadQuranScreen (generous line height,
  /// inline ayah-number badge, animated highlight, rounded card) so the
  /// repetition/memorization view matches the reading view.
  Widget _buildRepetitionAyahTile(AyahBrief a) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final textDirection =
        _edition.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final GlobalKey tileKey =
        _ayahTileKeys.putIfAbsent(a.number, () => GlobalKey());

    final bool isCurrentlyPlaying = _currentPlayingVerseNumber == a.number;
    final bool isSelected = _selectedAyah == a.number;

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

    final bool isTajweed = _edition.isTajweed;
    final String rawText = a.text.trim();
    final String spanKey = '${a.number}|${_edition.id}|$isTajweed|'
        '$_arabicFontKey|${baseFontSize.toStringAsFixed(1)}|'
        '${baseStyle.color?.hashCode ?? 0}|'
        '${diacriticStyle.color?.hashCode ?? 0}|${rawText.hashCode}';
    final List<InlineSpan> ayahContentSpans =
        _spanCache.putIfAbsent(spanKey, () {
      final spans = isTajweed
          ? TajweedParser.parseSpans(rawText, baseStyle,
              diacriticStyle: diacriticStyle)
          : TajweedParser.buildPlainSpans(rawText, baseStyle,
              diacriticStyle: diacriticStyle);
      if (_spanCache.length > _spanCacheMaxEntries) {
        _spanCache.clear();
      }
      return spans;
    });

    final Color playingColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2C3C57)
        : const Color(0xFFFFE19C);
    final Color backgroundColor = isCurrentlyPlaying
        ? playingColor
        : isSelected
            ? colorScheme.secondaryContainer.withAlpha((255 * 0.6).round())
            : colorScheme.primaryContainer.withAlpha((255 * 0.15).round());
    final Color borderColor = isCurrentlyPlaying
        ? colorScheme.primary
        : colorScheme.outlineVariant.withAlpha((255 * 0.5).round());
    final List<BoxShadow>? boxShadow = isCurrentlyPlaying
        ? [
            BoxShadow(
              color: colorScheme.primary.withAlpha((255 * 0.25).round()),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
        : null;

    return TweenAnimationBuilder<Color?>(
      key: tileKey,
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
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: boxShadow,
          ),
          child: child,
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectAyah(a),
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
                child: _edition == QuranEditions.irab && IrabService().isLoaded
                    ? Wrap(
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IrabVerseWidget(
                            verse: IrabService().getVerse(
                                    a.surah.number, a.numberInSurah) ??
                                IrabVerse(
                                    surahNumber: a.surah.number,
                                    verseNumber: a.numberInSurah,
                                    words: []),
                            fontSize: baseFontSize,
                          ),
                          const SizedBox(width: 8),
                          AyahNumberBadge(
                            number: a.numberInSurah,
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
                                number: a.numberInSurah,
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
                    '${a.surah.englishName} ${a.numberInSurah}',
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

  /// Multi-reciter rotation UI (per verse-repeat). Only shown for editions
  /// that fall back to the user's selected Arabic reciter.
  Widget _buildReciterRotationSection(
      void Function(void Function()) setSheetState, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final langCode = l10n.localeName;

    void invalidatePlaylist() {
      // Rotation changed → any loaded/paused playlist is stale.

      _pausedForResume = false;
    }

    // Build the preview sequence for the current verse repeat count.
    String buildPreview() {
      final order = _reciterRotationOrder.where((e) => e.isNotEmpty).toList();
      if (order.isEmpty) return '';
      final count = _verseRepeatCount <= 0 ? 1 : _verseRepeatCount;
      const maxShown = 8;
      final shown = count < maxShown ? count : maxShown;
      final parts = <String>[];
      for (int i = 0; i < shown; i++) {
        parts.add(
            AudioService.reciterDisplayName(order[i % order.length], langCode));
      }
      var seq = parts.join('  →  ');
      if (count > maxShown) seq = '$seq  …';
      return seq;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: Text(
            l10n.reciterRotationTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            l10n.reciterRotationDesc,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
          ),
          value: _reciterRotationEnabled,
          onChanged: (val) async {
            setSheetState(() => _reciterRotationEnabled = val);
            setState(() {
              _reciterRotationEnabled = val;
              invalidatePlaylist();
            });
            await PreferencesService.saveReciterRotationEnabled(val);
          },
        ),
        if (_reciterRotationEnabled) ...[
          if (_reciterRotationOrder.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                l10n.reciterRotationEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _reciterRotationOrder.length,
              onReorderItem: (oldIndex, newIndex) async {
                final list = List<String>.from(_reciterRotationOrder);
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                setSheetState(() => _reciterRotationOrder = list);
                setState(() {
                  _reciterRotationOrder = list;
                  invalidatePlaylist();
                });
                await PreferencesService.saveReciterRotationOrder(list);
              },
              itemBuilder: (context, index) {
                final code = _reciterRotationOrder[index];
                final name = AudioService.reciterDisplayName(code, langCode);
                return Card(
                  key: ValueKey(code),
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: theme.colorScheme.surfaceContainerHighest
                      .withAlpha((255 * 0.4).round()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    title: Text(name, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.reciterRotationRemove,
                          onPressed: () async {
                            final list =
                                List<String>.from(_reciterRotationOrder)
                                  ..removeAt(index);
                            setSheetState(() => _reciterRotationOrder = list);
                            setState(() {
                              _reciterRotationOrder = list;
                              invalidatePlaylist();
                            });
                            await PreferencesService.saveReciterRotationOrder(
                                list);
                          },
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                l10n.reciterRotationPreview(
                  _verseRepeatCount <= 0 ? 1 : _verseRepeatCount,
                  buildPreview(),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.reciterRotationAddReciter),
                onPressed: () {
                  SettingsSheetUtils.showReciterSelectionSheet(
                    context,
                    requireVerseByVerse: true,
                    onReciterSelected: (code) async {
                      if (code.isEmpty) return;
                      if (_reciterRotationOrder.contains(code)) return;
                      final list = List<String>.from(_reciterRotationOrder)
                        ..add(code);
                      setSheetState(() => _reciterRotationOrder = list);
                      setState(() {
                        _reciterRotationOrder = list;
                        invalidatePlaylist();
                      });
                      await PreferencesService.saveReciterRotationOrder(list);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _surahName(int order) =>
      _surahs.firstWhere((s) => s.order == order).name;

  void _showSettingsSheet() {
    if (_surahs.isEmpty) return;
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
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: Row(
                        children: [
                          Material(
                            color: colorScheme.surfaceContainerHighest
                                .withAlpha(160),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              key: const ValueKey(
                                  'repetition_settings_back_button'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(context).pop(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back_rounded,
                                      size: 22,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      MaterialLocalizations.of(context)
                                          .backButtonTooltip,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 16,
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              l10n.settings,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 26),
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: Theme(
                        data: theme.copyWith(
                          listTileTheme: theme.listTileTheme.copyWith(
                            titleTextStyle:
                                theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            subtitleTextStyle:
                                theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RepetitionPassageEditor(
                                surahs: _surahs,
                                passage: _passage,
                                remember: _remember,
                                onApply: (draft, remember) async {
                                  Navigator.pop(context);
                                  final changed = draft != _passage;
                                  _remember = remember;
                                  _passage = draft;
                                  final save = PreferencesService.savePassage(
                                      draft, remember);
                                  if (changed) await _reloadAyahs();
                                  await save;
                                },
                              ),
                            const Divider(),
                            // The reciter picker only affects playback for editions
                            // that fall back to the user's selected Arabic reciter
                            // (audioReciterKey == null). Editions with their own fixed
                            // recitation (english/french/muyassar) ignore it, so we
                            // hide the row there to avoid implying it has an effect.
                            if (_edition.audioReciterKey == null) ...[
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
                                  // Close settings to open reciter picker
                                  Navigator.pop(context);
                                  SettingsSheetUtils.showReciterSelectionSheet(
                                      this.context,
                                      requireVerseByVerse: true,
                                      onReciterSelected: (key) async {
                                    // Save to Global Reciter
                                    await PreferencesService.saveReciter(key);
                                    if (!mounted) return;
                                    setState(() {
                                      _pausedForResume =
                                          false; // Reciter changed → can't resume
                                    });
                                  });
                                },
                              ),
                              const Divider(),
                              _buildReciterRotationSection(
                                  setSheetState, l10n),
                              const Divider(),
                            ],
                            ListTile(
                              title: Text(
                                  '${l10n.verseRepeatCount}: $_verseRepeatCount'),
                              subtitle: Slider(
                                value: _verseRepeatCount.toDouble(),
                                min: 1,
                                max: 50,
                                divisions: 49,
                                label: '$_verseRepeatCount',
                                onChanged: (val) async {
                                  final newVal = val.toInt();
                                  setSheetState(
                                      () => _verseRepeatCount = newVal);
                                  setState(() {
                                    _verseRepeatCount = newVal;
                                    // Verse repeat count is baked into the playlist, so
                                    // changing it invalidates any paused playlist.
                                    _pausedForResume = false;
                                  });
                                  await PreferencesService.saveVerseRepeatCount(
                                      newVal);
                                },
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              title: Text(
                                  '${l10n.rangeRepeatCount}: $_rangeRepeatCount'),
                              subtitle: Slider(
                                value: _rangeRepeatCount.toDouble(),
                                min: 1,
                                max: 20,
                                divisions: 19,
                                label: '$_rangeRepeatCount',
                                onChanged: (val) async {
                                  final newVal = val.toInt();
                                  setSheetState(
                                      () => _rangeRepeatCount = newVal);
                                  setState(() => _rangeRepeatCount = newVal);
                                  await PreferencesService
                                      .saveRangeRepetitionCount(newVal);
                                },
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              title: Text(
                                  '${l10n.fontSize}: ${PreferencesService.getFontSize().toInt()}'),
                              subtitle: Slider(
                                value: PreferencesService.getFontSize(),
                                min: 16,
                                max: 28,
                                divisions: 3,
                                label:
                                    '${PreferencesService.getFontSize().toInt()}',
                                onChanged: (val) async {
                                  await PreferencesService.saveFontSize(val);
                                  if (!mounted || !context.mounted) return;
                                  setSheetState(() {});
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }
}
