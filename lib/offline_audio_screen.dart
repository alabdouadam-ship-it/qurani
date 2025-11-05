import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/offline_audio_service.dart';
import 'package:qurani/services/preferences_service.dart';

class OfflineAudioScreen extends StatefulWidget {
  const OfflineAudioScreen({super.key});

  @override
  State<OfflineAudioScreen> createState() => _OfflineAudioScreenState();
}

class _OfflineAudioScreenState extends State<OfflineAudioScreen> {
  String _reciter = PreferencesService.getReciter();
  int _downloadedAyahs = 0;
  int _downloadedFull = 0;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  bool _downloading = false;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final ayahCount = await OfflineAudioService.countDownloadedAyahs(_reciter);
    final fullCount = await OfflineAudioService.countDownloadedFullSurahs(_reciter);
    if (mounted) {
      setState(() {
        _downloadedAyahs = ayahCount;
        _downloadedFull = fullCount;
      });
    }
  }

  Future<void> _startDownload() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progressCurrent = 0;
      _progressTotal = 0;
    });
    _cancelToken = CancelToken();
    try {
      await OfflineAudioService.downloadAllAyahAudios(
        reciterKey: _reciter,
        onProgress: (c, t) {
          if (!mounted) return;
          setState(() {
            _progressCurrent = c;
            _progressTotal = t;
          });
        },
        cancelToken: _cancelToken,
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
        await _refreshCounts();
      }
    }
  }

  Future<void> _deleteAyahs() async {
    if (_downloading) return;
    await OfflineAudioService.deleteDownloadedAyahs(_reciter);
    await _refreshCounts();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lang = PreferencesService.getLanguage();
    final reciterName = AudioService.reciterDisplayName(_reciter, lang);
    final percent = (_progressTotal > 0) ? (_progressCurrent / _progressTotal) : 0.0;
    return Scaffold(
      appBar: AppBar(title: Text('Offline audio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reciter: $reciterName', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Verse audios downloaded: $_downloadedAyahs (total ~6236)'),
            const SizedBox(height: 4),
            Text('Full surahs downloaded: $_downloadedFull / 114'),
            const SizedBox(height: 12),
            Text('Why download? You can listen without internet.'),
            const SizedBox(height: 16),
            if (_downloading) ...[
              LinearProgressIndicator(value: percent.clamp(0.0, 1.0)),
              const SizedBox(height: 8),
              Text('Downloading $_progressCurrent / $_progressTotal'),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      _cancelToken?.cancel();
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Download verse audios'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _deleteAyahs,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete verse audios'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Note: Full surah audio can be downloaded from Listen to Quran screen.'),
            ],
          ],
        ),
      ),
    );
  }
}


