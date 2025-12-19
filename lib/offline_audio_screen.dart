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
  final String _reciter = PreferencesService.getReciter();
  int _downloadedAyahs = 0;
  int _downloadedFull = 0;
  int _downloadedAE = 0; // arabic-english
  int _downloadedAF = 0; // arabic-french
  int _downloadedTafsir = 0; // muyassar
  int _progressCurrentAyah = 0;
  int _progressTotalAyah = 0;
  int _progressCurrentFull = 0;
  int _progressTotalFull = 0;
  int _progressCurrentAE = 0;
  int _progressTotalAE = 0;
  int _progressCurrentAF = 0;
  int _progressTotalAF = 0;
  int _progressCurrentTafsir = 0;
  int _progressTotalTafsir = 0;
  bool _downloadingAyah = false;
  bool _downloadingFull = false;
  bool _downloadingAE = false;
  bool _downloadingAF = false;
  bool _downloadingTafsir = false;
  CancelToken? _cancelTokenAyah;
  CancelToken? _cancelTokenFull;
  CancelToken? _cancelTokenAE;
  CancelToken? _cancelTokenAF;
  CancelToken? _cancelTokenTafsir;

  static const int _totalAyahs = 6236;
  static const int _totalFull = 114;

  bool get _allFullDownloaded => _downloadedFull >= _totalFull;
  bool get _anyFullDownloaded => _downloadedFull > 0;
  bool get _allAyahDownloaded => _downloadedAyahs >= _totalAyahs;
  bool get _anyAyahDownloaded => _downloadedAyahs > 0;
  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final ayahCount = await OfflineAudioService.countDownloadedAyahs(_reciter);
    final fullCount = await OfflineAudioService.countDownloadedFullSurahs(_reciter);
    final aeCount = await OfflineAudioService.countDownloadedAyahs('arabic-english');
    final afCount = await OfflineAudioService.countDownloadedAyahs('arabic-french');
    final tafsirCount = await OfflineAudioService.countDownloadedAyahs('muyassar');
    if (mounted) {
      setState(() {
        _downloadedAyahs = ayahCount;
        _downloadedFull = fullCount;
        _downloadedAE = aeCount;
        _downloadedAF = afCount;
        _downloadedTafsir = tafsirCount;
      });
    }
  }

  Future<void> _startDownloadAyahs() async {
    if (_downloadingAyah) return;
    setState(() {
      _downloadingAyah = true;
      _progressCurrentAyah = 0;
      _progressTotalAyah = 0;
    });
    _cancelTokenAyah = CancelToken();
    try {
      await OfflineAudioService.downloadAllAyahAudios(
        reciterKey: _reciter,
        onProgress: (c, t) {
          if (!mounted) return;
          setState(() {
            _progressCurrentAyah = c;
            _progressTotalAyah = t;
          });
        },
        cancelToken: _cancelTokenAyah,
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingAyah = false;
        });
        await _refreshCounts();
      }
    }
  }

  Future<void> _startDownloadFull() async {
    if (_downloadingFull) return;
    setState(() {
      _downloadingFull = true;
      _progressCurrentFull = 0;
      _progressTotalFull = 0;
    });
    _cancelTokenFull = CancelToken();
    try {
      await OfflineAudioService.downloadAllFullSurahs(
        reciterKey: _reciter,
        onProgress: (c, t) {
          if (!mounted) return;
          setState(() {
            _progressCurrentFull = c;
            _progressTotalFull = t;
          });
        },
        cancelToken: _cancelTokenFull,
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingFull = false;
        });
        await _refreshCounts();
      }
    }
  }

  Future<void> _deleteAyahs() async {
    if (_downloadingAyah) return;
    await OfflineAudioService.deleteDownloadedAyahs(_reciter);
    await _refreshCounts();
  }

  Future<void> _deleteFull() async {
    if (_downloadingFull) return;
    await OfflineAudioService.deleteDownloadedFullSurahs(_reciter);
    await _refreshCounts();
  }

  Future<void> _startDownloadAE() async {
    if (_downloadingAE) return;
    setState(() {
      _downloadingAE = true;
      _progressCurrentAE = 0;
      _progressTotalAE = 0;
    });
    _cancelTokenAE = CancelToken();
    try {
      await OfflineAudioService.downloadAllAyahAudios(
        reciterKey: 'arabic-english',
        onProgress: (c, t) {
          if (!mounted) return;
          setState(() { _progressCurrentAE = c; _progressTotalAE = t; });
        },
        cancelToken: _cancelTokenAE,
      );
    } finally {
      if (mounted) {
        setState(() { _downloadingAE = false; });
        await _refreshCounts();
      }
    }
  }

  Future<void> _startDownloadAF() async {
    if (_downloadingAF) return;
    setState(() {
      _downloadingAF = true;
      _progressCurrentAF = 0;
      _progressTotalAF = 0;
    });
    _cancelTokenAF = CancelToken();
    try {
      await OfflineAudioService.downloadAllAyahAudios(
        reciterKey: 'arabic-french',
        onProgress: (c, t) {
          if (!mounted) return;
          setState(() { _progressCurrentAF = c; _progressTotalAF = t; });
        },
        cancelToken: _cancelTokenAF,
      );
    } finally {
      if (mounted) {
        setState(() { _downloadingAF = false; });
        await _refreshCounts();
      }
    }
  }

  Future<void> _startDownloadTafsir() async {
    if (_downloadingTafsir) return;
    setState(() {
      _downloadingTafsir = true;
      _progressCurrentTafsir = 0;
      _progressTotalTafsir = 0;
    });
    _cancelTokenTafsir = CancelToken();
    try {
      await OfflineAudioService.downloadAllAyahAudios(
        reciterKey: 'muyassar',
        onProgress: (c, t) {
          if (!mounted) return;
          setState(() { _progressCurrentTafsir = c; _progressTotalTafsir = t; });
        },
        cancelToken: _cancelTokenTafsir,
      );
    } finally {
      if (mounted) {
        setState(() { _downloadingTafsir = false; });
        await _refreshCounts();
      }
    }
  }

  Future<void> _deleteAE() async { if (_downloadingAE) return; await OfflineAudioService.deleteDownloadedAyahs('arabic-english'); await _refreshCounts(); }
  Future<void> _deleteAF() async { if (_downloadingAF) return; await OfflineAudioService.deleteDownloadedAyahs('arabic-french'); await _refreshCounts(); }
  Future<void> _deleteTafsir() async { if (_downloadingTafsir) return; await OfflineAudioService.deleteDownloadedAyahs('muyassar'); await _refreshCounts(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lang = PreferencesService.getLanguage();
    final reciterName = AudioService.reciterDisplayName(_reciter, lang);
    final percentAyah = (_progressTotalAyah > 0) ? (_progressCurrentAyah / _progressTotalAyah) : 0.0;
    final percentFull = (_progressTotalFull > 0) ? (_progressCurrentFull / _progressTotalFull) : 0.0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.offlineAudioTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full surah card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.album, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(l10n.fullSurahLabel, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.reciterLabel(reciterName), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text('$_downloadedFull / $_totalFull', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    if (_downloadingFull) ...[
                      LinearProgressIndicator(value: percentFull.clamp(0.0, 1.0)),
                      const SizedBox(height: 8),
                      Text(l10n.downloadingProgress(_progressCurrentFull, _progressTotalFull)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(
                          onPressed: () { _cancelTokenFull?.cancel(); },
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(l10n.cancel),
                        ),
                      ]),
                    ] else ...[
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (!_allFullDownloaded)
                          ElevatedButton.icon(
                            onPressed: _startDownloadFull,
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: Text(l10n.downloadFullSurahs),
                          ),
                        if (_anyFullDownloaded)
                          OutlinedButton.icon(
                            onPressed: _deleteFull,
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l10n.deleteFullSurahs),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Verse-by-verse card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.queue_music, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(l10n.verseByVerse, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.reciterLabel(reciterName), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text('$_downloadedAyahs / $_totalAyahs', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    if (_downloadingAyah) ...[
                      LinearProgressIndicator(value: percentAyah.clamp(0.0, 1.0)),
                      const SizedBox(height: 8),
                      Text(l10n.downloadingProgress(_progressCurrentAyah, _progressTotalAyah)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(
                          onPressed: () { _cancelTokenAyah?.cancel(); },
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(l10n.cancel),
                        ),
                      ]),
                    ] else ...[
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (!_allAyahDownloaded)
                          ElevatedButton.icon(
                            onPressed: _startDownloadAyahs,
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: Text(l10n.downloadVerseAudios),
                          ),
                        if (_anyAyahDownloaded)
                          OutlinedButton.icon(
                            onPressed: _deleteAyahs,
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l10n.deleteVerseAudios),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Additional verse-by-verse sets (Arabic-English, Arabic-French, Tafsir)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.library_music, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(l10n.verseByVerse, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Arabic-English
                    _downloadingAE
                        ? Column(children: [
                            LinearProgressIndicator(value: (_progressTotalAE > 0 ? (_progressCurrentAE / _progressTotalAE) : 0.0).clamp(0.0, 1.0)),
                            const SizedBox(height: 8),
                            Text(l10n.downloadingProgress(_progressCurrentAE, _progressTotalAE)),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: OutlinedButton.icon(onPressed: () { _cancelTokenAE?.cancel(); }, icon: const Icon(Icons.stop_circle_outlined), label: Text(l10n.cancel)),
                            ),
                          ])
                        : _buildExtraSetRow(
                            context: context,
                            label: AudioService.reciterDisplayName('arabic-english', lang),
                            count: _downloadedAE,
                            total: _totalAyahs,
                            onDownload: _startDownloadAE,
                            onDelete: _deleteAE,
                          ),
                    const Divider(height: 24),
                    // Arabic-French
                    _downloadingAF
                        ? Column(children: [
                            LinearProgressIndicator(value: (_progressTotalAF > 0 ? (_progressCurrentAF / _progressTotalAF) : 0.0).clamp(0.0, 1.0)),
                            const SizedBox(height: 8),
                            Text(l10n.downloadingProgress(_progressCurrentAF, _progressTotalAF)),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: OutlinedButton.icon(onPressed: () { _cancelTokenAF?.cancel(); }, icon: const Icon(Icons.stop_circle_outlined), label: Text(l10n.cancel)),
                            ),
                          ])
                        : _buildExtraSetRow(
                            context: context,
                            label: AudioService.reciterDisplayName('arabic-french', lang),
                            count: _downloadedAF,
                            total: _totalAyahs,
                            onDownload: _startDownloadAF,
                            onDelete: _deleteAF,
                          ),
                    const Divider(height: 24),
                    // Tafsir (Muyassar)
                    _downloadingTafsir
                        ? Column(children: [
                            LinearProgressIndicator(value: (_progressTotalTafsir > 0 ? (_progressCurrentTafsir / _progressTotalTafsir) : 0.0).clamp(0.0, 1.0)),
                            const SizedBox(height: 8),
                            Text(l10n.downloadingProgress(_progressCurrentTafsir, _progressTotalTafsir)),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: OutlinedButton.icon(onPressed: () { _cancelTokenTafsir?.cancel(); }, icon: const Icon(Icons.stop_circle_outlined), label: Text(l10n.cancel)),
                            ),
                          ])
                        : _buildExtraSetRow(
                            context: context,
                            label: AudioService.reciterDisplayName('muyassar', lang),
                            count: _downloadedTafsir,
                            total: _totalAyahs,
                            onDownload: _startDownloadTafsir,
                            onDelete: _deleteTafsir,
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Full surah info
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.downloadFullSurahNote)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraSetRow({
    required BuildContext context,
    required String label,
    required int count,
    required int total,
    required VoidCallback onDownload,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(avatar: const Icon(Icons.queue_music, size: 18), label: Text('$count / $total')),
                if (count < total)
                  ElevatedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: Text(AppLocalizations.of(context)!.downloadVerseAudios),
                  ),
                if (count > 0)
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(AppLocalizations.of(context)!.deleteVerseAudios),
                  ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}


