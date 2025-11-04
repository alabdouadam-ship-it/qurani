import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'local_webview_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'responsive_config.dart';
import 'preferences_screen.dart';
import 'advanced_options_screen.dart';
import 'support_us_screen.dart';
import 'contact_us_screen.dart';

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
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            const Color(0xFF2C2C2C),
                            const Color(0xFF1E1E1E),
                          ]
                        : [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.5)
                          : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.settings,
                      size: isSmallScreen ? 40 : 50,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              
              // Settings Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: isSmallScreen ? 10 : 15,
                    mainAxisSpacing: isSmallScreen ? 10 : 15,
                    childAspectRatio: isTablet ? 1.2 : 1.0,
                  ),
                  itemCount: _getSettings(context).length,
                  itemBuilder: (context, index) {
                    final setting = _getSettings(context)[index];
                    return _buildSettingCard(context, setting);
                  },
                ),
              ),
            ],
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
        id: 'support',
        icon: Icons.favorite_outline,
        title: l10n.supportUs,
        subtitle: '',
        color: Colors.redAccent,
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
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [
                setting.color.withOpacity(0.1),
                setting.color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: setting.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  setting.icon,
                  size: isSmallScreen ? 28 : 32,
                  color: setting.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                setting.title,
                style: TextStyle(
                  fontSize: ResponsiveConfig.getFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                setting.subtitle,
                style: TextStyle(
                  fontSize: ResponsiveConfig.getFontSize(context, 12),
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.help,
              assetPath: _localizedHtml('help'),
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
      case 'share':
        _shareApp(context);
        break;
      case 'privacy':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.privacyPolicy,
              assetPath: _localizedHtml('privacy-policy'),
            ),
          ),
        );
        break;
      case 'terms':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalWebViewScreen(
              title: AppLocalizations.of(context)!.termsConditions,
              assetPath: _localizedHtml('conditions-terms'),
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Help & Support'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to use Qurani:'),
              SizedBox(height: 8),
              Text('• Use the refresh button to clear cache'),
              Text('• Use settings for app preferences'),
              Text('• Use more options for additional features'),
              SizedBox(height: 8),
              Text('Need more help? Contact us at:'),
              Text('support@qurani.app'),
            ],
          ),
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

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Privacy Policy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data Collection:'),
                Text('• We do not collect personal data'),
                Text('• Cache is stored locally on your device'),
                SizedBox(height: 8),
                Text('Data Usage:'),
                Text('• Data is used only for app functionality'),
                Text('• No data is shared with third parties'),
                SizedBox(height: 8),
                Text('Contact: privacy@qurani.app'),
              ],
            ),
          ),
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

