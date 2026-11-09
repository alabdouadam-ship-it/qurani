import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'l10n/app_localizations.dart';
import 'services/backup_service.dart';
import 'services/restore_runtime.dart';
import 'providers/app_state_providers.dart';
import 'providers/reader_prefs_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final data = await BackupService.instance.capture();
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data.toJson())));
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox;
      await SharePlus.instance.share(ShareParams(files: [
        XFile.fromData(bytes, mimeType: 'application/json')
      ], fileNameOverrides: [
        'qurani-backup-${DateTime.now().millisecondsSinceEpoch}.json'
      ], sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size));
    } catch (_) {
      _message(l10n.backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    bool validated = false;
    try {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            mimeTypes: ['application/json'],
            uniformTypeIdentifiers: ['public.json'])
      ]);
      if (file == null) return;
      if (await file.length() > BackupService.maxBytes) {
        throw const FormatException('Too large');
      }
      final backup = BackupService.parse(await file.readAsString());
      validated = true;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: Text(l10n.backupRestore),
                  content: Text(l10n.backupConfirm(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(backup.createdAt.toLocal()),
                      backup.records)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(l10n.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(l10n.backupRestore))
                  ]));
      if (confirmed != true) return;
      await BackupService.instance.restore(backup);
      var schedulesOk = true;
      try {
        await refreshRuntimeAfterRestore();
      } catch (_) {
        schedulesOk = false;
      }
      if (!mounted) return;
      ref.invalidate(localeProvider);
      ref.invalidate(themeProvider);
      ref.invalidate(disabledScreensProvider);
      ref.invalidate(arabicFontProvider);
      _message(schedulesOk ? l10n.backupDone : l10n.backupScheduleWarning);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      _message(validated ? l10n.backupFailed : l10n.backupInvalid);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
            appBar: AppBar(title: Text(l10n.backupTitle)),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              Text(l10n.backupDescription),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.upload_file),
                  label: Text(l10n.backupExport)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.backupImport)),
              if (_busy)
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator())),
            ])));
  }
}
