import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// Used for haptic feedback on Pause / Resume / Repair actions.
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/download_service.dart';
import 'package:qurani/services/offline_audio_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/widgets/modern_ui.dart';

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

  // Pause / integrity state for the bulk full-surah download (PR 2).
  // `_isFullPaused` mirrors the persisted `bulk_paused_full_<reciter>` flag
  // so the UI can render "Resume" instead of "Download full surahs" after
  // the user reopens the screen.
  bool _isFullPaused = false;
  bool _isRepairing = false;
  // Counts from `DownloadService.verifyAllSurahs`. Recomputed on every
  // `_refreshCounts` so the UI badge always reflects on-disk reality.
  int _verifiedFull = 0;
  int _corruptFull = 0;
  int _missingFull = 0;

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

  @override
  void dispose() {
    // Cancel any in-flight bulk downloads when the screen leaves the tree.
    // Before this, a user tapping Back mid-download left 5 potential HTTP
    // streams running silently on Wi-Fi/mobile — wasting bandwidth, battery,
    // and (on iOS) occasionally keeping the process alive longer than needed.
    // CancelToken.cancel() is idempotent, so calling it on tokens that were
    // never created or already completed is a safe no-op.
    _cancelTokenAyah?.cancel();
    _cancelTokenFull?.cancel();
    _cancelTokenAE?.cancel();
    _cancelTokenAF?.cancel();
    _cancelTokenTafsir?.cancel();
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    final ayahCount = await OfflineAudioService.countDownloadedAyahs(_reciter);
    final fullCount = await OfflineAudioService.countDownloadedFullSurahs(_reciter);
    final aeCount = await OfflineAudioService.countDownloadedAyahs('arabic-english');
    final afCount = await OfflineAudioService.countDownloadedAyahs('arabic-french');
    final tafsirCount = await OfflineAudioService.countDownloadedAyahs('muyassar');
    // Integrity sweep (cached — only re-sniffs files whose size/mtime changed).
    final integrity = await DownloadService.verifyAllSurahs(_reciter);
    final paused = PreferencesService.isBulkFullPaused(_reciter);
    if (mounted) {
      setState(() {
        _downloadedAyahs = ayahCount;
        _downloadedFull = fullCount;
        _downloadedAE = aeCount;
        _downloadedAF = afCount;
        _downloadedTafsir = tafsirCount;
        _verifiedFull = integrity.present;
        _corruptFull = integrity.corrupt;
        _missingFull = integrity.missing;
        _isFullPaused = paused;
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
    // A fresh download (or resume) implicitly clears the persisted pause flag
    // — the user explicitly opted in by tapping the button.
    if (_isFullPaused) {
      await PreferencesService.setBulkFullPaused(_reciter, false);
    }
    setState(() {
      _downloadingFull = true;
      _isFullPaused = false;
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

  /// Pauses an in-flight bulk full-surah download. Cancels the active token
  /// (so per-surah work returns at the next granularity boundary) and
  /// persists the paused state so the user's intent survives an app kill.
  Future<void> _pauseFull() async {
    if (!_downloadingFull) return;
    HapticFeedback.lightImpact();
    _cancelTokenFull?.cancel();
    await PreferencesService.setBulkFullPaused(_reciter, true);
    if (mounted) {
      setState(() => _isFullPaused = true);
    }
  }

  /// Resumes a paused bulk download by clearing the persisted flag and
  /// re-running the bulk worker. Already-downloaded files are skipped
  /// instantly by `DownloadService.downloadSurah`'s existence check, and
  /// any in-flight `.part` files resume from the last byte offset.
  Future<void> _resumeFull() async {
    HapticFeedback.lightImpact();
    await PreferencesService.setBulkFullPaused(_reciter, false);
    if (mounted) {
      setState(() => _isFullPaused = false);
    }
    await _startDownloadFull();
  }

  /// Deletes corrupt files (failed magic-byte sniff) and refreshes counts.
  /// The user is then prompted via SnackBar to resume the download so the
  /// repaired holes get re-fetched on the next bulk run.
  Future<void> _repairFull() async {
    if (_isRepairing || _downloadingFull) return;
    HapticFeedback.mediumImpact();
    setState(() => _isRepairing = true);
    try {
      final removed = await DownloadService.repairCorruptSurahs(_reciter);
      await _refreshCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.repairCompleted(removed),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRepairing = false);
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
    final lang = Localizations.localeOf(context).languageCode;
    final reciterName = AudioService.reciterDisplayName(_reciter, lang);
    final percentAyah = (_progressTotalAyah > 0) ? (_progressCurrentAyah / _progressTotalAyah) : 0.0;
    final percentFull = (_progressTotalFull > 0) ? (_progressCurrentFull / _progressTotalFull) : 0.0;
    return ModernPageScaffold(
      title: l10n.offlineAudioTitle,
      icon: Icons.cloud_download_outlined,
      subtitle: l10n.localeName == 'ar'
          ? 'إدارة تنزيلات التلاوة كاملة أو آية بآية مع متابعة أوضح للتقدم.'
          : l10n.localeName == 'fr'
              ? 'Gérez les téléchargements audio avec un suivi plus clair de la progression.'
              : 'Manage audio downloads with clearer progress and calmer presentation.',
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernSurfaceCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.library_music_rounded,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reciterLabel(reciterName),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.downloadFullSurahNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(170),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ModernSurfaceCard(
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
                          onPressed: _pauseFull,
                          icon: const Icon(Icons.pause_circle_outline),
                          label: Text(l10n.pause),
                        ),
                      ]),
                    ] else ...[
                      // Integrity badge — only meaningful once at least one
                      // surah is on disk; otherwise we'd be telling the user
                      // "0 of 114 verified" right next to the download CTA.
                      if (_anyFullDownloaded) _buildFullIntegrityBadge(theme, l10n),
                      if (_anyFullDownloaded) const SizedBox(height: 12),
                      if (_isFullPaused)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Icon(Icons.pause_circle_filled,
                                color: theme.colorScheme.tertiary, size: 18),
                            const SizedBox(width: 6),
                            Text(l10n.downloadPaused,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.tertiary,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (_isFullPaused)
                          ElevatedButton.icon(
                            onPressed: _resumeFull,
                            icon: const Icon(Icons.play_circle_outline),
                            label: Text(l10n.resume),
                          )
                        else if (!_allFullDownloaded)
                          ElevatedButton.icon(
                            onPressed: _startDownloadFull,
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: Text(l10n.downloadFullSurahs),
                          ),
                        if (_corruptFull > 0)
                          OutlinedButton.icon(
                            onPressed: _isRepairing ? null : _repairFull,
                            icon: _isRepairing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.healing_outlined),
                            label: Text(_isRepairing
                                ? l10n.repairing
                                : l10n.repairCorruptFiles),
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
            const SizedBox(height: 12),
            ModernSurfaceCard(
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
            const SizedBox(height: 12),
            ModernSurfaceCard(
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
            const SizedBox(height: 12),
            ModernSurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.downloadFullSurahNote)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the integrity badge row for the full-surah card. Three chips,
  /// each colour-coded by severity: green for verified, red for corrupt,
  /// neutral for missing. When everything is good we collapse to a single
  /// celebratory "All 114 verified" line so the card stays calm.
  Widget _buildFullIntegrityBadge(ThemeData theme, AppLocalizations l10n) {
    final allGood = _verifiedFull == _totalFull;
    if (allGood) {
      return Row(
        children: [
          Icon(Icons.verified_outlined,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.integrityAllVerified(_totalFull),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    final chips = <Widget>[
      _integrityChip(
        theme: theme,
        icon: Icons.verified_outlined,
        label: l10n.integrityVerified(_verifiedFull, _totalFull),
        fg: theme.colorScheme.primary,
      ),
      if (_corruptFull > 0)
        _integrityChip(
          theme: theme,
          icon: Icons.error_outline,
          label: l10n.integrityCorrupt(_corruptFull),
          fg: theme.colorScheme.error,
        ),
      if (_missingFull > 0)
        _integrityChip(
          theme: theme,
          icon: Icons.cloud_off_outlined,
          label: l10n.integrityMissing(_missingFull),
          fg: theme.colorScheme.onSurface.withAlpha(170),
        ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _integrityChip({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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


