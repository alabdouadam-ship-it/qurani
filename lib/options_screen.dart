import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'responsive_config.dart';
import 'services/update_service.dart';

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
    // final isTablet = ResponsiveConfig.isTablet(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book,
              color: Theme.of(context).colorScheme.onPrimary,
              size: ResponsiveConfig.getFontSize(context, 20),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.optionsTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveConfig.getFontSize(context, 18),
              ),
            ),
          ],
        ),
        centerTitle: false,
        flexibleSpace: Center(
          child: FutureBuilder<Map<String, String>?>(
            future: _getHijriDate(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final hijri = snapshot.data!;
                final isArabic = l10n.localeName == 'ar';
                final day = hijri['day'];
                final month = isArabic ? hijri['monthAr'] : hijri['monthEn'];
                final year = hijri['year'];
                return Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Text(
                    '$day $month $year',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveConfig.getFontSize(context, 14),
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
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
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: ResponsiveConfig.getPadding(context),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final options = _getOptions(context);
                    final width = constraints.maxWidth;
                          
                    // Determine column count
                    // On mobile: 2
                    // On web/tablet: adapt based on width
                    int crossAxisCount;
                    if (width < 600) {
                      crossAxisCount = 2;
                    } else {
                       const targetTileWidth = 180.0; 
                       final cols = width ~/ targetTileWidth;
                       crossAxisCount = cols.clamp(3, 8);
                    }
                    
                    final itemCount = options.length;
                    final rowCount = (itemCount / crossAxisCount).ceil();
                    
                    // Spacing
                    final spaceC = width < 600 ? 10.0 : 15.0;
                    final spaceM = width < 600 ? 10.0 : 15.0;
                    
                    // Calculate item width
                    final itemWidth = (width - (spaceC * (crossAxisCount - 1))) / crossAxisCount;
                    
                    // Calculate item height to fill vertical space
                    final totalSpacingHeight = spaceM * (rowCount - 1);
                    final availableHeight = constraints.maxHeight;
                    // Ensure we have a valid height
                    final safeHeight = availableHeight.isFinite ? availableHeight : 500.0;
                    
                    // Minimum height check to avoid extreme squashing on landscape
                    final minItemHeight = width < 600 ? 100.0 : 120.0;
                    
                    final calculatedItemHeight = (safeHeight - totalSpacingHeight) / rowCount;
                    // If calculated is too small, use min (scrolling will happen if needed)
                    // But user asked to "fill without scroll", so we prioritize fill.
                    // If we clamp to min, it might overflow. 
                    // But usually safeHeight is large enough.
                    final itemHeight = calculatedItemHeight < minItemHeight ? minItemHeight : calculatedItemHeight;
                    
                    final aspectRatio = (itemHeight > 0) ? (itemWidth / itemHeight) : 1.0;
      
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spaceC,
                      mainAxisSpacing: spaceM,
                      childAspectRatio: aspectRatio,
                      // Allow scrolling only if content overflows (e.g. forced minHeight)
                      // Otherwise it fits perfectly.
                      physics: const ScrollPhysics(), 
                      children: options.map((option) => _buildOptionCard(context, option)).toList(),
                    );
                  },
                ),
              ),
            ),
            if (kIsWeb) _buildWebFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWebFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // Reduced padding
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.downloadOurApp,
            style: TextStyle(
              fontSize: 14, // Reduced font size
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8), // Reduced spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStoreButton(
                context,
                icon: Icons.android,
                label: l10n.googlePlay,
                url: 'https://play.google.com/store/apps/details?id=com.qurani.app',
                color: const Color(0xFF3DDC84), // Android Green
              ),
              const SizedBox(width: 16), // Reduced spacing
              _buildStoreButton(
                context,
                icon: Icons.apple,
                label: l10n.appStore,
                url: 'https://apps.apple.com/app/id6757434993',
                color: Colors.black, // Apple Black
              ),
            ],
          ),
        ],
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
              color: color.withOpacity(0.3),
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
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () => _handleOptionTap(context, option),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.all(kIsWeb ? 8 : (isSmallScreen ? 10 : 14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [
                option.color.withAlpha((255 * 0.1).round()),
                option.color.withAlpha((255 * 0.05).round()),
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
                    color: option.color.withAlpha((255 * 0.1).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    option.icon,
                    size: kIsWeb ? 24 : (isSmallScreen ? 26 : 30),
                    color: option.color,
                  ),
                ),
              ),
              SizedBox(height: kIsWeb ? 6 : (isSmallScreen ? 8 : 10)),
              Flexible(
                child: Text(
                  option.title,
                  style: TextStyle(
                    fontSize: kIsWeb ? 11 : ResponsiveConfig.getFontSize(context, isSmallScreen ? 13 : 14),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (option.subtitle.isNotEmpty) ...[
                SizedBox(height: kIsWeb ? 2 : (isSmallScreen ? 2 : 4)),
                Flexible(
                  child: Text(
                    option.subtitle,
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
