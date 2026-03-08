import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'local_webview_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'responsive_config.dart';
import 'preferences_screen.dart';

import 'contact_us_screen.dart';
import 'offline_audio_screen.dart';
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
      // Row 1
      SettingItem(
        id: 'preferences',
        icon: Icons.tune,
        title: l10n.preferences,
        subtitle: "",
        color: Colors.green,
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
      // Row 2
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
      // Row 3
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

      SettingItem(
        id: 'contact',
        icon: Icons.support_agent,
        title: l10n.contactUs,
        subtitle: '',
        color: Colors.teal,
      ),
      
      // Row 3 (uncomment to add more settings)
      // SettingItem(
      //   icon: Icons.notifications,
      //   title: 'Notifications',
      //   subtitle: 'Alert settings',
      //   color: Colors.orange,
      // ),
      // SettingItem(
      //   icon: Icons.language,
      //   title: 'Language',
      //   subtitle: 'App language',
      //   color: Colors.red,
      // ),
      
      // Row 4 (uncomment to add more settings)
      // SettingItem(
      //   icon: Icons.dark_mode,
      //   title: 'Theme',
      //   subtitle: 'App appearance',
      //   color: Colors.grey,
      // ),
      // SettingItem(
      //   icon: Icons.storage,
      //   title: 'Storage',
      //   subtitle: 'Cache management',
      //   color: Colors.brown,
      // ),
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
              onlineUrl: 'https://qurani.info/data/about-qurani/$fileName',
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
              onlineUrl: 'https://qurani.info/data/about-qurani/$privacyFileName',
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
              onlineUrl: 'https://qurani.info/data/about-qurani/$termsFileName',
            ),
          ),
        );
        break;

      case 'contact':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ContactUsScreen(),
          ),
        );
        break;
      default:
        _showComingSoon(context, setting.title);
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

  // Removed unused _showHelpDialog

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
      
      await Share.share(
        message,
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unknownError)),
      );
    }
  }

  // Removed unused _showPrivacyDialog

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(feature),
          content: const Text('This feature is coming soon!'),
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

