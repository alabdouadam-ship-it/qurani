import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'responsive_config.dart';
import 'services/update_service.dart';

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
import 'services/preferences_service.dart';
import 'services/prayer_times_service.dart';


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
    final isTablet = ResponsiveConfig.isTablet(context);
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
        child: Padding(
          padding: ResponsiveConfig.getPadding(context),
          child: Column(
            children: [
              // Header - compact on web
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(kIsWeb ? 12 : (isSmallScreen ? 16 : 20)),
                margin: EdgeInsets.only(bottom: kIsWeb ? 12 : 20),
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
                  borderRadius: BorderRadius.circular(kIsWeb ? 10 : 15),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withAlpha((255 * 0.5).round())
                          : Theme.of(context).colorScheme.primary.withAlpha((255 * 0.3).round()),
                      blurRadius: kIsWeb ? 6 : 10,
                      offset: Offset(0, kIsWeb ? 3 : 5),
                    ),
                  ],
                ),
                child: FutureBuilder<Map<String, String>?>(
                  future: _getHijriDate(),
                  builder: (context, snapshot) {
                    final name = PreferencesService.getUserName().trim();
                    final greeting = name.isEmpty 
                        ? l10n.homeGreetingGeneric 
                        : l10n.homeGreetingNamed(name);
                    
                    String fullText = greeting;
                    if (snapshot.hasData && snapshot.data != null) {
                      final hijri = snapshot.data!;
                      final isArabic = l10n.localeName == 'ar';
                      final day = hijri['day'];
                      final month = isArabic ? hijri['monthAr'] : hijri['monthEn'];
                      final year = hijri['year'];
                      final hijriString = '$day $month $year';
                      
                      fullText = '$greeting\n$hijriString';
                    }

                    return Text(
                      fullText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ResponsiveConfig.getFontSize(context, kIsWeb ? 18 : 22),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
              
              // Options Grid - Fixed layout without scroll
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final options = _getOptions(context);
                    if (kIsWeb) {
                      // On web, use responsive grid with smaller cards (more columns)
                      final width = constraints.maxWidth;
                      final targetTileWidth = 180.0; // Reduced from 220 to fit more
                      final cols = width ~/ targetTileWidth;
                      final crossAxisCount = cols.clamp(3, 8); // Min 3, max 8 columns
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.25, // Slightly taller cards
                        physics: const NeverScrollableScrollPhysics(),
                        children: options.map((option) => _buildOptionCard(context, option)).toList(),
                      );
                    }
                    // Mobile/tablet default 2 columns - fit to screen
                    if (!kIsWeb) {
                      final crossAxisCount = 2;
                      final itemCount = options.length;
                      final rowCount = (itemCount / crossAxisCount).ceil();
                      
                      // Calculate available spacing
                      final spaceC = isSmallScreen ? 10.0 : 15.0; // Cross axis spacing
                      final spaceM = isSmallScreen ? 10.0 : 15.0; // Main axis spacing
                      
                      // Calculate width per item
                      final width = (constraints.maxWidth - (spaceC * (crossAxisCount - 1))) / crossAxisCount;
                      
                      // Calculate height per item
                      // We want it to fit in the available height, minus spacing
                      final totalSpacingHistory = spaceM * (rowCount - 1);
                      final height = (constraints.maxHeight - totalSpacingHistory) / rowCount;
                      
                      // Determine Aspect Ratio
                      // Guard against very small screens or weird layout constraints
                      final aspectRatio = (height > 0) ? (width / height) : 1.0;

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spaceC,
                        mainAxisSpacing: spaceM,
                        childAspectRatio: aspectRatio,
                        physics: const NeverScrollableScrollPhysics(), // Disable scrolling
                        children: options.map((option) => _buildOptionCard(context, option)).toList(),
                      );
                    }

                    // Web fallback (existing)
                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: isSmallScreen ? 10 : 15,
                      mainAxisSpacing: isSmallScreen ? 10 : 15,
                      childAspectRatio: isTablet ? 1.2 : 1.05,
                      children: options.map((option) => _buildOptionCard(context, option)).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
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
      if (!kIsWeb)
        OptionItem(
          id: 'tasbeeh',
          icon: Icons.countertops,
          title: l10n.tasbeeh,
          subtitle: '',
          color: Colors.green,
        ),

      // Row 4
      OptionItem(
        id: 'prayer_times',
        icon: Icons.schedule,
        title: l10n.prayerTimes,
        subtitle: '',
        color: Colors.orange,
      ),
      if (!kIsWeb)
        OptionItem(
          id: 'qibla',
          icon: Icons.explore,
          title: l10n.qiblaTitle,
          subtitle: '',
          color: Colors.teal,
        ),


      
      // Add more rows here as needed:
      // Row 3 (uncomment to add more options)
      // OptionItem(
      //   icon: Icons.audiotrack,
      //   title: 'Audio',
      //   subtitle: 'Recitations',
      //   color: Colors.deepOrange,
      // ),
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
                    fontSize: kIsWeb ? 12 : ResponsiveConfig.getFontSize(context, isSmallScreen ? 14 : 16),
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

      default:
        _showComingSoon(context, option.title);
    }
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
