import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'responsive_config.dart';
import 'services/update_service.dart';
import 'widgets/modern_ui.dart';

import 'package:url_launcher/url_launcher.dart';
import 'memorization_test_screen.dart';
import 'qibla_screen.dart';
import 'repetition_memorization_screen.dart';
import 'listen_quran_screen.dart';
import 'read_quran_screen.dart';
import 'tafsir_screen.dart';
import 'tasbeeh_screen.dart';
import 'settings_screen.dart';
import 'search_quran_screen.dart';
import 'prayer_times_screen.dart';
import 'services/prayer_times_service.dart';
import 'hadith_books_screen.dart';


class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  bool _updateCheckedThisSession = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_updateCheckedThisSession) {
      _updateCheckedThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Check for updates respecting weekly/daily rules
        await UpdateService.maybeCheckForUpdate(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    final l10n = AppLocalizations.of(context)!;

    return ModernPageScaffold(
      title: l10n.optionsTitle,
      icon: Icons.menu_book_rounded,
      subtitle: l10n.localeName == 'ar'
          ? 'رحلة هادئة بين القراءة والاستماع والأذكار والخدمات اليومية.'
          : l10n.localeName == 'fr'
              ? 'Un accès apaisant à la lecture, l’écoute, les adhkar et les outils quotidiens.'
              : 'A calm gateway to reading, listening, adhkar, and your daily Quran tools.',
      actions: [
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            size: ResponsiveConfig.getFontSize(context, isSmallScreen ? 20 : 24),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
          tooltip: l10n.settings,
        ),
      ],
      bottomNavigationBar: kIsWeb ? _buildWebFooter(context) : null,
      body: Column(
        children: [
          FutureBuilder<Map<String, String>?>(
            future: _getHijriDate(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final hijri = snapshot.data!;
                final isArabic = l10n.localeName == 'ar';
                final day = hijri['day'];
                final month = isArabic ? hijri['monthAr'] : hijri['monthEn'];
                final year = hijri['year'];
                final hijriLabel = l10n.localeName == 'ar'
                    ? 'التاريخ الهجري'
                    : l10n.localeName == 'fr'
                        ? 'Date hégirienne'
                        : 'Hijri date';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ModernSurfaceCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                '$hijriLabel: $day $month $year',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: ResponsiveConfig.getFontSize(context, 15),
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final options = _getOptions(context);
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                int crossAxisCount;
                if (width < 600) {
                  crossAxisCount = 2;
                } else {
                  const targetTileWidth = 180.0;
                  final cols = width ~/ targetTileWidth;
                  crossAxisCount = cols.clamp(3, 8);
                }
                final rowCount = (options.length / crossAxisCount).ceil();
                final spaceC = width < 600 ? 6.0 : 16.0;
                final spaceM = width < 600 ? 6.0 : 16.0;
                final itemWidth =
                    (width - (spaceC * (crossAxisCount - 1))) / crossAxisCount;
                final itemHeight = ((height - (spaceM * (rowCount - 1))) / rowCount)
                    .clamp(72.0, 220.0)
                    .toDouble();
                final aspectRatio = itemWidth / itemHeight;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spaceC,
                  mainAxisSpacing: spaceM,
                  childAspectRatio: aspectRatio,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: options.map((option) => _buildOptionCard(context, option)).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ModernSurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.downloadOurApp,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStoreButton(
                  context,
                  icon: Icons.android,
                  label: l10n.googlePlay,
                  url: 'https://play.google.com/store/apps/details?id=com.qurani.app',
                  color: const Color(0xFF3DDC84),
                ),
                const SizedBox(width: 16),
                _buildStoreButton(
                  context,
                  icon: Icons.apple,
                  label: l10n.appStore,
                  url: 'https://apps.apple.com/app/id6757434993',
                  color: Colors.black,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
    required Color color,
  }) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4, // Reduced blur
              offset: const Offset(0, 2), // Reduced offset
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20, // Reduced icon size
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12, // Reduced font size
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OptionItem> _getOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <OptionItem>[
      // Row 1
      OptionItem(
        id: 'listen_quran',
        icon: Icons.headset,
        title: l10n.listenQuran,
        subtitle: '',
        color: Colors.deepPurple,
      ),
      OptionItem(
        id: 'read_quran',
        icon: Icons.menu_book,
        title: l10n.readQuran,
        subtitle: '',
        color: Colors.blueGrey,
      ),
      
      // Row 2
      OptionItem(
        id: 'repetition_memorization',
        icon: Icons.repeat,
        title: l10n.repetitionMemorization,
        subtitle: '',
        color: Colors.teal,
      ),
      OptionItem(
        id: 'memorization_test',
        icon: Icons.rule,
        title: l10n.memorizationTest,
        subtitle: '',
        color: Theme.of(context).colorScheme.primary,
      ),

      // Row 3
      OptionItem(
        id: 'search',
         icon: Icons.search,
         title: l10n.searchQuran,
         subtitle: '',
         color: Colors.cyan,
       ),
      //if (!kIsWeb)
        OptionItem(
          id: 'tasbeeh',
          icon: Icons.countertops,
          title: l10n.tasbeeh,
          subtitle: '',
          color: Colors.green,
        ),

      // Row 4
      if (!kIsWeb)
        OptionItem(
          id: 'prayer_times',
          icon: Icons.schedule,
          title: l10n.prayerTimes,
          subtitle: '',
          color: Colors.orange,
        ),
      OptionItem(
        id: 'hadith',
        icon: Icons.menu_book,
        title: l10n.hadithLibrary,
        subtitle: '',
        color: Colors.brown,
      ),
      if (!kIsWeb)
        OptionItem(
          id: 'qibla',
          icon: Icons.explore,
          title: l10n.qiblaTitle,
          subtitle: '',
          color: Colors.teal,
        ),
      OptionItem(
        id: 'news',
        icon: Icons.notifications,
        title: l10n.newsAndNotifications,
        subtitle: '',
        color: Colors.redAccent,
      ),
    ];
    return items;
  }

  Widget _buildOptionCard(BuildContext context, OptionItem option) {
    return ModernFeatureTile(
      icon: option.icon,
      title: option.title,
      subtitle: option.subtitle,
      color: option.color,
      onTap: () => _handleOptionTap(context, option),
    );
  }

  void _handleOptionTap(BuildContext context, OptionItem option) {
    switch (option.id) {
      case 'memorization_test':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MemorizationTestScreen(),
          ),
        );
        break;
      case 'repetition_memorization':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RepetitionMemorizationScreen(),
          ),
        );
        break;
      case 'listen_quran':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ListenQuranScreen(),
          ),
        );
        break;
      case 'read_quran':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ReadQuranScreen(),
          ),
        );
        break;
      case 'tafsir':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TafsirScreen(),
          ),
        );
        break;
      case 'tasbeeh':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TasbeehScreen(),
          ),
        );
        break;
      case 'qibla':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const QiblaScreen(),
          ),
        );
        break;
      case 'hadith':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HadithBooksScreen(),
          ),
        );
        break;
      case 'prayer_times':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PrayerTimesScreen(),
          ),
        );
        break;
      case 'search':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SearchQuranScreen(),
          ),
        );
        break;
      case 'news':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noNewsMessage),
            duration: const Duration(seconds: 3),
            showCloseIcon: true,
          ),
        );
        break;

      default:
        _showComingSoon(context, option.title);
    }
  }

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

  Future<Map<String, String>?> _getHijriDate() async {
    try {
      final now = DateTime.now();
      return await PrayerTimesService.getHijriForDate(
        year: now.year, 
        month: now.month, 
        day: now.day
      );
    } catch (_) {
      return null;
    }
  }
}

class OptionItem {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  OptionItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
