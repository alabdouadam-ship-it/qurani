import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_repository.dart';
import 'util/arabic_font_utils.dart';
import 'models/surah.dart';

class RepetitionRangeScreen extends StatefulWidget {
  const RepetitionRangeScreen({super.key, required this.surah});

  final Surah surah;

  @override
  State<RepetitionRangeScreen> createState() => _RepetitionRangeScreenState();
}

class _RepetitionRangeScreenState extends State<RepetitionRangeScreen> {
  final AudioPlayer _player = AudioPlayer();
  QuranEdition _edition = QuranEdition.simple;
  late Future<List<AyahBrief>> _ayahsFuture;
  RangeValues? _range;
  bool _isPreparing = false;
  bool _isPlaying = false;
  int? _activeRangeStart;
  int? _activeRangeEnd;
  String? _activeReciterKey;
  int? _activeRepeatCount;
  List<AyahBrief> _currentAyahs = const [];
  int? _selectedAyah;
  int _verseRepeatCount = 10;
  int? _currentPlayingVerseNumber;
  int? _lastAutoScrolledVerse;
  final ScrollController _ayahScrollController = ScrollController();
  final Map<int, GlobalKey> _ayahTileKeys = <int, GlobalKey>{};
  List<_VersePlaybackEntry> _playlistEntries = const [];
  int _currentPlaylistIndex = 0;
  bool _isHandlingEntryCompletion = false;
  late String _arabicFontKey;

  @override
  void initState() {
    super.initState();
    _verseRepeatCount = PreferencesService.getVerseRepeatCount();
    _ayahsFuture = QuranRepository.instance
        .loadSurahAyahs(widget.surah.order, _edition);
    _arabicFontKey = PreferencesService.getArabicFontFamily();
    PreferencesService.arabicFontNotifier.addListener(_onArabicFontChange);
    _player.playerStateStream.listen((state) {
      final completed = state.processingState == ProcessingState.completed;
      final isPlaying = state.playing && !completed;
      if (mounted) {
        setState(() => _isPlaying = isPlaying);
      } else {
        _isPlaying = isPlaying;
      }
      if (completed && !_isHandlingEntryCompletion) {
        unawaited(_handleEntryCompleted());
      }
    });
    _player.sequenceStateStream.listen((sequenceState) {
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
    _player.dispose();
    _ayahScrollController.dispose();
    PreferencesService.arabicFontNotifier.removeListener(_onArabicFontChange);
    super.dispose();
  }

  Future<void> _reloadAyahs() async {
    setState(() {
      _ayahsFuture = QuranRepository.instance
          .loadSurahAyahs(widget.surah.order, _edition);
      _range = null;
      _selectedAyah = null;
      _activeRangeStart = null;
      _activeRangeEnd = null;
      _activeReciterKey = null;
      _activeRepeatCount = null;
      _currentPlayingVerseNumber = null;
      _currentAyahs = const [];
      _verseRepeatCount = PreferencesService.getVerseRepeatCount();
      _ayahTileKeys.clear();
      _lastAutoScrolledVerse = null;
      _playlistEntries.clear();
      _currentPlaylistIndex = 0;
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
      setState(() => _isPlaying = false);
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

  void _onArabicFontChange() {
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

  String _resolveReciterKey() {
    switch (_edition) {
      case QuranEdition.simple:
      case QuranEdition.uthmani:
        final reciter = PreferencesService.getReciter();
        return reciter.isNotEmpty ? reciter : 'afs';
      case QuranEdition.english:
        return 'arabic-english';
      case QuranEdition.french:
        return 'arabic-french';
      case QuranEdition.tafsir:
        return 'muyassar';
    }
  }

  Future<bool> _preparePlaylist({
    required List<AyahBrief> ayahs,
    required int start,
    required int end,
    required String reciterKey,
    required int repeatCount,
  }) async {
    final langCode = PreferencesService.getLanguage();
    final reciterName = AudioService.reciterDisplayName(reciterKey, langCode);
    final entries = <_VersePlaybackEntry>[];

    for (int i = start; i <= end; i++) {
      final brief = ayahs[i - 1];
      final url = AudioService.buildVerseUrl(
        reciterKeyAr: reciterKey,
        surahOrder: widget.surah.order,
        verseNumber: brief.numberInSurah,
      );
      if (url == null) {
        continue;
      }
      for (int repeatIndex = 0; repeatIndex < repeatCount; repeatIndex++) {
        entries.add(
          _VersePlaybackEntry(
            url: url,
            globalAyahNumber: brief.number,
            verseInSurah: brief.numberInSurah,
            reciterName: reciterName,
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
    _activeReciterKey = reciterKey;
    _activeRepeatCount = repeatCount;
    _currentPlayingVerseNumber = null;
    return true;
  }

  Future<void> _handleEntryCompleted() async {
    if (_playlistEntries.isEmpty) {
      if (mounted) {
        setState(() => _isPlaying = false);
      } else {
        _isPlaying = false;
      }
      return;
    }
    _isHandlingEntryCompletion = true;
    try {
      final nextIndex = (_currentPlaylistIndex + 1) % _playlistEntries.length;
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

    await _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(entry.url),
        tag: mediaItem,
      ),
    );
    await _player.play();

    if (mounted) {
      setState(() {
        _currentPlaylistIndex = index;
        _currentPlayingVerseNumber = entry.verseInSurah;
        _isPlaying = true;
      });
    } else {
      _currentPlaylistIndex = index;
      _currentPlayingVerseNumber = entry.verseInSurah;
      _isPlaying = true;
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

    final reciterKey = _resolveReciterKey();
    final needsReload =
        _playlistEntries.isEmpty ||
        _activeReciterKey != reciterKey ||
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
          reciterKey: reciterKey,
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
    await _playEntryAt(entryIndex);
    return true;
  }

  void _selectAyah(AyahBrief ayah) {
    final wasPlaying = _player.playing;
    final total = _currentAyahs.length;
    if (total == 0) {
      return;
    }
    final RangeValues currentRange = _range ?? RangeValues(1, total.toDouble());
    final int start = currentRange.start.round();
    final int end = currentRange.end.round();
    final bool inRange = ayah.numberInSurah >= start && ayah.numberInSurah <= end;
    if (!inRange) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.verseOutsideRange)),
        );
      }
      return;
    }
    setState(() {
      _selectedAyah = ayah.number;
    });
    _scrollToMemorizationVerse(ayah.numberInSurah);
    if (wasPlaying) {
      unawaited(_playSelectedAyah(showErrors: false));
    }
  }

  Widget _buildTopBar(List<AyahBrief> ayahs) {
    final l10n = AppLocalizations.of(context)!;
    final total = ayahs.length;
    final range = _range ?? RangeValues(1, total.toDouble());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.surah.name}',
                textDirection: TextDirection.rtl,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            PopupMenuButton<QuranEdition>(
              icon: const Icon(Icons.menu_book_outlined),
              onSelected: (e) async {
                setState(() => _edition = e);
                await _reloadAyahs();
              },
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
                            Text(edition.displayName),
                          ],
                        ),
                      ),
                    )
                    .toList();
              },
            )
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${range.start.round()}'),
            Text('${range.end.round()}'),
          ],
        ),
        RangeSlider(
          min: 1,
          max: total.toDouble(),
          divisions: total > 1 ? total - 1 : null,
          values: RangeValues(range.start.clamp(1, total.toDouble()), range.end.clamp(1, total.toDouble())),
          labels: RangeLabels('${range.start.round()}', '${range.end.round()}'),
          onChanged: (val) {
            AyahBrief? fallbackAyah;
            setState(() {
              final maxVal = total.toDouble();
              final double clampedStart = val.start.clamp(1.0, maxVal);
              final double clampedEnd = val.end.clamp(1.0, maxVal);
              _range = RangeValues(clampedStart, clampedEnd);
              _activeRangeStart = null;
              _activeRangeEnd = null;
              _activeReciterKey = null;
              _activeRepeatCount = null;

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
                    final int fallbackIndex = (startIndex.clamp(1, _currentAyahs.length)) - 1;
                    fallbackAyah = _currentAyahs[fallbackIndex];
                    _selectedAyah = fallbackAyah?.number;
                  }
                }
              }
            });
            final AyahBrief? effectiveFallback = fallbackAyah;
            if (effectiveFallback != null) {
              _scrollToMemorizationVerse(effectiveFallback.numberInSurah, immediate: true);
            }
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: FilledButton.icon(
            onPressed: _isPreparing
                ? null
                : () {
                    final ayahs = _currentAyahs;
                    int? startVerseInSurah;
                    if (ayahs.isNotEmpty) {
                      final currentRange = _range ?? RangeValues(1, ayahs.length.toDouble());
                      final start = currentRange.start.round().clamp(1, ayahs.length);
                      startVerseInSurah = ayahs[start - 1].numberInSurah;
                    }
                    if (startVerseInSurah != null) {
                      _scrollToMemorizationVerse(startVerseInSurah, immediate: true);
                    }
                    _togglePlay(ayahs);
                  },
            icon: _isPreparing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            label: Text(_isPlaying ? l10n.pauseSurahAudio : l10n.playSurahAudio),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.repetitionMemorization),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildTopBar(ayahs),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: _ayahScrollController,
                  itemCount: ayahsToDisplay.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = ayahsToDisplay[index];
                    final GlobalKey tileKey =
                        _ayahTileKeys.putIfAbsent(a.number, () => GlobalKey());
                    final rtl = _edition.isRtl;
                    final bool isInActiveRange = (_activeRangeStart != null && _activeRangeEnd != null)
                        ? (a.numberInSurah >= _activeRangeStart! && a.numberInSurah <= _activeRangeEnd!)
                        : false;
                    final bool isCurrentlyPlaying = _currentPlayingVerseNumber != null
                        ? _currentPlayingVerseNumber == a.numberInSurah
                        : false;
                    final bool isSelected = _selectedAyah == a.number;
                    final theme = Theme.of(context);
                    final Color playingColor = theme.brightness == Brightness.dark
                        ? const Color(0xFF2C3C57)
                        : const Color(0xFFFFE19C);
                    double baseFontSize = PreferencesService.getFontSize();
                    if (_edition.isTranslation) {
                      baseFontSize = (baseFontSize - 4).clamp(12.0, 48.0) as double;
                    }
                    final TextStyle baseStyle = _arabicTextStyle(
                      fontSize: baseFontSize,
                      height: 1.6,
                      color: theme.colorScheme.onSurface,
                    );
                    return ListTile(
                      key: tileKey,
                      dense: true,
                      tileColor: isCurrentlyPlaying
                          ? playingColor
                          : isSelected
                              ? theme.colorScheme.primaryContainer.withOpacity(0.35)
                              : isInActiveRange
                                  ? theme.colorScheme.surfaceVariant.withOpacity(0.3)
                                  : null,
                      title: Directionality(
                        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                        child: RichText(
                          textAlign: rtl ? TextAlign.right : TextAlign.left,
                      text: TextSpan(
                        style: baseStyle,
                        children: [
                          TextSpan(
                            text: a.text,
                            style: baseStyle,
                          ),
                        ],
                      ),
                        ),
                      ),
                      onTap: () => _selectAyah(a),
                      trailing: CircleAvatar(
                        radius: 12,
                        child: Text('${a.numberInSurah}', style: const TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VersePlaybackEntry {
  final String url;
  final int globalAyahNumber;
  final int verseInSurah;
  final String reciterName;
  final String reciterKey;
  final int repeatIndex;
  final int repeatCount;

  const _VersePlaybackEntry({
    required this.url,
    required this.globalAyahNumber,
    required this.verseInSurah,
    required this.reciterName,
    required this.reciterKey,
    required this.repeatIndex,
    required this.repeatCount,
  });
}


