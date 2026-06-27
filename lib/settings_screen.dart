import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'local_webview_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'responsive_config.dart';
import 'preferences_screen.dart';


import 'offline_audio_screen.dart';
import 'screen_customization_screen.dart';
import 'widgets/modern_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    final isTablet = ResponsiveConfig.isTablet(context);
    final l10n = AppLocalizations.of(context)!;

    return ModernPageScaffold(
      title: l10n.settings,
      icon: Icons.settings_outlined,
      subtitle: l10n.localeName == 'ar'
          ? 'تحكم في التفضيلات والمحتوى والتنزيلات وروابط المساعدة في واجهة أكثر هدوءًا ووضوحًا.'
          : l10n.localeName == 'fr'
              ? 'Gérez les préférences, les téléchargements et l’aide dans une interface plus apaisée et claire.'
              : 'Manage preferences, downloads, and help links in a calmer, clearer interface.',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final settings = _getSettings(context);
          int crossAxisCount;
          if (isSmallScreen) {
            crossAxisCount = 2;
          } else if (isTablet) {
            crossAxisCount = 3;
          } else {
            final width = constraints.maxWidth;
            const targetTileWidth = 180.0;
            final cols = width ~/ targetTileWidth;
            crossAxisCount = cols.clamp(3, 8);
          }

          final rows = (settings.length / crossAxisCount).ceil();
          final availableHeight = constraints.maxHeight - 24;
          final totalSpacingHeight = (rows - 1) * (isSmallScreen ? 12 : 16);
          final minItemHeight = isSmallScreen ? 120.0 : 140.0;
          final calculatedItemHeight = (availableHeight - totalSpacingHeight) / rows;
          final itemHeight = calculatedItemHeight < minItemHeight ? minItemHeight : calculatedItemHeight;
          final totalSpacingWidth = (crossAxisCount - 1) * (isSmallScreen ? 12 : 16);
          final itemWidth = (constraints.maxWidth - totalSpacingWidth) / crossAxisCount;
          final aspectRatio = itemWidth / itemHeight;

          return GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isSmallScreen ? 12 : 16,
            mainAxisSpacing: isSmallScreen ? 12 : 16,
            childAspectRatio: aspectRatio,
            padding: const EdgeInsets.only(bottom: 24),
            physics: const BouncingScrollPhysics(),
            children: settings.map((s) => _buildSettingCard(context, s)).toList(),
          );
        },
      ),
    );
  }

  List<SettingItem> _getSettings(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      SettingItem(
        id: 'preferences',
        icon: Icons.tune,
        title: l10n.preferences,
        subtitle: "",
        color: Colors.green,
      ),
      SettingItem(
        id: 'customize_screens',
        icon: Icons.dashboard_customize_outlined,
        title: l10n.localeName == 'ar' ? 'تخصيص الشاشات' : (l10n.localeName == 'fr' ? 'Personnaliser les écrans' : 'Customize Screens'),
        subtitle: "",
        color: Colors.blueAccent,
      ),
      SettingItem(
        id: 'share',
        icon: Icons.share,
        title: l10n.shareApp,
        subtitle: "",
        color: Colors.teal,
      ),
      if (!kIsWeb)
        SettingItem(
          id: 'offline_audio',
          icon: Icons.cloud_download_outlined,
          title: l10n.offlineAudioTitle,
          subtitle: '',
          color: Colors.orange,
        ),
      SettingItem(
        id: 'about',
        icon: Icons.info_outline,
        title: l10n.about,
        subtitle: '',
        color: Colors.blue,
      ),
      SettingItem(
        id: 'help',
        icon: Icons.help_outline,
        title: l10n.help,
        subtitle: '',
        color: Colors.purple,
      ),
      SettingItem(
        id: 'privacy',
        icon: Icons.privacy_tip_outlined,
        title: l10n.privacyPolicy,
        subtitle: '',
        color: Colors.indigo,
      ),
      SettingItem(
        id: 'terms',
        icon: Icons.article_outlined,
        title: l10n.termsConditions,
        subtitle: '',
        color: Colors.brown,
      ),
    ];
  }

  Widget _buildSettingCard(BuildContext context, SettingItem setting) {
    return ModernFeatureTile(
      icon: setting.icon,
      title: setting.title,
      subtitle: setting.subtitle,
      color: setting.color,
      onTap: () => _handleSettingTap(context, setting),
    );
  }

  void _handleSettingTap(BuildContext context, SettingItem setting) {
    // Legal/help docs are served from the same Firebase Hosting site as the web
    // app, at the site root. The copies in `web/` are deployed by
    // `flutter build web` (Flutter copies `web/` → `build/web/` root), so they
    // are live at `<site>/<name>.html` with the exact same file names. The
    // copies in `public/` remain the bundled offline fallback: if the online
    // copy is unreachable, LocalWebViewScreen loads the bundled asset, so these
    // screens still work fully offline.
    const legalBase = 'https://qurani.info';
    String localizedHtml(String base) {
      final code = AppLocalizations.of(context)!.localeName;
      final lang = code.startsWith('ar') ? 'ar' : code.startsWith('fr') ? 'fr' : 'en';
      return 'public/'
          '${base}_$lang.html';
    }
    switch (setting.id) {
      case 'about':
        _showAboutDialog(context);
        break;
      case 'help':
        final fileName = localizedHtml('help').split('/').last;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.help,
              assetPath: localizedHtml('help'),
              onlineUrl: '$legalBase/$fileName',
            ),
          ),
        );
        break;
      case 'preferences':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PreferencesScreen(),
          ),
        );
        break;
      case 'offline_audio':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OfflineAudioScreen(),
          ),
        );
        break;
      case 'customize_screens':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ScreenCustomizationScreen(),
          ),
        );
        break;
      case 'share':
        _shareApp(context);
        break;
      case 'privacy':
        final privacyFileName = localizedHtml('privacy-policy').split('/').last;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.privacyPolicy,
              assetPath: localizedHtml('privacy-policy'),
              onlineUrl: '$legalBase/$privacyFileName',
            ),
          ),
        );
        break;
      case 'terms':
        final termsFileName = localizedHtml('conditions-terms').split('/').last;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.termsConditions,
              assetPath: localizedHtml('conditions-terms'),
              onlineUrl: '$legalBase/$termsFileName',
            ),
          ),
        );
        break;
    }
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    String versionText = '';
    try {
      final info = await PackageInfo.fromPlatform();
      final prettyVersion = info.version.isNotEmpty && info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version.isNotEmpty
              ? info.version
              : info.buildNumber;
      versionText = l10n.appVersionLabel(prettyVersion);
    } catch (_) {
      versionText = '';
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.aboutTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (versionText.isNotEmpty) Text(versionText),
              const SizedBox(height: 8),
              Text(l10n.aboutDescription),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;
      final appUrl = 'https://play.google.com/store/apps/details?id=$packageName';
      final message = l10n.shareAppMessage(appUrl);

      // Calculate share position origin for iPad
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unknownError)),
      );
    }
  }
}

class SettingItem {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  SettingItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

