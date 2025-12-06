import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'local_webview_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'responsive_config.dart';
import 'preferences_screen.dart';
import 'support_us_screen.dart';
import 'contact_us_screen.dart';
import 'offline_audio_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    final isTablet = ResponsiveConfig.isTablet(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.light,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: ResponsiveConfig.getPadding(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final settings = _getSettings(context);
              if (kIsWeb) {
                final width = constraints.maxWidth;
                final targetTileWidth = 180.0;
                final cols = width ~/ targetTileWidth;
                final crossAxisCount = cols.clamp(3, 8);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  physics: const NeverScrollableScrollPhysics(),
                  children: settings.map((s) => _buildSettingCard(context, s)).toList(),
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: isSmallScreen ? 10 : 15,
                mainAxisSpacing: isSmallScreen ? 10 : 15,
                childAspectRatio: isTablet ? 1.2 : 1.05,
                physics: const NeverScrollableScrollPhysics(),
                children: settings.map((s) => _buildSettingCard(context, s)).toList(),
              );
            },
          ),
        ),
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
      /*SettingItem(
        id: 'support',
        icon: Icons.favorite_outline,
        title: l10n.supportUs,
        subtitle: '',
        color: Colors.redAccent,
      ),*/
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
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () => _handleSettingTap(context, setting),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.all(kIsWeb ? 8 : (isSmallScreen ? 10 : 14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [
                setting.color.withAlpha((255 * 0.1).round()),
                setting.color.withAlpha((255 * 0.05).round()),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Container(
                  padding: EdgeInsets.all(kIsWeb ? 8 : (isSmallScreen ? 10 : 14)),
                  decoration: BoxDecoration(
                    color: setting.color.withAlpha((255 * 0.1).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    setting.icon,
                    size: kIsWeb ? 24 : (isSmallScreen ? 26 : 30),
                    color: setting.color,
                  ),
                ),
              ),
              SizedBox(height: kIsWeb ? 6 : (isSmallScreen ? 8 : 10)),
              Flexible(
                child: Text(
                  setting.title,
                  style: TextStyle(
                    fontSize: kIsWeb ? 12 : ResponsiveConfig.getFontSize(context, isSmallScreen ? 14 : 16),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (setting.subtitle.isNotEmpty) ...[
                SizedBox(height: kIsWeb ? 2 : (isSmallScreen ? 2 : 4)),
                Flexible(
                  child: Text(
                    setting.subtitle,
                    style: TextStyle(
                      fontSize: kIsWeb ? 10 : ResponsiveConfig.getFontSize(context, 11),
                      color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleSettingTap(BuildContext context, SettingItem setting) {
    String _localizedHtml(String base) {
      final code = AppLocalizations.of(context)!.localeName;
      final lang = code.startsWith('ar') ? 'ar' : code.startsWith('fr') ? 'fr' : 'en';
      return 'public/'
          '${base}_${lang}.html';
    }
    switch (setting.id) {
      case 'about':
        _showAboutDialog(context);
        break;
      case 'help':
        final fileName = _localizedHtml('help').split('/').last;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.help,
              assetPath: _localizedHtml('help'),
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
        final privacyFileName = _localizedHtml('privacy-policy').split('/').last;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.privacyPolicy,
              assetPath: _localizedHtml('privacy-policy'),
              onlineUrl: 'https://qurani.info/data/about-qurani/$privacyFileName',
            ),
          ),
        );
        break;
      case 'terms':
        final termsFileName = _localizedHtml('conditions-terms').split('/').last;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.termsConditions,
              assetPath: _localizedHtml('conditions-terms'),
              onlineUrl: 'https://qurani.info/data/about-qurani/$termsFileName',
            ),
          ),
        );
        break;
      case 'support':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SupportUsScreen(),
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
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;
      final appUrl = 'https://play.google.com/store/apps/details?id=$packageName';
      final message = l10n.shareAppMessage(appUrl);
      await Share.share(message);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
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
          title: Text('$feature'),
          content: Text('This feature is coming soon!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
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

