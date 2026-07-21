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
import 'util/debug_error_display.dart';
import 'models/surah.dart';
import 'util/settings_sheet_utils.dart'; // Import utility
import 'services/reciter_config_service.dart';

class RepetitionRangeScreen extends ConsumerStatefulWidget {
  const RepetitionRangeScreen({super.key, required this.surah});

  final Surah surah;

  @override
  ConsumerState<RepetitionRangeScreen> createState() =>
      _RepetitionRangeScreenState();
}

class _RepetitionRangeScreenState extends ConsumerState<RepetitionRangeScreen> {
  final AudioPlayer _player = AudioPlayer();
  QuranEdition _edition = QuranEditions.simple;
  late Future<List<AyahBrief>> _ayahsFuture;
  RangeValues? _range;
  bool _isPreparing = false;
  bool _isPlaying = false;
  int? _activeRangeStart;
  int? _activeRangeEnd;
  String? _activeReciterKey;
  int? _activeRepeatCount;
  // Multi-reciter rotation: each verse-repeat uses the next reciter in the
  // ordered list, wrapping around (repeatIndex % order.length). When disabled
  // or the list is empty/single, playback behaves as a single reciter.
  bool _reciterRotationEnabled = false;
  List<String> _reciterRotationOrder = <String>[];
  // Snapshot of the reciter order baked into the currently-loaded playlist,
  // used to detect staleness and force a rebuild when the rotation changes.
  List<String>? _activeReciterOrder;
  List<AyahBrief> _currentAyahs = [];
  int? _selectedAyah;
  int _verseRepeatCount = 10;
  int _rangeRepeatCount = 1;
  int _currentRangeIteration = 0;
  int? _currentPlayingVerseNumber;
  int? _lastAutoScrolledVerse;
  final ScrollController _ayahScrollController = ScrollController();
  final Map<int, GlobalKey> _ayahTileKeys = <int, GlobalKey>{};
  // Memoized ayah span parsing (mirrors ReadQuranScreen for visual + perf
  // parity). Keyed so theme/font/edition/size changes invalidate entries.
  final Map<String, List<InlineSpan>> _spanCache = <String, List<InlineSpan>>{};
  static const int _spanCacheMaxEntries = 200;
  List<_VersePlaybackEntry> _playlistEntries = [];
  int _currentPlaylistIndex = 0;
  bool _isHandlingEntryCompletion = false;
  late String _arabicFontKey;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<SequenceState?>? _sequenceStateSub;

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
    _ayahsFuture = QuranRepository.instance
        .loadSurahAyahs(widget.surah.order, _edition);
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
      // Guard at listener level to prevent double-trigger
      if (completed && !_isHandlingEntryCompletion) {
        _isHandlingEntryCompletion = true;
        final generation = _playbackGeneration;
        unawaited(_handleEntryCompleted(generation));
      }
    });
    _sequenceStateSub = _player.sequenceStateStream.listen((sequenceState) {
      final tag = sequenceState?.currentSource?.tag;
      int? verseNumber;
      if (tag is MediaItem) {
        final extras = tag.extras;
        final dynamic value = extras?['verseInSurah'];
        if (value is int) {
          verseNumber = value;
        } else if (value is num) {
          verseNumber = value.toInt();
        }
      }
      if (mounted) {
        setState(() {
          _currentPlayingVerseNumber = verseNumber;
        });
        if (verseNumber != null) {
          _scrollToMemorizationVerse(verseNumber);
        }
      } else {
        _currentPlayingVerseNumber = verseNumber;
      }
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _sequenceStateSub?.cancel();
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
    setState(() {
      _ayahsFuture = QuranRepository.instance
          .loadSurahAyahs(widget.surah.order, _edition);
      _range = null;
      _selectedAyah = null;
      _activeRangeStart = null;
      _activeRangeEnd = null;
      _activeReciterKey = null;
      _activeReciterOrder = null;
      _activeRepeatCount = null;
      _currentPlayingVerseNumber = null;
      _currentAyahs = [];
      _verseRepeatCount = PreferencesService.getVerseRepeatCount();
      _ayahTileKeys.clear();
      _spanCache.clear();
      _lastAutoScrolledVerse = null;
      _playlistEntries.clear();
      _currentPlaylistIndex = 0;
      _pausedForResume = false;
    });
    if (_ayahScrollController.hasClients) {
      _ayahScrollController.jumpTo(0);
    }
    await _player.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    } else {
      _isPlaying = false;
    }
  }

  Future<void> _togglePlay(List<AyahBrief> ayahs) async {
    if (_isPreparing) return;
    if (_player.playing) {
      await _player.pause();
      // Remember that we can resume the currently-loaded playlist instead of
      // rebuilding it from the start on the next play.
      _pausedForResume = _playlistEntries.isNotEmpty;
      setState(() => _isPlaying = false);
      return;
    }

    // Resume from the paused position when the loaded playlist is still valid.
    if (_pausedForResume &&
        _playlistEntries.isNotEmpty &&
        _player.audioSource != null) {
      _pausedForResume = false;
      _player.play();
      setState(() => _isPlaying = true);
      return;
    }

    final success = await _playSelectedAyah(showErrors: true);
    if (!success && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorLoadingAudio)),
      );
    }
  }

  void _scrollToMemorizationVerse(int verseInSurah,
      {bool immediate = false, int attempt = 0}) {
    _lastAutoScrolledVerse = verseInSurah;
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
    AyahBrief? target;
    for (final ayah in _currentAyahs) {
      if (ayah.numberInSurah == verseInSurah) {
        target = ayah;
        break;
      }
    }
    if (target == null) return;
    final key = _ayahTileKeys[target.number];
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
          duration: immediate ? Duration.zero : const Duration(milliseconds: 350),
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

  bool _sameOrder(List<String>? a, List<String> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<bool> _preparePlaylist({
    required List<AyahBrief> ayahs,
    required int start,
    required int end,
    required List<String> reciterOrder,
    required int repeatCount,
  }) async {
    final langCode = PreferencesService.getLanguage();
    // Cache display names per reciter to avoid repeated lookups.
    final Map<String, String> reciterNames = {
      for (final key in reciterOrder)
        key: AudioService.reciterDisplayName(key, langCode),
    };
    final entries = <_VersePlaybackEntry>[];

    for (int i = start; i <= end; i++) {
      final brief = ayahs[i - 1];
      for (int repeatIndex = 0; repeatIndex < repeatCount; repeatIndex++) {
        // Rotate reciter per verse-repeat, wrapping around the order.
        final reciterKey = reciterOrder[repeatIndex % reciterOrder.length];
        entries.add(
          _VersePlaybackEntry(
            verseUri: await AudioService.getVerseUriPreferLocal(
              reciterKeyAr: reciterKey,
              surahOrder: widget.surah.order,
              verseNumber: brief.numberInSurah,
            ),
            globalAyahNumber: brief.number,
            verseInSurah: brief.numberInSurah,
            reciterName: reciterNames[reciterKey] ?? reciterKey,
            reciterKey: reciterKey,
            repeatIndex: repeatIndex,
            repeatCount: repeatCount,
          ),
        );
      }
    }

    if (entries.isEmpty) {
      return false;
    }

    _playlistEntries = entries;
    _currentPlaylistIndex = 0;
    _activeRangeStart = start;
    _activeRangeEnd = end;
    _activeReciterKey = reciterOrder.first;
    _activeReciterOrder = List<String>.from(reciterOrder);
    _activeRepeatCount = repeatCount;
    _currentPlayingVerseNumber = null;
    return true;
  }

  Future<void> _handleEntryCompleted(int generation) async {
    if (_playlistEntries.isEmpty) {
      _isHandlingEntryCompletion = false;
      if (mounted) {
        setState(() => _isPlaying = false);
      } else {
        _isPlaying = false;
      }
      return;
    }
    try {
      // Abort if generation changed (user tapped a different verse or reloaded)
      if (_playbackGeneration != generation) return;

      final nextIndex = (_currentPlaylistIndex + 1) % _playlistEntries.length;
      bool shouldStop = false;

      // Check for wrap-around
      if (nextIndex == 0) {
         _currentRangeIteration++;
         if (_currentRangeIteration >= _rangeRepeatCount) {
             shouldStop = true;
         }
      }

      if (shouldStop) {
        try { await _player.stop(); } catch (_) {}
        // Range finished: clear playback flags and the verse highlight so the
        // list doesn't leave the last verse looking like it's still playing.
        _pausedForResume = false;
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentPlayingVerseNumber = null;
          });
        } else {
          _isPlaying = false;
          _currentPlayingVerseNumber = null;
        }
        return;
      }

      if (_playbackGeneration != generation) return;
      await _playEntryAt(nextIndex);
    } finally {
      _isHandlingEntryCompletion = false;
    }
  }

  Future<void> _playEntryAt(int index) async {
    if (_playlistEntries.isEmpty) return;
    final entry = _playlistEntries[index];
    final mediaItem = MediaItem(
      id: '${entry.reciterKey}-${widget.surah.order}-${entry.verseInSurah}-${entry.repeatIndex}',
      title: '${widget.surah.name} • ${entry.verseInSurah}',
      album: entry.reciterName,
      artUri: null,
      extras: {
        'surahOrder': widget.surah.order,
        'verseInSurah': entry.verseInSurah,
        'globalAyah': entry.globalAyahNumber,
        'edition': _edition.displayName,
        'repeatIndex': entry.repeatIndex,
        'repeatCount': entry.repeatCount,
        'verseMode': true,
        'repetitionMode': true,
      },
    );

    final uri = entry.verseUri;
    // If URI is null (missing audio), skip to next entry
    if (uri == null) {
      _currentPlaylistIndex = index;
      final generation = _playbackGeneration;
      unawaited(_handleEntryCompleted(generation));
      return;
    }
    
    // Update index BEFORE play so completion handler reads the correct value
    _currentPlaylistIndex = index;
    _currentPlayingVerseNumber = entry.verseInSurah;
    _isPlaying = true;
    if (mounted) setState(() {});

    try {
      await _player.setAudioSource(AudioSource.uri(uri, tag: mediaItem));
      _player.play(); // Don't await — completion handled by listener
    } catch (e, stackTrace) {
      if (!mounted) return;
      DebugErrorDisplay.showError(
        context,
        screen: 'Repetition Range',
        operation: 'Play Verse ${entry.verseInSurah}',
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      );
      
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        String userMessage = l10n.errorLoadingAudio;
        
        if (e.toString().contains('Permission')) {
          userMessage = 'Audio permission required. Please grant permission in settings.';
        } else if (e.toString().contains('Network') || e.toString().contains('Connection')) {
          userMessage = l10n.audioInternetRequired;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    _scrollToMemorizationVerse(entry.verseInSurah);
  }

  Future<bool> _playSelectedAyah({bool showErrors = false}) async {
    if (_isPreparing) {
      return false;
    }

    final ayahs = _currentAyahs;
    if (ayahs.isEmpty) {
      return false;
    }

    final latestRepeatCount = PreferencesService.getVerseRepeatCount();
    final repeatCount = latestRepeatCount <= 0 ? 1 : latestRepeatCount;
    if (latestRepeatCount != _verseRepeatCount) {
      if (mounted) {
        setState(() {
          _verseRepeatCount = repeatCount;
        });
      } else {
        _verseRepeatCount = repeatCount;
      }
    }

    final total = ayahs.length;
    int start = (_range?.start.round() ?? 1).clamp(1, total);
    int end = (_range?.end.round() ?? total).clamp(1, total);
    if (end < start) {
      final temp = start;
      start = end;
      end = temp;
    }

    final reciterOrder = _resolveReciterOrder();
    final reciterKey = reciterOrder.first;

    // Validation: every reciter in the rotation must support verse-by-verse
    // audio. Surface the first incompatible one so the user can fix it.
    for (final key in reciterOrder) {
      final reciter = await ReciterConfigService.getReciterByCode(key);
      if (reciter != null && !reciter.hasVerseByVerse()) {
        if (showErrors && mounted) {
          final l10n = AppLocalizations.of(context)!;
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
                            // Rebuild
                          });
                          // Retry
                          _playSelectedAyah(showErrors: true);
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
    }

    // If target verse not downloaded and no internet, show a clear message
    try {
      final targetAyah = _selectedAyah ?? ayahs[start - 1].number;
      final targetInSurah = (_selectedAyah != null)
          ? (ayahs.firstWhere((a) => a.number == targetAyah, orElse: () => ayahs[start - 1]).numberInSurah)
          : ayahs[start - 1].numberInSurah;
      final hasLocal = await AudioService.isLocalAyahAvailable(
        reciterKeyAr: reciterKey,
        surahOrder: widget.surah.order,
        verseNumber: targetInSurah,
      );
      final hasNet = await _hasInternet();
      if (!hasLocal && !hasNet) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.audioInternetRequired)),
          );
        }
        return false;
      }
    } catch (_) {}
    final needsReload =
        _playlistEntries.isEmpty ||
        _activeReciterKey != reciterKey ||
        !_sameOrder(_activeReciterOrder, reciterOrder) ||
        _activeRangeStart != start ||
        _activeRangeEnd != end ||
        _activeRepeatCount != repeatCount;

    if (needsReload) {
      _isPreparing = true;
      try {
        final prepared = await _preparePlaylist(
          ayahs: ayahs,
          start: start,
          end: end,
          reciterOrder: reciterOrder,
          repeatCount: repeatCount,
        );
        if (!prepared) {
          return false;
        }
      } finally {
        _isPreparing = false;
      }
    }

    final entries = _playlistEntries;
    if (entries.isEmpty) {
      return false;
    }

    final targetAyahNumber = _selectedAyah ?? ayahs[start - 1].number;
    final targetEntryIndex = entries.indexWhere(
      (entry) => entry.globalAyahNumber == targetAyahNumber,
    );
    final entryIndex = targetEntryIndex >= 0 ? targetEntryIndex : 0;
    
    // Reset iteration count on new play start
    _currentRangeIteration = 0;
    // This is a fresh start (not a resume), so drop any stale resume flag.
    _pausedForResume = false;

    await _playEntryAt(entryIndex);
    return true;
  }

  Future<bool> _hasInternet() => NetUtils.hasInternet();

  void _selectAyah(AyahBrief ayah) {
    final wasPlaying = _player.playing;
    final total = _currentAyahs.length;
    if (total == 0) {
      return;
    }
    setState(() {
      _selectedAyah = ayah.number;
    });
    // Selecting an ayah re-anchors playback to it, so a previously paused
    // playlist can no longer be resumed in place.
    _pausedForResume = false;
    _scrollToMemorizationVerse(ayah.numberInSurah);
    if (wasPlaying) {
      unawaited(_playSelectedAyah(showErrors: false));
    }
  }

  /// Applies a new [start]/[end] range (from the slider or the numeric editor),
  /// clamping to the surah bounds, invalidating any loaded playlist, and
  /// re-anchoring the selected ayah if it falls outside the new range.
  void _applyRange(double start, double end) {
    final total = _currentAyahs.length;
    if (total == 0) return;
    AyahBrief? fallbackAyah;
    setState(() {
      final maxVal = total.toDouble();
      final double clampedStart = start.clamp(1.0, maxVal);
      final double clampedEnd = end.clamp(1.0, maxVal);
      _range = RangeValues(clampedStart, clampedEnd);
      _activeRangeStart = null;
      _activeRangeEnd = null;
      _activeReciterKey = null;
      _activeReciterOrder = null;
      _activeRepeatCount = null;
      // Range changed → loaded playlist is stale, can't resume.
      _pausedForResume = false;

      if (_selectedAyah != null && _currentAyahs.isNotEmpty) {
        AyahBrief? selectedBrief;
        for (final ayah in _currentAyahs) {
          if (ayah.number == _selectedAyah) {
            selectedBrief = ayah;
            break;
          }
        }
        if (selectedBrief != null) {
          final int startIndex = clampedStart.round();
          final int endIndex = clampedEnd.round();
          if (selectedBrief.numberInSurah < startIndex ||
              selectedBrief.numberInSurah > endIndex) {
            final int fallbackIndex =
                (startIndex.clamp(1, _currentAyahs.length)) - 1;
            fallbackAyah = _currentAyahs[fallbackIndex];
            _selectedAyah = fallbackAyah?.number;
          }
        }
      }
    });
    final AyahBrief? effectiveFallback = fallbackAyah;
    if (effectiveFallback != null) {
      _scrollToMemorizationVerse(effectiveFallback.numberInSurah,
          immediate: true);
    }
  }

  /// Tappable pill showing a range bound (first/last ayah). Tapping opens a
  /// numeric editor so exact verses are easy to reach even for narrow ranges.
  Widget _buildRangeBoundChip({
    required String label,
    required int value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer
                .withAlpha((255 * 0.5).round()),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.primary.withAlpha((255 * 0.5).round()),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '$value',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.edit,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Numeric stepper dialog to set the first/last ayah of the range exactly.
  Future<void> _editRangeBound({required bool isStart}) async {
    final total = _currentAyahs.length;
    if (total == 0) return;
    final l10n = AppLocalizations.of(context)!;
    final range = _range ?? RangeValues(1, total.toDouble());
    final int currentStart = range.start.round().clamp(1, total);
    final int currentEnd = range.end.round().clamp(1, total);

    // Keep the range valid: the first ayah can't exceed the last, and the last
    // can't precede the first.
    final int minValue = isStart ? 1 : currentStart;
    final int maxValue = isStart ? currentEnd : total;
    int value = (isStart ? currentStart : currentEnd).clamp(minValue, maxValue);

    final controller = TextEditingController(text: '$value');

    final int? result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void setValue(int v) {
              value = v.clamp(minValue, maxValue);
              controller.text = '$value';
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
              setDialogState(() {});
            }

            return AlertDialog(
              title: Text(isStart ? l10n.firstAyah : l10n.lastAyah),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed:
                        value > minValue ? () => setValue(value - 1) : null,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: Theme.of(context).textTheme.headlineSmall,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        helperText: '$minValue–$maxValue',
                        helperMaxLines: 1,
                      ),
                      onChanged: (text) {
                        final parsed = int.tryParse(text.trim());
                        if (parsed != null) {
                          value = parsed.clamp(minValue, maxValue);
                          setDialogState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed:
                        value < maxValue ? () => setValue(value + 1) : null,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed =
                        int.tryParse(controller.text.trim()) ?? value;
                    Navigator.pop(context, parsed.clamp(minValue, maxValue));
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (result == null) return;

    if (isStart) {
      _applyRange(result.toDouble(), currentEnd.toDouble());
    } else {
      _applyRange(currentStart.toDouble(), result.toDouble());
    }
    // Bring the chosen bound into view.
    final int verseInSurah = _currentAyahs[(result.clamp(1, total)) - 1]
        .numberInSurah;
    _scrollToMemorizationVerse(verseInSurah, immediate: true);
  }

  Widget _buildTopBar(List<AyahBrief> ayahs) {
    final l10n = AppLocalizations.of(context)!;
    final total = ayahs.length;
    final range = _range ?? RangeValues(1, total.toDouble());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildRangeBoundChip(
              label: l10n.firstAyah,
              value: range.start.round(),
              onTap: () => _editRangeBound(isStart: true),
            ),
            _buildPlayControl(l10n),
            _buildRangeBoundChip(
              label: l10n.lastAyah,
              value: range.end.round(),
              onTap: () => _editRangeBound(isStart: false),
            ),
          ],
        ),
        RangeSlider(
          min: 1,
          max: total.toDouble(),
          divisions: total > 1 ? total - 1 : null,
          values: RangeValues(range.start.clamp(1, total.toDouble()), range.end.clamp(1, total.toDouble())),
          labels: RangeLabels('${range.start.round()}', '${range.end.round()}'),
          onChanged: (val) => _applyRange(val.start, val.end),
        ),
      ],
    );
  }

  /// Compact circular play/pause control shown between the first/last ayah
  /// chips.
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
          onTap: _isPreparing
              ? null
              : () {
                  final ayahs = _currentAyahs;
                  // Only jump to the range start on a genuine fresh start.
                  // When pausing or resuming an existing playlist, keep the
                  // view on the current verse.
                  final bool freshStart =
                      !_player.playing && !_pausedForResume;
                  if (freshStart && ayahs.isNotEmpty) {
                    final currentRange =
                        _range ?? RangeValues(1, ayahs.length.toDouble());
                    final start =
                        currentRange.start.round().clamp(1, ayahs.length);
                    final startVerseInSurah = ayahs[start - 1].numberInSurah;
                    _scrollToMemorizationVerse(startVerseInSurah,
                        immediate: true);
                  }
                  _togglePlay(ayahs);
                },
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

    setState(() => _edition = edition);
    await PreferencesService.saveLastRepetitionEdition(edition.name);
    await _reloadAyahs();
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
          widget.surah.name,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: l10n.editionTitle,
            onPressed: () async {
              final selected = await showEditionPickerSheet(
                context,
                current: _edition,
              );
              if (selected != null && selected != _edition) {
                await _toggleEdition(selected);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(),
          ),
        ],
      ),
      body: FutureBuilder<List<AyahBrief>>(
        future: _ayahsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final ayahs = snapshot.data ?? const <AyahBrief>[];
          _currentAyahs = ayahs;
          if (ayahs.isNotEmpty && _lastAutoScrolledVerse == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final start = (_range?.start.round() ?? 1).clamp(1, ayahs.length);
              final firstVerse = ayahs[start - 1].numberInSurah;
              _scrollToMemorizationVerse(firstVerse, immediate: true);
            });
          }
          if (_range == null && ayahs.isNotEmpty) {
            _range = RangeValues(1, ayahs.length.toDouble());
          }
          int startBound = (_range?.start.round() ?? 1).clamp(1, ayahs.length);
          int endBound = (_range?.end.round() ?? ayahs.length).clamp(1, ayahs.length);
          if (endBound < startBound) {
            final tmp = startBound;
            startBound = endBound;
            endBound = tmp;
          }
          final visibleAyahs = ayahs.where((a) {
            final verse = a.numberInSurah;
            return verse >= startBound && verse <= endBound;
          }).toList();
          final ayahsToDisplay = visibleAyahs.isEmpty ? ayahs : visibleAyahs;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildTopBar(ayahs),
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
                    itemCount: ayahsToDisplay.length,
                    itemBuilder: (context, index) =>
                        _buildRepetitionAyahTile(ayahsToDisplay[index]),
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

    final bool isInActiveRange =
        (_activeRangeStart != null && _activeRangeEnd != null)
            ? (a.numberInSurah >= _activeRangeStart! &&
                a.numberInSurah <= _activeRangeEnd!)
            : false;
    final bool isCurrentlyPlaying = _currentPlayingVerseNumber != null
        ? _currentPlayingVerseNumber == a.numberInSurah
        : false;
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
            : isInActiveRange
                ? colorScheme.primaryContainer.withAlpha((255 * 0.35).round())
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

  /// Multi-reciter rotation UI (per verse-repeat). Only shown for editions
  /// that fall back to the user's selected Arabic reciter.
  Widget _buildReciterRotationSection(
      void Function(void Function()) setSheetState, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final langCode = l10n.localeName;

    void invalidatePlaylist() {
      // Rotation changed → any loaded/paused playlist is stale.
      _activeReciterOrder = null;
      _activeReciterKey = null;
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
        parts.add(AudioService.reciterDisplayName(
            order[i % order.length], langCode));
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
          title: Text(l10n.reciterRotationTitle),
          subtitle: Text(
            l10n.reciterRotationDesc,
            style: theme.textTheme.bodySmall,
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
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else ...[
            ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _reciterRotationOrder.length,
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex -= 1;
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
                  final name =
                      AudioService.reciterDisplayName(code, langCode);
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
                              await PreferencesService
                                  .saveReciterRotationOrder(list);
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.settings,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
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
                               context,
                               requireVerseByVerse: true,
                               onReciterSelected: (key) async {
                                // Save to Global Reciter
                                await PreferencesService.saveReciter(key);
                                setState(() {
                                  // Trigger reload if playing logic checks this
                                  _activeReciterKey = null; // Force reload
                                  _pausedForResume = false; // Reciter changed → can't resume
                                });
                               }
                           );
                        },
                      ),
                      const Divider(),
                      _buildReciterRotationSection(setSheetState, l10n),
                      const Divider(),
                    ],
                    ListTile(
                      title: Text('${l10n.verseRepeatCount}: $_verseRepeatCount'),
                      subtitle: Slider(
                        value: _verseRepeatCount.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        label: '$_verseRepeatCount',
                        onChanged: (val) async {
                           final newVal = val.toInt();
                           setSheetState(() => _verseRepeatCount = newVal);
                           setState(() {
                             _verseRepeatCount = newVal;
                             // Verse repeat count is baked into the playlist, so
                             // changing it invalidates any paused playlist.
                             _pausedForResume = false;
                           });
                           await PreferencesService.saveVerseRepeatCount(newVal);
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: Text('${l10n.rangeRepeatCount}: $_rangeRepeatCount'),
                      subtitle: Slider(
                        value: _rangeRepeatCount.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        label: '$_rangeRepeatCount',
                        onChanged: (val) async {
                           final newVal = val.toInt();
                           setSheetState(() => _rangeRepeatCount = newVal);
                           setState(() => _rangeRepeatCount = newVal);
                           await PreferencesService.saveRangeRepetitionCount(newVal);
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: Text('${l10n.fontSize}: ${PreferencesService.getFontSize().toInt()}'),
                      subtitle: Slider(
                        value: PreferencesService.getFontSize(),
                        min: 16,
                        max: 28,
                        divisions: 3,
                        label: '${PreferencesService.getFontSize().toInt()}',
                        onChanged: (val) async {
                          await PreferencesService.saveFontSize(val);
                          setSheetState(() {});
                          setState(() {});
                        },
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

class _VersePlaybackEntry {
  final Uri? verseUri;
  final int globalAyahNumber;
  final int verseInSurah;
  final String reciterName;
  final String reciterKey;
  final int repeatIndex;
  final int repeatCount;

  const _VersePlaybackEntry({
    required this.verseUri,
    required this.globalAyahNumber,
    required this.verseInSurah,
    required this.reciterName,
    required this.reciterKey,
    required this.repeatIndex,
    required this.repeatCount,
  });
}



