import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/providers/app_state_providers.dart';
import 'package:qurani/widgets/modern_ui.dart';

class ScreenCustomizationScreen extends ConsumerStatefulWidget {
  const ScreenCustomizationScreen({super.key});

  @override
  ConsumerState<ScreenCustomizationScreen> createState() =>
      _ScreenCustomizationScreenState();
}

class _ScreenCustomizationScreenState extends ConsumerState<ScreenCustomizationScreen> {

  void _toggleScreen(String screenId, bool isEnabled) {
    ref.read(disabledScreensProvider.notifier).toggleScreen(screenId, isEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // List of screens that can be customized (excluding 'news' as requested)
    final customizableScreens = [
      _CustomizableScreenData(
        id: 'read_quran',
        icon: Icons.menu_book,
        title: l10n.readQuran,
        color: Colors.blueGrey,
      ),
      _CustomizableScreenData(
        id: 'listen_quran',
        icon: Icons.headset,
        title: l10n.listenQuran,
        color: Colors.deepPurple,
      ),
      _CustomizableScreenData(
        id: 'repetition_memorization',
        icon: Icons.repeat,
        title: l10n.repetitionMemorization,
        color: Colors.teal,
      ),
      _CustomizableScreenData(
        id: 'memorization_test',
        icon: Icons.rule,
        title: l10n.memorizationTest,
        color: theme.colorScheme.primary,
      ),
      _CustomizableScreenData(
        id: 'search',
        icon: Icons.search,
        title: l10n.searchQuran,
        color: Colors.cyan,
      ),
      _CustomizableScreenData(
        id: 'tasbeeh',
        icon: Icons.countertops,
        title: l10n.tasbeeh,
        color: Colors.green,
      ),
      if (!kIsWeb)
        _CustomizableScreenData(
          id: 'prayer_times',
          icon: Icons.schedule,
          title: l10n.prayerTimes,
          color: Colors.orange,
        ),
      _CustomizableScreenData(
        id: 'hadith',
        icon: Icons.menu_book,
        title: l10n.hadithLibrary,
        color: Colors.brown,
      ),
      if (!kIsWeb)
        _CustomizableScreenData(
          id: 'qibla',
          icon: Icons.explore,
          title: l10n.qiblaTitle,
          color: Colors.teal,
        ),
    ];

    return ModernPageScaffold(
      title: l10n.localeName == 'ar'
          ? 'تخصيص الشاشات'
          : (l10n.localeName == 'fr'
              ? 'Personnaliser les écrans'
              : 'Customize Screens'),
      icon: Icons.dashboard_customize_outlined,
      subtitle: l10n.localeName == 'ar'
          ? 'يمكنك هنا اختيار الشاشات التي ترغب في ظهورها في القائمة الرئيسية.'
          : (l10n.localeName == 'fr'
              ? 'Ici, vous pouvez choisir les écrans que vous souhaitez voir apparaître dans le menu principal.'
              : 'Here you can choose the screens you want to appear in the main menu.'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ModernSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.localeName == 'ar'
                  ? 'يمكنك تخصيص الشاشات التي تراها في القائمة الرئيسية لتناسب احتياجاتك. الشاشات المعطلة لن تظهر في القائمة الرئيسية.'
                  : (l10n.localeName == 'fr'
                      ? 'Vous pouvez personnaliser les écrans que vous voyez dans le menu principal selon vos besoins. Les écrans désactivés n\'apparaîtront pas dans le menu principal.'
                      : 'You can customize the screens you see in the main menu to suit your needs. Disabled screens will not appear in the main menu.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...customizableScreens.map((screen) {
            final disabledScreens = ref.watch(disabledScreensProvider);
            final isEnabled = !disabledScreens.contains(screen.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ModernSurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: screen.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(screen.icon, color: screen.color),
                  ),
                  title: Text(
                    screen.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: isEnabled,
                  onChanged: (value) => _toggleScreen(screen.id, value),
                ),
              ),
            );
          }),
          // News and Notifications item (Non-toggleable as requested)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ModernSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.notifications, color: Colors.redAccent),
                ),
                title: Text(
                  l10n.newsAndNotifications,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                value: true,
                onChanged: null, // Disabled
                subtitle: Text(
                  l10n.localeName == 'ar'
                      ? 'هذه الشاشة أساسية ولا يمكن إخفاؤها.'
                      : (l10n.localeName == 'fr'
                          ? 'Cet écran est essentiel et ne peut pas être masqué.'
                          : 'This screen is essential and cannot be hidden.'),
                  style: TextStyle(
                      fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizableScreenData {
  final String id;
  final IconData icon;
  final String title;
  final Color color;

  _CustomizableScreenData({
    required this.id,
    required this.icon,
    required this.title,
    required this.color,
  });
}
