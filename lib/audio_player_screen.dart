import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qurani/providers/audio_providers.dart';
import 'package:qurani/services/media_item_compat.dart';

import 'l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'audio_player/bookmarks_sheet.dart';
import 'audio_player/download_prompt_dialog.dart';
import 'audio_player/duration_formatter.dart';
import 'audio_player/queue_section.dart';
import 'audio_player/sleep_timer_dialog.dart' as sleep_dlg;
import 'audio_player/speed_dialog.dart';
import 'audio_player/transport_controls.dart';
import 'models/surah.dart';
import 'models/audio_bookmark.dart';
import 'services/audio_service.dart';
import 'services/download_service.dart';
import 'services/preferences_service.dart';
import 'services/surah_service.dart';
import 'widgets/sound_equalizer.dart';
import 'widgets/modern_ui.dart';
import 'services/queue_service.dart';
import 'services/net_utils.dart';
import 'util/debug_error_display.dart';

/// Main audio player screen that handles full-surah playback, repeat, auto
/// advance and verse-by-verse playback.
class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key, required this.initialSurahOrder});

  final int initialSurahOrder;

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  final QueueService _queueService = QueueService();

  List<Surah> _surahs = const [];
  int _currentOrder = 1;
  String? _reciterKey;
  List<int> _queue = const [];
  Set<int> _featuredListenSurahs = <int>{};

  bool _isRepeat = false;
  bool _autoPlayNext = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _verseByVerseMode = false;
  bool _isHandlingCompletion = false;
  bool _isCurrentSurahDownloaded = false;
  bool _isDownloadingCurrentSurah = false;

  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  final double _equalizerHeight = 120;

  String? _errorMessage;

  Duration? _currentTrackDuration;
  Duration? _savedSurahPositionBeforeVerseMode;

  int _currentVerse = 1;
  List<String>? _verseUrls;

  Timer? _sleepTimer;
  int? _sleepTimerMinutes;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<ProcessingState>? _processingStateSub;
  StreamSubscription<int?>? _currentIndexSub;
  StreamSubscription<PlaybackEvent>? _playbackEventSub;
  bool _isPlayerDisposed = false;

  // ── Fix: generation counter to cancel stale async operations ──
  /// Monotonic counter; incremented on every surah/verse change to cancel
  /// stale idle-retry and playlist mutation operations.
  int _playbackGeneration = 0;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.initialSurahOrder;
    _reciterKey = PreferencesService.getReciter();
    _queue = ref.read(queueProvider);
    _autoPlayNext = PreferencesService.getAutoPlayNextSurah();
    _isRepeat = PreferencesService.getIsRepeat();

    // Enforce mutual exclusivity on load
    if (_isRepeat) {
      _autoPlayNext = false;
    }

    // Apply initial loop mode
    _player.setLoopMode(_isRepeat ? LoopMode.one : LoopMode.off);

    _featuredListenSurahs = PreferencesService.getListenFeaturedSurahs();
    _player.setSpeed(_playbackSpeed);
    _player.setVolume(_volume);
    _setupListeners();
    unawaited(_configureAudioSession());
    unawaited(_loadInitialData());
    // Ensure download button state reflects existing offline file immediately
    unawaited(_updateDownloadStatus());
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _processingStateSub?.cancel();
    _currentIndexSub?.cancel();
    _playbackEventSub?.cancel();
    unawaited(_disposePlayer());
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    if (_isPlayerDisposed) return;
    _isPlayerDisposed = true;
    try {
      await _player.stop();
    } catch (_) {
      // ignore stop failures during disposal
    }
    await _player.dispose();
  }

  void _setupListeners() {
    if (_isPlayerDisposed) return;
    _positionSub = _player.positionStream.listen((position) {
      // Save position periodically (e.g. every 5 seconds) or check if we should save on pause?
      // For simplicity and performance, saving on every update is too much.
      // We can rely on _handlePlayerStateChange for Pause/Stop.
      // But if app is killed, we might lose progress.
      // Let's save every 5 seconds if playing.
      if (_player.playing && position.inSeconds % 5 == 0) {
        PreferencesService.saveLastPlaybackPosition(
            _currentOrder, position.inMilliseconds);
      }
    });

    _durationSub = _player.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      final sequence = _player.sequenceState;
      final tag = sequence?.currentSource?.tag;
      final isPlaceholder =
          tag is MediaItem && (tag.extras?['placeholder'] as String?) != null;
      if (!isPlaceholder) {
        _currentTrackDuration = duration;
      }
    });

    _playerStateSub =
        _player.playerStateStream.listen(_handlePlayerStateChange);
    _processingStateSub =
        _player.processingStateStream.listen(_handleProcessingChange);
    _currentIndexSub =
        _player.currentIndexStream.listen(_onCurrentIndexChanged);
    _playbackEventSub = _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        if (e is PlatformException) {
          debugPrint('[AudioPlayer] Playback Error: ${e.message}');
          // If error occurs, we might need to reload current.
          // Usually just_audio propagates this to processingState idle or error.
        }
      },
    );
  }

  Future<void> _onCurrentIndexChanged(int? index) async {
    if (index == null || !_isPlaying || _verseByVerseMode) return;
    
    final sequence = _player.sequence;
    if (sequence == null || index >= sequence.length) return;
    final item = sequence[index].tag as MediaItem;
    final newOrder = item.extras?['surahOrder'] as int?;
    if (newOrder == null || newOrder == _currentOrder) return;

    // We moved! Update state and cancel any stale operations
    _playbackGeneration++;
    final generation = _playbackGeneration;

    if (mounted) {
      setState(() {
        _currentOrder = newOrder;
      });
    }
    _updateDownloadStatus();
    PreferencesService.addToHistory(newOrder, _reciterKey!);

    final playlist = _player.audioSource as ConcatenatingAudioSource?;
    if (playlist == null) return;

    // If queue is active and matches newOrder, dequeue it
    final queued = _queueService.getNext(peek: true);
    if (queued == newOrder) {
      _queueService.getNext(); // pop it
    }

    // --- Self-healing Sliding Window: [Previous, Current, Next] ---
    
    // 1. Cull old 'Previous' items (index should shift down to 1 or 0)
    while ((_player.currentIndex ?? 0) > 1) {
      if (_playbackGeneration != generation || _player.audioSource != playlist) return;
      await playlist.removeAt(0);
    }

    // 2. Insert new 'Previous' if we are at index 0 and a previous surah exists
    if ((_player.currentIndex ?? 0) == 0 && newOrder > 1) {
      final prevOrder = newOrder - 1;
      final prevSource = await _buildAudioSource(prevOrder);
      if (_playbackGeneration != generation || _player.audioSource != playlist) return;
      if (prevSource != null) {
        // Inserting at 0 while playing at 0 automatically shifts the current index to 1
        await playlist.insert(0, prevSource);
      }
    }

    // 3. Cull old 'Next' items
    while (playlist.length > (_player.currentIndex ?? 0) + 2) {
      if (_playbackGeneration != generation || _player.audioSource != playlist) return;
      await playlist.removeAt(playlist.length - 1);
    }

    // 4. Append new 'Next' if we don't have one
    if (playlist.length == (_player.currentIndex ?? 0) + 1) {
      AudioSource? nextSource;
      final nextQ = _queueService.getNext(peek: true);
      if (nextQ != null) {
        nextSource = await _buildAudioSource(nextQ);
      } else if (_autoPlayNext && !_isRepeat && newOrder < 114) {
        nextSource = await _buildAudioSource(newOrder + 1);
      }
      
      if (_playbackGeneration != generation || _player.audioSource != playlist) return;
      if (nextSource != null) {
        await playlist.add(nextSource);
      }
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      debugPrint('[AudioPlayer] Configuring audio session...');
      final session = await AudioSession.instance;
      debugPrint('[AudioPlayer] Audio session obtained successfully');

      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      debugPrint('[AudioPlayer] Audio session configured successfully');

      session.interruptionEventStream.listen((event) {
        debugPrint(
            '[AudioPlayer] Audio interruption: ${event.begin} - ${event.type}');
        if (event.begin) {
          // Only pause if it's a permanent interruption (like a phone call)
          if (event.type == AudioInterruptionType.duck) {
            // Don't pause for ducking, just lower volume
            debugPrint('[AudioPlayer] Ducking audio');
          } else if (event.type == AudioInterruptionType.pause) {
            if (_player.playing) {
              debugPrint('[AudioPlayer] Pausing due to interruption');
              _player.pause();
            }
          }
        } else {
          debugPrint('[AudioPlayer] Resuming after interruption');
          if (!_isPlayerDisposed && mounted && _isPlaying) {
            _player.play();
          }
        }
      });

      debugPrint(
          '[AudioPlayer] Audio session configured for background playback');
    } catch (e, stackTrace) {
      debugPrint('[AudioPlayer] CRITICAL ERROR configuring audio session: $e');
      debugPrint('[AudioPlayer] Stack trace: $stackTrace');
      // Continue anyway - some devices may work without explicit configuration
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final lang = PreferencesService.getLanguage();
      final surahs = await SurahService.getLocalizedSurahs(lang);
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _featuredListenSurahs = PreferencesService.getListenFeaturedSurahs();
      });
      await _playSurah(_currentOrder, autoPlay: true);
    } catch (e) {
      debugPrint('Error loading surahs: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _playSurah(
    int order, {
    bool autoPlay = true,
    Duration? resumePosition,
  }) async {
    if (_isPlayerDisposed) return;
    _playbackGeneration++; // Cancel stale async operations
    final normalizedOrder = order.clamp(1, 114);
    setState(() {
      _currentOrder = normalizedOrder;
    });

    await _loadVerseUrls(normalizedOrder);

    Duration startPosition;
    if (resumePosition != null) {
      startPosition = resumePosition;
    } else {
      if (PreferencesService.getAlwaysStartFromBeginning()) {
        startPosition = Duration.zero;
      } else {
        final lastPosMs =
            PreferencesService.getLastPlaybackPosition(normalizedOrder);
        startPosition =
            lastPosMs > 0 ? Duration(milliseconds: lastPosMs) : Duration.zero;
      }
    }

    await _loadAndPlaySurah(normalizedOrder, startPosition, autoPlay: autoPlay);
    await _updateDownloadStatus();
  }

  Future<void> _loadAndPlaySurah(
    int order,
    Duration startPosition, {
    required bool autoPlay,
  }) async {
    if (_isPlayerDisposed) return;
    if (_reciterKey == null || _reciterKey!.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectReciterFirst)),
      );
      return;
    }

    final url = await AudioService.buildFullRecitationUrl(
      reciterKeyAr: _reciterKey!,
      surahOrder: order,
    );
    if (url == null) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (mounted) {
        setState(() {
          _errorMessage = l10n.surahUnavailable;
          _isCurrentSurahDownloaded = false;
        });
      }
      return;
    }

    int retryCount = 0;
    const maxRetries = 3;

    while (true) {
      try {
        final localPath =
            await DownloadService.localSurahPath(_reciterKey!, order);
        final hasLocalFile =
            await DownloadService.isSurahDownloaded(_reciterKey!, order);
        final langCode = PreferencesService.getLanguage();
        final reciterName =
            AudioService.reciterDisplayName(_reciterKey!, langCode);
        final currentSurah = _surahs.firstWhere(
          (s) => s.order == order,
          orElse: () =>
              Surah(name: 'Surah $order', order: order, totalVerses: 0),
        );

        final mainItem = MediaItem(
          id: '${_reciterKey!}_$order',
          title: currentSurah.name,
          album: reciterName,
          extras: {'surahOrder': order},
        );

        // Initial Playlist Setup: [Previous (optional), Current, Next (optional)]
        final playlistChildren = <AudioSource>[];
        int initialIndex = 0;

        // 1. Preload Previous
        if (order > 1 && !_verseByVerseMode) {
          try {
            final prevSource = await _buildAudioSource(order - 1);
            if (prevSource != null) {
              playlistChildren.add(prevSource);
              initialIndex = 1;
            }
          } catch (e) {
            debugPrint('Error preloading previous surah: $e');
          }
        }

        // 2. Add Current
        final source = hasLocalFile
            ? AudioSource.uri(Uri.file(localPath), tag: mainItem)
            : AudioSource.uri(Uri.parse(url), tag: mainItem);

        playlistChildren.add(source);

        // 3. Preload Next
        if (!_verseByVerseMode) {
          final nextQueued = _queueService.getNext(peek: true);
          if (nextQueued != null) {
            try {
              final nextSource = await _buildAudioSource(nextQueued);
              if (nextSource != null) playlistChildren.add(nextSource);
            } catch (e) {
              debugPrint('Error preloading next queued surah: $e');
            }
          } else if (_autoPlayNext && !_isRepeat && order < 114) {
            try {
              final nextSource = await _buildAudioSource(order + 1);
              if (nextSource != null) playlistChildren.add(nextSource);
            } catch (e) {
              debugPrint('Error preloading next surah: $e');
            }
          }
        }

        final playlist = ConcatenatingAudioSource(
          children: playlistChildren,
          useLazyPreparation: true,
          shuffleOrder: DefaultShuffleOrder(),
        );

        debugPrint(
            '[AudioPlayer] Setting playlist with ${playlistChildren.length} items (initialIndex=$initialIndex)');

        try {
          await _player.setAudioSource(
            playlist,
            initialIndex: initialIndex,
            initialPosition: startPosition,
          );
          debugPrint('[AudioPlayer] Audio source set successfully');
        } catch (e, stackTrace) {
          debugPrint('[AudioPlayer] CRITICAL ERROR setting audio source: $e');
          debugPrint('[AudioPlayer] Stack trace: $stackTrace');
          throw Exception('Failed to load audio: ${e.toString()}');
        }

        if (autoPlay) {
          try {
            await _player.play();
            debugPrint('[AudioPlayer] Playback started');
          } catch (e) {
            debugPrint('[AudioPlayer] ERROR starting playback: $e');
            throw Exception('Failed to start playback: ${e.toString()}');
          }
        } else {
          await _player.pause();
        }

        if (mounted) {
          setState(() {
            _isPlaying = autoPlay;
            _isBuffering = false;
            _errorMessage = null;
            _isCurrentSurahDownloaded = hasLocalFile;
          });
        }

        await PreferencesService.addToHistory(order, _reciterKey!);
        break; // Success, exit loop
      } catch (e, stackTrace) {
        debugPrint(
            '[AudioPlayer] Error loading surah audio (attempt ${retryCount + 1}): $e');

        retryCount++;
        if (retryCount >= maxRetries) {
          debugPrint('[AudioPlayer] Max retries reached. Showing error.');
          debugPrint('[AudioPlayer] Final Stack trace: $stackTrace');

          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;

          // Show debug error dialog
          DebugErrorDisplay.showError(
            context,
            screen: 'Audio Player',
            operation: 'Load Surah $order',
            error: e.toString(),
            stackTrace: stackTrace.toString(),
          );
          String userMessage = l10n.errorLoadingAudio;

          if (e.toString().contains('Permission')) {
            userMessage =
                'Audio permission required. Please grant permission in settings.';
          } else if (e.toString().contains('Network') ||
              e.toString().contains('Connection')) {
            userMessage =
                'Network error. Please check your internet connection.';
          } else if (e.toString().contains('Format') ||
              e.toString().contains('Codec')) {
            userMessage = 'Audio format not supported on this device.';
          }

          if (mounted) {
            setState(() {
              _errorMessage = userMessage;
              _isBuffering = false;
              _isCurrentSurahDownloaded = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userMessage),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () {},
                ),
              ),
            );
          }
          break; // Exit loop after handling final error
        } else {
          // Wait before retrying (exponential backoff could be used, but simple delay is fine)
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }
  }

  Future<AudioSource?> _buildAudioSource(int order) async {
    final url = await AudioService.buildFullRecitationUrl(
      reciterKeyAr: _reciterKey!,
      surahOrder: order,
    );
    if (url == null) return null;

    final localPath = await DownloadService.localSurahPath(_reciterKey!, order);
    final hasLocalFile =
        await DownloadService.isSurahDownloaded(_reciterKey!, order);
    final langCode = PreferencesService.getLanguage();
    final reciterName = AudioService.reciterDisplayName(_reciterKey!, langCode);
    // Ensure _surahs is populated or get safe name
    final surahName = (order <= _surahs.length && order > 0)
        ? _surahs
            .firstWhere((s) => s.order == order,
                orElse: () =>
                    Surah(name: 'Surah $order', order: order, totalVerses: 0))
            .name
        : 'Surah $order';

    final mainItem = MediaItem(
      id: '${_reciterKey!}_$order',
      title: surahName,
      album: reciterName,
      extras: {'surahOrder': order},
    );

    return hasLocalFile
        ? AudioSource.uri(Uri.file(localPath), tag: mainItem)
        : AudioSource.uri(Uri.parse(url), tag: mainItem);
  }

  void _handlePlayerStateChange(PlayerState state) {
    if (!mounted) return;
    if (_isPlayerDisposed) return;

    final buffering = state.processingState == ProcessingState.buffering;
    if (buffering != _isBuffering) {
      setState(() => _isBuffering = buffering);
    }

    final playing = state.playing;
    if (playing != _isPlaying) {
      setState(() => _isPlaying = playing);
      if (!playing) {
        final pos = _player.position;
        PreferencesService.saveLastPlaybackPosition(
            _currentOrder, pos.inMilliseconds);
      }
    }

    if (state.processingState == ProcessingState.completed) {
      unawaited(_handlePlaybackCompleted());
    }
  }

  void _handleProcessingChange(ProcessingState state) {
    if (!mounted) return;
    if (_isPlayerDisposed) return;
    final buffering = state == ProcessingState.buffering;
    if (buffering != _isBuffering) {
      setState(() => _isBuffering = buffering);
    }

    // Fix 1+3+5: Auto-retry logic for background timeouts.
    // Skip retry when in verse-by-verse mode (verse transitions cause
    // transient idle states) and use generation counter to cancel stale
    // retries that would overwrite a user's manual surah change.
    if (state == ProcessingState.idle &&
        _isPlaying &&
        !_isHandlingCompletion &&
        !_verseByVerseMode) {
      final generation = _playbackGeneration;
      debugPrint(
          '[AudioPlayer] Unexpected Idle State detected (Background kill?). Retrying in 5s... (gen=$generation)');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted &&
            _isPlaying &&
            !_isHandlingCompletion &&
            !_verseByVerseMode &&
            _playbackGeneration == generation &&
            _player.processingState == ProcessingState.idle) {
          debugPrint(
              '[AudioPlayer] Retrying playback of Order: $_currentOrder (gen=$generation)');
          final pos = _player.position;
          final safePos = pos > Duration.zero ? pos : Duration.zero;
          _loadAndPlaySurah(_currentOrder, safePos, autoPlay: true);
        }
      });
    }
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_isHandlingCompletion) return;
    if (_isPlayerDisposed) return;
    _isHandlingCompletion = true;
    try {
      if (_verseByVerseMode && _verseUrls != null && _currentSurah != null) {
        final total = _currentSurah!.totalVerses;
        if (_currentVerse < total) {
          await _playVerse(_currentVerse + 1);
        } else if (_isRepeat && total > 0) {
          await _playVerse(1);
        } else {
          await _seekToCurrentStart(play: false);
          setState(() => _isPlaying = false);
        }
        return;
      }

      // For full surah mode, LoopMode.all handles repeat automatically.
      // ConcatenatingAudioSource handles transitions to next surah.
      // We only need to handle the end of playlist when NOT repeating.
      if (_player.nextIndex == null && !_isRepeat) {
        // End of playlist and not repeating - stop playback
        await _seekToCurrentStart(play: false);
        setState(() => _isPlaying = false);
      }
      // If _isRepeat is true, LoopMode.all will automatically restart the playlist
    } finally {
      _isHandlingCompletion = false;
    }
  }

  Future<void> _goToNextSurah() async {
    if (_isPlayerDisposed) return;
    _playbackGeneration++;
    final nextOrder = (_currentOrder >= 114) ? 114 : _currentOrder + 1;
    await _playSurah(nextOrder, autoPlay: true, resumePosition: Duration.zero);
  }

  Future<void> _goToPreviousSurah() async {
    if (_isPlayerDisposed) return;
    _playbackGeneration++;
    final prevOrder = (_currentOrder <= 1) ? 1 : _currentOrder - 1;
    await _playSurah(prevOrder, autoPlay: true, resumePosition: Duration.zero);
  }

  Future<void> _seekRelative(Duration delta) async {
    if (_isPlayerDisposed) return;
    final position = _player.position;
    final duration = _player.duration ?? Duration.zero;
    final target = position + delta;

    if (target <= Duration.zero) {
      await _player.seek(Duration.zero);
    } else if (target >= duration) {
      await _player.seek(duration);
    } else {
      await _player.seek(target);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlayerDisposed) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      _player.setVolume(_volume);
      await _player.play();
    }
  }

  Future<void> _seekToCurrentStart({required bool play}) async {
    if (_isPlayerDisposed) return;
    await _player.seek(Duration.zero);
    if (play) {
      await _player.play();
    } else {
      await _player.pause();
    }
  }

  Future<void> _updateDownloadStatus() async {
    if (_reciterKey == null || _reciterKey!.isEmpty) return;
    if (_isPlayerDisposed) return;
    try {
      final downloaded =
          await DownloadService.isSurahDownloaded(_reciterKey!, _currentOrder);
      if (mounted) {
        setState(() => _isCurrentSurahDownloaded = downloaded);
      }
    } catch (e) {
      debugPrint('Error checking download status: $e');
    }
  }

  Future<void> _addBookmark() async {
    if (_isPlayerDisposed) return;
    final position = _player.position;
    final l10n = AppLocalizations.of(context)!;

    // Optional: Ask for note? For now just save with timestamp/date
    final bookmark = AudioBookmark.create(
      surahId: _currentOrder,
      positionMs: position.inMilliseconds,
      reciterId: _reciterKey,
    );

    await PreferencesService.saveAudioBookmark(bookmark);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bookmarkSaved)),
      );
    }
  }

  Future<void> _showBookmarksDialog() {
    return showAudioBookmarksSheet(
      context,
      currentSurahOrder: _currentOrder,
      surahs: _surahs,
      onPlayBookmark: _playBookmark,
    );
  }

  Future<void> _playBookmark(AudioBookmark bm) async {
    if (bm.surahId != _currentOrder) {
      await _playSurah(bm.surahId,
          autoPlay: true,
          resumePosition: Duration(milliseconds: bm.positionMs));
    } else {
      await _player.seek(Duration(milliseconds: bm.positionMs));
      if (!_player.playing) {
        await _player.play();
      }
    }
  }

  Future<void> _promptDownloadCurrentSurah() async {
    if (_reciterKey == null || _reciterKey!.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isDownloadingCurrentSurah = true);
    final result = await promptAndDownloadSurah(
      context,
      reciterKey: _reciterKey!,
      surahOrder: _currentOrder,
    );

    if (!mounted) return;

    setState(() {
      _isDownloadingCurrentSurah = false;
      if (result.success) {
        _isCurrentSurahDownloaded = true;
      }
    });

    if (result.cancelled) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.downloadComplete)),
      );
    } else {
      final message = (result.error != null && result.error!.isNotEmpty)
          ? '${l10n.downloadFailed}: ${result.error}'
          : l10n.downloadFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showSpeedDialog(BuildContext context) {
    showPlaybackSpeedDialog(
      context,
      initialSpeed: _playbackSpeed,
      player: _player,
      onChanged: (value) {
        if (!mounted) return;
        setState(() => _playbackSpeed = value);
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    sleep_dlg.showSleepTimerDialog(
      context,
      currentMinutes: _sleepTimerMinutes,
      onSet: _setSleepTimer,
    );
  }

  void _setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    if (minutes == null) {
      setState(() {
        _sleepTimer = null;
        _sleepTimerMinutes = null;
      });
      return;
    }

    setState(() => _sleepTimerMinutes = minutes);
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await _player.pause();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sleepTimerEnded)),
        );
      }
    });
  }

  Future<void> _shareSurah() async {
    if (_reciterKey == null || _reciterKey!.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final url = await AudioService.buildFullRecitationUrl(
      reciterKeyAr: _reciterKey!,
      surahOrder: _currentOrder,
    );

    if (url == null) return;

    final langCode = PreferencesService.getLanguage();
    final reciterName = AudioService.reciterDisplayName(_reciterKey!, langCode);
    final surahName = _currentSurah?.name ?? 'Surah $_currentOrder';

    final message = l10n.shareSurahMessage(surahName, reciterName, url);

    // Calculate share position origin for iPad
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;

    // ignore: deprecated_member_use
    await Share.share(
      message,
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _loadVerseUrls(int surahOrder) async {
    if (_reciterKey == null || _reciterKey!.isEmpty) return;
    final surah = _currentSurah;
    if (surah == null) return;

    _verseUrls = await AudioService.buildVerseUrls(
      reciterKeyAr: _reciterKey!,
      surahOrder: surahOrder,
      totalVerses: surah.totalVerses,
    );
  }

  Future<void> _playVerse(int verseNumber) async {
    if (_isPlayerDisposed) return;
    _playbackGeneration++; // Cancel stale idle-retry
    if (_verseUrls == null ||
        verseNumber < 1 ||
        verseNumber > (_verseUrls?.length ?? 0) ||
        _reciterKey == null ||
        _reciterKey!.isEmpty) {
      return;
    }

    final surah = _currentSurah;
    if (surah == null) return;
    if (_isPlayerDisposed) return;

    final uri = await AudioService.getVerseUriPreferLocal(
      reciterKeyAr: _reciterKey!,
      surahOrder: surah.order,
      verseNumber: verseNumber,
    );
    if (uri == null) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorLoadingAudio)));
      }
      return;
    }

    // If not local file and no internet, show a clear message
    if (uri.scheme != 'file') {
      final hasNet = await _checkInternet();
      if (!hasNet) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.audioInternetRequired)));
        }
        return;
      }
    }
    final langCode = PreferencesService.getLanguage();
    final reciterName = AudioService.reciterDisplayName(_reciterKey!, langCode);

    final mediaItem = MediaItem(
      id: '${_reciterKey!}_${surah.order}_verse_$verseNumber',
      title: '${surah.name} • Ayah $verseNumber',
      album: reciterName,
      extras: {
        'surahOrder': surah.order,
        'verse': verseNumber,
        'verseMode': true,
      },
    );

    try {
      debugPrint('[AudioPlayer] Playing verse $verseNumber');

      try {
        await _player.setAudioSource(AudioSource.uri(uri, tag: mediaItem));
      } catch (e, stackTrace) {
        debugPrint('[AudioPlayer] ERROR setting verse audio source: $e');
        debugPrint('[AudioPlayer] Stack trace: $stackTrace');
        throw Exception('Failed to load verse audio: ${e.toString()}');
      }

      await _player.setLoopMode(LoopMode.off);
      await _player.play();

      if (mounted) {
        setState(() {
          _currentVerse = verseNumber;
          _isPlaying = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[AudioPlayer] CRITICAL ERROR playing verse: $e');
      debugPrint('[AudioPlayer] Stack trace: $stackTrace');

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _errorMessage = l10n.errorLoadingAudio);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorLoadingAudio),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Surah? get _currentSurah =>
      _surahs.where((s) => s.order == _currentOrder).cast<Surah?>().firstOrNull;

  Surah? _findSurah(int order) {
    for (final surah in _surahs) {
      if (surah.order == order) return surah;
    }
    return null;
  }

  Future<bool> _checkInternet() async {
    return NetUtils.hasInternet();
  }

  Future<void> _toggleFeature(int order) async {
    final featured = await PreferencesService.toggleListenFeaturedSurah(order);
    if (!mounted) return;
    setState(() {
      if (featured) {
        _featuredListenSurahs.add(order);
      } else {
        _featuredListenSurahs.remove(order);
      }
    });
  }

  void _toggleQueueEntry(int order) {
    final inQueue = _queue.contains(order);
    if (inQueue) {
      _queueService.removeFromQueue(order);
    } else {
      _queueService.addToQueue(order);
    }
  }

  Widget _buildVerseControls(ColorScheme color, bool isRtl) {
    if (!_verseByVerseMode || _verseUrls == null || _currentSurah == null) {
      return const SizedBox.shrink();
    }

    final total = _currentSurah!.totalVerses;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ModernSurfaceCard(
        child: Column(
          children: [
            Text(
              '${AppLocalizations.of(context)!.currentVerse}: $_currentVerse / ${_currentSurah!.totalVerses}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isRtl
                  ? [
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: _currentVerse > 1
                            ? () => _playVerse(_currentVerse - 1)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Slider(
                          value: _currentVerse.toDouble(),
                          min: 1,
                          max: total.toDouble(),
                          divisions: total - 1,
                          label: '$_currentVerse',
                          onChanged: (value) => _playVerse(value.toInt()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: _currentVerse < total
                            ? () => _playVerse(_currentVerse + 1)
                            : null,
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: _currentVerse > 1
                            ? () => _playVerse(_currentVerse - 1)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Slider(
                          value: _currentVerse.toDouble(),
                          min: 1,
                          max: total.toDouble(),
                          divisions: total - 1,
                          label: '$_currentVerse',
                          onChanged: (value) => _playVerse(value.toInt()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: _currentVerse < total
                            ? () => _playVerse(_currentVerse + 1)
                            : null,
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      ColorScheme color, bool isRtl, String title, String reciterName) {
    final l10n = AppLocalizations.of(context)!;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _buildTopSection(color, isRtl, title, reciterName),
          ),
        ),
        if (_queue.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AudioPlayerQueueSection(
                queue: _queue,
                currentOrder: _currentOrder,
                findSurah: _findSurah,
                color: color,
                onPlayOrder: (order) => _playSurah(
                  order,
                  autoPlay: true,
                  resumePosition: Duration.zero,
                ),
                onRemoveOrder: _queueService.removeFromQueue,
                onClearQueue: _queueService.clearQueue,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${l10n.listenQuran} (${l10n.queue})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color.onSurface,
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final surah = _surahs[index];
              return AudioPlayerPlaylistTile(
                surah: surah,
                currentOrder: _currentOrder,
                isFeatured: _featuredListenSurahs.contains(surah.order),
                inQueue: _queue.contains(surah.order),
                color: color,
                isRtl: isRtl,
                onPlay: () => _playSurah(
                  surah.order,
                  autoPlay: true,
                  resumePosition: Duration.zero,
                ),
                onToggleQueue: () => _toggleQueueEntry(surah.order),
                onToggleFeature: () => _toggleFeature(surah.order),
              );
            },
            childCount: _surahs.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildTopSection(
      ColorScheme color, bool isRtl, String title, String reciterName) {
    final l10n = AppLocalizations.of(context)!;
    final durationStream = StreamBuilder<Duration?>(
      stream: _player.durationStream,
      builder: (context, snapshot) {
        final duration =
            _currentTrackDuration ?? snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            final double maxPosition = duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0;
            final double sliderValue = duration.inMilliseconds > 0
                ? pos.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble()
                : 0.0;
            return Column(
              children: [
                Slider(
                  min: 0,
                  max: maxPosition,
                  value: sliderValue,
                  onChanged: (value) =>
                      _player.seek(Duration(milliseconds: value.toInt())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatPlaybackDuration(pos),
                      style: TextStyle(
                          color:
                              color.onSurface.withAlpha((255 * 0.7).round())),
                    ),
                    Text(
                      formatPlaybackDuration(duration),
                      style: TextStyle(
                          color:
                              color.onSurface.withAlpha((255 * 0.7).round())),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    return ModernSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: color.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: color.onErrorContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: _retry,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          if (_isBuffering)
            LinearProgressIndicator(
              backgroundColor: color.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color.primary),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          durationStream,
          if (reciterName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Center(
                child: Text(
                  reciterName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SoundEqualizer(
            player: _player,
            height: _equalizerHeight,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _volume == 0.0
                      ? Icons.volume_off
                      : _volume < 0.5
                          ? Icons.volume_down
                          : Icons.volume_up,
                ),
                iconSize: 24,
                onPressed: () {
                  setState(() {
                    _volume = _volume > 0.0 ? 0.0 : 1.0;
                    _player.setVolume(_volume);
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    setState(() => _volume = value);
                    _player.setVolume(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 50,
                child: Text(
                  '${(_volume * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: color.onSurface.withAlpha((255 * 0.7).round()),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AudioPlayerTransportControls(
            player: _player,
            isRtl: isRtl,
            color: color,
            onPrevious: _goToPreviousSurah,
            onNext: _goToNextSurah,
            onSeekBack10: () => _seekRelative(const Duration(seconds: -10)),
            onSeekForward10: () => _seekRelative(const Duration(seconds: 10)),
            onTogglePlayPause: _togglePlayPause,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.repeatSurah),
                selected: _isRepeat,
                onSelected: (value) {
                  setState(() {
                    _isRepeat = value;
                    if (value) {
                      _verseByVerseMode = false;
                      _autoPlayNext = false;
                      _player.setLoopMode(LoopMode.one);
                    } else {
                      _player.setLoopMode(LoopMode.off);
                    }
                  });
                  if (value) {
                    PreferencesService.saveAutoPlayNextSurah(false);
                  }
                  PreferencesService.saveIsRepeat(value);
                },
              ),
              FilterChip(
                label: Text(l10n.autoPlayNext),
                selected: _autoPlayNext,
                onSelected: (value) async {
                  setState(() {
                    _autoPlayNext = value;
                    if (value) {
                      _isRepeat = false;
                      _verseByVerseMode = false;
                      _player.setLoopMode(LoopMode.off);
                    }
                  });
                  PreferencesService.saveAutoPlayNextSurah(value);
                  PreferencesService.saveIsRepeat(_isRepeat);

                  if (value && !_isPlayerDisposed) {
                    final currentPos = _player.position;
                    await _playSurah(_currentOrder,
                        autoPlay: _isPlaying, resumePosition: currentPos);
                  }
                },
              ),
              FilterChip(
                label: Text(l10n.verseByVerse),
                selected: _verseByVerseMode,
                onSelected: (value) async {
                  if (value) {
                    final currentPos = _player.position;
                    setState(() {
                      _savedSurahPositionBeforeVerseMode = currentPos;
                      _verseByVerseMode = true;
                      _isRepeat = false;
                      _autoPlayNext = false;
                      _currentVerse = 1;
                    });
                    await _loadVerseUrls(_currentOrder);
                    if (_verseUrls != null && _verseUrls!.isNotEmpty) {
                      await _playVerse(1);
                    }
                  } else {
                    final resume = _savedSurahPositionBeforeVerseMode;
                    setState(() {
                      _verseByVerseMode = false;
                      _verseUrls = null;
                      _currentVerse = 1;
                    });
                    await _playSurah(
                      _currentOrder,
                      autoPlay: _player.playing,
                      resumePosition: resume,
                    );
                    setState(() => _savedSurahPositionBeforeVerseMode = null);
                  }
                },
              ),
            ],
          ),
          _buildVerseControls(color, isRtl),
        ],
      ),
    );
  }

  void _retry() {
    unawaited(_playSurah(_currentOrder, autoPlay: _player.playing));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<int>>(queueProvider, (prev, next) {
      if (!mounted) return;
      setState(() => _queue = next);
    });
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final surahTitle = _currentSurah?.name ?? 'Surah $_currentOrder';
    final langCode = Localizations.localeOf(context).languageCode;
    final reciterName = _reciterKey != null && _reciterKey!.isNotEmpty
        ? AudioService.reciterDisplayName(_reciterKey!, langCode)
        : '';

    return ModernPageScaffold(
      title: surahTitle,
      icon: Icons.headphones_rounded,
      subtitle: reciterName.isNotEmpty ? reciterName : l10n.listenQuran,
      actions: [
        if (!kIsWeb && !_isCurrentSurahDownloaded)
          _isDownloadingCurrentSurah
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: l10n.download,
                  onPressed: _promptDownloadCurrentSurah,
                ),
        IconButton(
          icon: const Icon(Icons.speed_rounded),
          tooltip: l10n.playbackSpeed,
          onPressed: () => _showSpeedDialog(context),
        ),
        IconButton(
          icon: Icon(
              _sleepTimerMinutes != null ? Icons.timer : Icons.timer_outlined),
          tooltip: l10n.sleepTimer,
          onPressed: () => _showSleepTimerDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.bookmark_add_rounded),
          tooltip: l10n.bookmark,
          onPressed: _addBookmark,
        ),
        IconButton(
          icon: const Icon(Icons.list_rounded),
          tooltip: l10n.bookmarks,
          onPressed: _showBookmarksDialog,
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded),
          tooltip: AppLocalizations.of(context)!.share,
          onPressed: _shareSurah,
        ),
      ],
      body: _surahs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(color, isRtl, surahTitle, reciterName),
    );
  }
}

/// Silent audio source used as placeholders for previous/next actions.
extension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
