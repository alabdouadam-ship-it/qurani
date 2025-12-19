import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qurani/services/media_item_compat.dart';

import 'l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'models/surah.dart';
import 'services/audio_service.dart';
import 'services/download_service.dart';
import 'services/preferences_service.dart';
import 'services/surah_service.dart';
import 'widgets/sound_equalizer.dart';
import 'services/queue_service.dart';
import 'services/net_utils.dart';
import 'util/debug_error_display.dart';

/// Main audio player screen that handles full-surah playback, repeat, auto
/// advance and verse-by-verse playback.
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key, required this.initialSurahOrder});

  final int initialSurahOrder;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
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
  Duration? _bookmarkPosition;
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
  VoidCallback? _queueListener;
  bool _isPlayerDisposed = false;

  bool get _hasBookmark => _bookmarkPosition != null;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.initialSurahOrder;
    _reciterKey = PreferencesService.getReciter();
    _queue = _queueService.queue;
    _autoPlayNext = PreferencesService.getAutoPlayNextSurah();
    _featuredListenSurahs = PreferencesService.getListenFeaturedSurahs();
    _queueListener = () {
      if (!mounted) return;
      setState(() {
        _queue = _queueService.queue;
      });
    };
    _queueService.queueNotifier.addListener(_queueListener!);
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
    if (_queueListener != null) {
      _queueService.queueNotifier.removeListener(_queueListener!);
    }
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
         PreferencesService.saveLastPlaybackPosition(_currentOrder, position.inMilliseconds);
      }
    });

    _durationSub = _player.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      final sequence = _player.sequenceState;
      final tag = sequence?.currentSource?.tag;
      final isPlaceholder = tag is MediaItem &&
          (tag.extras?['placeholder'] as String?) != null;
      if (!isPlaceholder) {
        _currentTrackDuration = duration;
      }
    });

    _playerStateSub = _player.playerStateStream.listen(_handlePlayerStateChange);
    _processingStateSub = _player.processingStateStream.listen(_handleProcessingChange);
    _currentIndexSub = _player.currentIndexStream.listen(_onCurrentIndexChanged);
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
    
    // Index 1 implies we moved to the Next track in the playlist
    if (index == 1) {
      final playlist = _player.audioSource as ConcatenatingAudioSource?;
      if (playlist == null) return;

      int nextOrder = -1;
      
      // Check queue first
      // Check queue first
      // NOTE: index changed means we ARE playing playlist[1].
      // playlist[1] corresponds to what we set as Next.
      
       // Dequeue if queue active
       final queued = _queueService.getNext();
       if (queued != null) {
          // We effectively just started playing 'queued'.
          // So 'queued' is now current.
           nextOrder = queued;
           _queueService.removeFromQueue(queued); 
           // BUT wait, if we used peek in _loadAndPlaySurah, we haven't popped it yet?
           // Actually, _loadAndPlaySurah didn't pop.
           // So if we are here, we consumed the peeked item.
           // We should pop it now.
       } else {
           nextOrder = (_currentOrder < 114) ? _currentOrder + 1 : -1;
       }
       
       // Correct logic: rely on MediaItem extras if possible
       final sequence = _player.sequence;
       if (sequence != null && sequence.length > 1) {
          final item = sequence[1].tag as MediaItem;
          final order = item.extras?['surahOrder'] as int?;
          if (order != null) nextOrder = order;
       }

       if (nextOrder != -1) {
          if (mounted) {
             setState(() {
               _currentOrder = nextOrder;
             });
          }
          _updateDownloadStatus();
          PreferencesService.addToHistory(nextOrder, _reciterKey!);
          
          // Maintain Rolling Playlist: [Current, Next]
          // Currently list is [Previous, Current]. Index is 1.
          
          // 1. Prepare NextNext
          AudioSource? nextNextSource;
          final nextQueued = _queueService.getNext(peek: true);
          if (nextQueued != null) {
             nextNextSource = await _buildAudioSource(nextQueued);
          } else if (!_isRepeat && nextOrder < 114) {
             nextNextSource = await _buildAudioSource(nextOrder + 1);
          }

          // 2. Add NextNext to end
           if (nextNextSource != null) {
             await playlist.add(nextNextSource);
           }
           
          // 3. Remove Previous (index 0)
          // removing index 0 changes current index from 1 to 0. This is safe.
          await playlist.removeAt(0);
       }
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      debugPrint('[AudioPlayer] Configuring audio session...');
      final session = await AudioSession.instance;
      debugPrint('[AudioPlayer] Audio session obtained successfully');
      
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await session.setActive(true);
      debugPrint('[AudioPlayer] Audio session configured successfully');
      
      session.interruptionEventStream.listen((event) {
        debugPrint('[AudioPlayer] Audio interruption: ${event.begin} - ${event.type}');
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
      
      debugPrint('[AudioPlayer] Audio session configured for background playback');
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
        final lastPosMs = PreferencesService.getLastPlaybackPosition(normalizedOrder);
        startPosition = lastPosMs > 0 ? Duration(milliseconds: lastPosMs) : Duration.zero;
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

    final url = AudioService.buildFullRecitationUrl(
      reciterKeyAr: _reciterKey!,
      surahOrder: order,
    );
    if (url == null) {
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
        final localPath = await DownloadService.localSurahPath(_reciterKey!, order);
        final hasLocalFile = await DownloadService.isSurahDownloaded(_reciterKey!, order);
        final langCode = PreferencesService.getLanguage();
        final reciterName = AudioService.reciterDisplayName(_reciterKey!, langCode);
        final currentSurah = _surahs.firstWhere(
          (s) => s.order == order,
          orElse: () => Surah(name: 'Surah $order', order: order, totalVerses: 0),
        );

        final mainItem = MediaItem(
          id: '${_reciterKey!}_$order',
          title: currentSurah.name,
          album: reciterName,
          extras: {'surahOrder': order},
        );

        // Initial Playlist Setup: [Current, Next]
        final playlistChildren = <AudioSource>[];
        
        final source = hasLocalFile
            ? AudioSource.uri(Uri.file(localPath), tag: mainItem)
            : AudioSource.uri(Uri.parse(url), tag: mainItem);
            
        playlistChildren.add(source);

        // Preload next surah if available and not repeating single surah
        // (If repeating, we might use LoopMode.one, but here we keep simple auto-advance logic)
        final nextQueued = _queueService.getNext(peek: true);
        if (nextQueued != null) {
           try {
             final nextSource = await _buildAudioSource(nextQueued);
             if (nextSource != null) playlistChildren.add(nextSource);
           } catch (e) {
             debugPrint('Error preloading next queued surah: $e');
           }
        } else if (!_isRepeat && order < 114) {
           try {
             final nextSource = await _buildAudioSource(order + 1);
             if (nextSource != null) playlistChildren.add(nextSource);
           } catch (e) {
             debugPrint('Error preloading next surah: $e');
           }
        }

        final playlist = ConcatenatingAudioSource(
          children: playlistChildren,
          useLazyPreparation: true,
          shuffleOrder: DefaultShuffleOrder(),
        );

        debugPrint('[AudioPlayer] Setting playlist with ${playlistChildren.length} items');
        
        try {
          await _player.setAudioSource(
            playlist,
            initialIndex: 0,
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
        debugPrint('[AudioPlayer] Error loading surah audio (attempt ${retryCount + 1}): $e');
        
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
            userMessage = 'Audio permission required. Please grant permission in settings.';
          } else if (e.toString().contains('Network') || e.toString().contains('Connection')) {
            userMessage = 'Network error. Please check your internet connection.';
          } else if (e.toString().contains('Format') || e.toString().contains('Codec')) {
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
      final url = AudioService.buildFullRecitationUrl(
        reciterKeyAr: _reciterKey!,
        surahOrder: order,
      );
      if (url == null) return null;

      final localPath = await DownloadService.localSurahPath(_reciterKey!, order);
      final hasLocalFile = await DownloadService.isSurahDownloaded(_reciterKey!, order);
      final langCode = PreferencesService.getLanguage();
      final reciterName = AudioService.reciterDisplayName(_reciterKey!, langCode);
      // Ensure _surahs is populated or get safe name
      final surahName = (order <= _surahs.length && order > 0) 
         ? _surahs.firstWhere((s) => s.order == order, orElse: () => Surah(name: 'Surah $order', order: order, totalVerses: 0)).name 
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
        PreferencesService.saveLastPlaybackPosition(_currentOrder, pos.inMilliseconds);
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

    // Auto-retry logic for background timeouts
    if (state == ProcessingState.idle && _isPlaying && !_isHandlingCompletion) {
       debugPrint('[AudioPlayer] Unexpected Idle State detected (Background kill?). Retrying in 5s...');
       Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isPlaying && _player.processingState == ProcessingState.idle) {
             debugPrint('[AudioPlayer] Retrying playback of Order: $_currentOrder');
             // Reload current surah
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

      // For full surah mode, ConcatenatingAudioSource handles transitions automatically.
      // We only need to handle the end of the very last surah or playlist end.
      if (_player.nextIndex == null && !_isRepeat) {
          await _seekToCurrentStart(play: false);
          setState(() => _isPlaying = false);
      } else if (_isRepeat && _player.processingState == ProcessingState.completed) {
           // Repeat logic for single surah handled by LoopMode, but if explicit logic:
           await _playSurah(_currentOrder, autoPlay: true, resumePosition: Duration.zero);
      }
    } finally {
      _isHandlingCompletion = false;
    }
  }

  Future<void> _goToNextSurah() async {
    if (_isPlayerDisposed) return;
    final nextOrder = (_currentOrder >= 114) ? 114 : _currentOrder + 1;
    await _playSurah(nextOrder, autoPlay: true, resumePosition: Duration.zero);
  }

  Future<void> _goToPreviousSurah() async {
    if (_isPlayerDisposed) return;
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
      final downloaded = await DownloadService.isSurahDownloaded(_reciterKey!, _currentOrder);
    if (mounted) {
        setState(() => _isCurrentSurahDownloaded = downloaded);
      }
    } catch (e) {
      debugPrint('Error checking download status: $e');
    }
  }


  Future<void> _toggleBookmark() async {
    if (_isPlayerDisposed) return;
    final position = _player.position;
    if (_hasBookmark) {
      await PreferencesService.removeBookmark(_currentOrder);
      if (mounted) {
        setState(() => _bookmarkPosition = null);
      }
    } else {
      await PreferencesService.saveBookmark(_currentOrder, position.inSeconds);
      if (mounted) {
        setState(() => _bookmarkPosition = position);
      }
    }
  }

  Future<void> _jumpToBookmark() async {
    if (_isPlayerDisposed) return;
    if (_bookmarkPosition != null) {
      await _player.seek(_bookmarkPosition!);
    }
  }

  Future<void> _promptDownloadCurrentSurah() async {
    if (_reciterKey == null || _reciterKey!.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.downloadCurrentSurahTitle),
          content: Text(l10n.downloadCurrentSurahMessage),
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
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDownloadingCurrentSurah = true);
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.microtask(() async {
          try {
            await DownloadService.downloadSurah(_reciterKey!, _currentOrder);
            if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop(true);
            }
          } catch (e) {
            errorMessage = e.toString();
            if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop(false);
            }
          }
        });

        return AlertDialog(
          title: Text(l10n.downloadingSurah),
          content: const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );

    if (!mounted) return;

    setState(() {
      _isDownloadingCurrentSurah = false;
      if (result == true) {
        _isCurrentSurahDownloaded = true;
      }
    });

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.downloadComplete)),
      );
    } else if (result == false) {
      final message = (errorMessage != null && errorMessage!.isNotEmpty)
          ? '${l10n.downloadFailed}: $errorMessage'
          : l10n.downloadFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.playbackSpeed),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: '${_playbackSpeed.toStringAsFixed(1)}x',
                    onChanged: (value) {
                      setDialogState(() => _playbackSpeed = value);
                        _player.setSpeed(value);
                    },
                  ),
                  Text('${_playbackSpeed.toStringAsFixed(1)}x'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(context)!;
        int? tempSelected = _sleepTimerMinutes;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.sleepTimer),
              content: RadioGroup<int?>(
                groupValue: tempSelected,
                onChanged: (value) => setDialogState(() => tempSelected = value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<int?>(
                      title: Text(l10n.off),
                      value: null,
                    ),
                    RadioListTile<int?>(
                      title: Text('15 ${l10n.minutes}'),
                      value: 15,
                    ),
                    RadioListTile<int?>(
                      title: Text('30 ${l10n.minutes}'),
                      value: 30,
                    ),
                    RadioListTile<int?>(
                      title: Text('60 ${l10n.minutes}'),
                      value: 60,
                    ),
                    RadioListTile<int?>(
                      title: Text('90 ${l10n.minutes}'),
                      value: 90,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _setSleepTimer(null);
                    Navigator.pop(dialogContext);
                  },
                  child: Text(l10n.off),
                ),
                TextButton(
                  onPressed: () {
                    _setSleepTimer(tempSelected);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
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

  Future<void> _share(BuildContext context) async {
    if (_reciterKey == null || _reciterKey!.isEmpty) return;

    final langCode = PreferencesService.getLanguage();
    final reciterName = AudioService.reciterDisplayName(_reciterKey!, langCode);
    final surahName = _currentSurah?.name ?? 'Surah $_currentOrder';
    final url = AudioService.buildFullRecitationUrl(
      reciterKeyAr: _reciterKey!,
      surahOrder: _currentOrder,
    );


    if (url != null) {
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: '$surahName - $reciterName\n$url'));
    if (mounted) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.copiedToClipboard)),
        );
      }
    }
  }

  Future<void> _loadVerseUrls(int surahOrder) async {
    if (_reciterKey == null || _reciterKey!.isEmpty) return;
    final surah = _currentSurah;
    if (surah == null) return;
    
    _verseUrls = AudioService.buildVerseUrls(
      reciterKeyAr: _reciterKey!,
      surahOrder: surahOrder,
      totalVerses: surah.totalVerses,
    );
  }

  Future<void> _playVerse(int verseNumber) async {
    if (_isPlayerDisposed) return;
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorLoadingAudio)));
      }
      return;
    }

    // If not local file and no internet, show a clear message
    if (uri.scheme != 'file') {
      final hasNet = await _checkInternet();
      if (!hasNet) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.audioInternetRequired)));
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

  Widget _buildTransportControls({required bool isRtl, required ColorScheme color}) {
    final controls = <Widget>[
    IconButton(
      icon: Icon(isRtl ? Icons.skip_next_rounded : Icons.skip_previous_rounded),
        iconSize: 32,
        onPressed: _goToPreviousSurah,
      ),
      const SizedBox(width: 8),
    IconButton(
      icon: Icon(isRtl ? Icons.forward_10 : Icons.replay_10),
        iconSize: 28,
        onPressed: () => _seekRelative(const Duration(seconds: -10)),
      ),
      const SizedBox(width: 8),
      StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.95, end: playing ? 1.05 : 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: IconButton(
                  icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                  iconSize: 44,
                  color: color.primary,
                  onPressed: _togglePlayPause,
                ),
              );
            },
          );
        },
      ),
      const SizedBox(width: 8),
    IconButton(
      icon: Icon(isRtl ? Icons.replay_10 : Icons.forward_10),
        iconSize: 28,
        onPressed: () => _seekRelative(const Duration(seconds: 10)),
      ),
      const SizedBox(width: 8),
    IconButton(
      icon: Icon(isRtl ? Icons.skip_previous_rounded : Icons.skip_next_rounded),
        iconSize: 32,
        onPressed: _goToNextSurah,
      ),
    ];
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: controls,
  );
  }

  Widget _buildVerseControls(ColorScheme color, bool isRtl) {
    if (!_verseByVerseMode || _verseUrls == null || _currentSurah == null) {
      return const SizedBox.shrink();
    }

    final total = _currentSurah!.totalVerses;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
                  child: Container(
        padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
          color: color.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
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
                        onPressed: _currentVerse > 1 ? () => _playVerse(_currentVerse - 1) : null,
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
                        onPressed: _currentVerse < total ? () => _playVerse(_currentVerse + 1) : null,
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: _currentVerse > 1 ? () => _playVerse(_currentVerse - 1) : null,
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
                        onPressed: _currentVerse < total ? () => _playVerse(_currentVerse + 1) : null,
          ),
        ],
      ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme color, bool isRtl, String title, String reciterName) {
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
              child: _buildQueueSection(color),
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
              return _buildPlaylistTile(surah, color, isRtl);
            },
            childCount: _surahs.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildTopSection(ColorScheme color, bool isRtl, String title, String reciterName) {
    final l10n = AppLocalizations.of(context)!;
    final durationStream = StreamBuilder<Duration?>(
      stream: _player.durationStream,
      builder: (context, snapshot) {
        final duration = _currentTrackDuration ?? snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            final double maxPosition = duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0;
            final double sliderValue = duration.inMilliseconds > 0
                ? pos.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
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
                      _fmt(pos),
                      style: TextStyle(color: color.onSurface.withAlpha((255 * 0.7).round())),
                    ),
                    Text(
                      _fmt(duration),
                      style: TextStyle(color: color.onSurface.withAlpha((255 * 0.7).round())),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    return Column(
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
        _buildTransportControls(isRtl: isRtl, color: color),
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
                  }
                });
              },
            ),
            FilterChip(
              label: Text(l10n.autoPlayNext),
              selected: _autoPlayNext,
              onSelected: (value) {
                setState(() {
                  _autoPlayNext = value;
                  if (value) {
                    _isRepeat = false;
                    _verseByVerseMode = false;
                  }
                });
                PreferencesService.saveAutoPlayNextSurah(value);
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
        if (_hasBookmark && _bookmarkPosition != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: _jumpToBookmark,
              icon: const Icon(Icons.bookmark),
              label: Text('${l10n.bookmarked} - ${_fmt(_bookmarkPosition!)}'),
            ),
          ),
      ],
    );
  }

  Widget _buildQueueSection(ColorScheme color) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.queue,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _queue.isEmpty
                    ? null
                    : () {
                        _queueService.clearQueue();
                      },
                icon: const Icon(Icons.clear_all, size: 18),
                label: Text(l10n.clearQueue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _queue.map((order) {
              final surah = _findSurah(order);
              final isCurrent = order == _currentOrder;
              final label = surah != null
                  ? '${surah.order}. ${surah.name}'
                  : '${AppLocalizations.of(context)!.surah} $order';
              return InputChip(
                label: Text(label),
                selected: isCurrent,
                onPressed: () => _playSurah(order,
                    autoPlay: true, resumePosition: Duration.zero),
                onDeleted: () => _queueService.removeFromQueue(order),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistTile(Surah surah, ColorScheme color, bool isRtl) {
    final l10n = AppLocalizations.of(context)!;
    final isCurrent = surah.order == _currentOrder;
    final isFeatured = _featuredListenSurahs.contains(surah.order);
    final inQueue = _queue.contains(surah.order);
    final backgroundColor = isCurrent
        ? color.primaryContainer.withAlpha((255 * 0.5).round())
        : color.surface;
    final textAlign = isRtl ? TextAlign.right : TextAlign.left;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          onTap: () =>
              _playSurah(surah.order, autoPlay: true, resumePosition: Duration.zero),
          title: Text(
            '${surah.order}. ${surah.name}',
            textAlign: textAlign,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: color.onSurface,
            ),
          ),
          subtitle: Text(
            '${surah.totalVerses} ${l10n.verses}',
            textAlign: textAlign,
            style: TextStyle(color: color.onSurface.withAlpha((255 * 0.6).round())),
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                icon: Icon(
                  inQueue ? Icons.playlist_remove : Icons.playlist_add,
                ),
                tooltip: inQueue ? l10n.clearQueue : l10n.addToQueue,
                onPressed: () => _toggleQueueEntry(surah.order),
              ),
              IconButton(
                icon: Icon(
                  isFeatured ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade600,
                ),
                tooltip:
                    isFeatured ? l10n.removeFeatureSurah : l10n.featureSurah,
                onPressed: () => _toggleFeature(surah.order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retry() {
    unawaited(_playSurah(_currentOrder, autoPlay: _player.playing));
  }

  String _fmt(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours > 0 ? '${duration.inHours.toString().padLeft(2, '0')}:' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final surahTitle = _currentSurah?.name ?? 'Surah $_currentOrder';
    final langCode = Localizations.localeOf(context).languageCode;
    final reciterName = _reciterKey != null && _reciterKey!.isNotEmpty
        ? AudioService.reciterDisplayName(_reciterKey!, langCode)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('', style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
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
                    icon: const Icon(Icons.download),
                    tooltip: l10n.download,
                    onPressed: _promptDownloadCurrentSurah,
                  ),
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: l10n.playbackSpeed,
            onPressed: () => _showSpeedDialog(context),
          ),
                                IconButton(
            icon: Icon(_sleepTimerMinutes != null ? Icons.timer : Icons.timer_outlined),
            tooltip: l10n.sleepTimer,
            onPressed: () => _showSleepTimerDialog(context),
          ),
                                IconButton(
            icon: Icon(_hasBookmark ? Icons.bookmark : Icons.bookmark_border),
            tooltip: _hasBookmark ? l10n.bookmarked : l10n.bookmark,
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.share,
            onPressed: () => _share(context),
          ),
        ],
      ),
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


