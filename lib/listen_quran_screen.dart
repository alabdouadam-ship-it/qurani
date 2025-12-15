import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'responsive_config.dart';
import 'widgets/surah_grid.dart';
import 'models/surah.dart';
import 'services/preferences_service.dart';
import 'services/audio_service.dart';
import 'services/download_service.dart';
import 'audio_player_screen.dart';
import 'util/settings_sheet_utils.dart'; // Import utility

class ListenQuranScreen extends StatefulWidget {
  const ListenQuranScreen({super.key});

  @override
  State<ListenQuranScreen> createState() => _ListenQuranScreenState();
}

class _ListenQuranScreenState extends State<ListenQuranScreen> {
  Future<bool>? _showDownloadButtonFuture;
  String? _lastReciterKey;

  @override
  void initState() {
    super.initState();
    _lastReciterKey = PreferencesService.getReciter();
    _showDownloadButtonFuture = _shouldShowDownloadButton();
  }

  Future<bool> _shouldShowDownloadButton() async {
    final reciterKey = PreferencesService.getReciter();
    if (reciterKey.isEmpty) {
      return true;
    }

    if (!PreferencesService.isDownloadedFull()) {
      return true;
    }

    final downloadedReciter = PreferencesService.getDownloadedReciter();
    if (downloadedReciter != reciterKey) {
      return true;
    }

    for (var order = 1; order <= 114; order++) {
      final exists = await DownloadService.isSurahDownloaded(reciterKey, order);
      if (!exists) {
        return true;
      }
    }

    return false;
  }

  void _refreshDownloadButtonState() {
    if (!mounted) return;
    final currentReciter = PreferencesService.getReciter();
    setState(() {
      _lastReciterKey = currentReciter;
      _showDownloadButtonFuture = _shouldShowDownloadButton();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentReciter = PreferencesService.getReciter();
    if (currentReciter != _lastReciterKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshDownloadButtonState();
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.listenQuran,
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
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () {
              SettingsSheetUtils.showReciterSelectionSheet(
                context,
                onReciterSelected: (reciterKey) {
                  PreferencesService.saveReciter(reciterKey);
                  setState(() {
                    _lastReciterKey = reciterKey;
                  });
                },
              );
            },
          ),
          if (!kIsWeb) _buildDownloadAction(l10n),
        ],
      ),
      body: SurahGrid(
        onTapSurah: (Surah s) {
          final reciterKey = PreferencesService.getReciter();
          if (reciterKey.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.selectReciterFirst)),
            );
            return;
          }
          final url = AudioService.buildFullRecitationUrl(
            reciterKeyAr: reciterKey,
            surahOrder: s.order,
          );
          if (url == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.surahUnavailable)),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioPlayerScreen(initialSurahOrder: s.order),
            ),
          );
        },
        allowHighlight: true,
      ),
    );
  }

  Widget _buildDownloadAction(AppLocalizations l10n) {
    return FutureBuilder<bool>(
      future: _showDownloadButtonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final shouldShow = snapshot.data ?? false;
        if (!shouldShow) {
          return const SizedBox.shrink();
        }
        return IconButton(
          icon: const Icon(Icons.download),
          tooltip: l10n.download,
          onPressed: () => _handleDownloadPressed(l10n),
        );
      },
    );
  }

  Future<void> _handleDownloadPressed(AppLocalizations l10n) async {
    final reciterKey = PreferencesService.getReciter();
    if (reciterKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectReciterFirst)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.downloadReciterTitle),
          content: Text(l10n.downloadReciterMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.download),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    double progress = 0.0;
    bool started = false;
    StateSetter? dialogSetState;
    String? errorMessage;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            dialogSetState = setState;
            if (!started) {
              started = true;
              Future.microtask(() async {
                try {
                  await DownloadService.downloadFullReciter(
                    reciterKey,
                    onProgress: (value) {
                      dialogSetState?.call(() {
                        progress = value;
                      });
                    },
                  );
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (e) {
                  errorMessage = e.toString();
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop(false);
                  }
                }
              });
            }
            final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
            final label = progress == 0 ? '...' : '$percent%';
            const totalSurahs = 114;
            int completedSurahs = 0;
            if (progress > 0) {
              completedSurahs = (progress * totalSurahs).ceil();
              if (completedSurahs > totalSurahs) {
                completedSurahs = totalSurahs;
              }
            }
            return AlertDialog(
              title: Text(l10n.downloadProgressTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress == 0 ? null : progress),
                  const SizedBox(height: 8),
                  Text('$completedSurahs/$totalSurahs'),
                  const SizedBox(height: 12),
                  Text(label),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.downloadComplete)),
      );
      _refreshDownloadButtonState();
    } else if (success == false) {
      final message = errorMessage?.isNotEmpty == true
          ? '${l10n.downloadFailed}: $errorMessage'
          : l10n.downloadFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

