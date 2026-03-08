import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/responsive_config.dart';
import 'package:qurani/themes/app_theme_config.dart';
import 'package:qurani/widgets/theme_card.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({
    super.key,
    required this.selectedThemeId,
    required this.onThemeSelected,
  });

  final String selectedThemeId;
  final ValueChanged<String> onThemeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final localeCode = Localizations.localeOf(context).languageCode;
    const options = AppThemeConfig.themes;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 4 : width >= 600 ? 3 : 2;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(theme.brightness == Brightness.dark ? 100 : 160),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(35),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(theme.brightness == Brightness.dark ? 18 : 12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveConfig.isSmallScreen(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(36),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.theme,
                        style: TextStyle(
                          fontSize: ResponsiveConfig.getFontSize(context, 17),
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppThemeConfig.getTheme(selectedThemeId).localizedName(localeCode),
                        style: TextStyle(
                          fontSize: ResponsiveConfig.getFontSize(context, 13),
                          color: theme.colorScheme.onSurface.withAlpha(170),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GridView.builder(
              itemCount: options.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final item = options[index];
                return ThemeCard(
                  theme: item,
                  label: item.localizedName(localeCode),
                  selected: item.id == selectedThemeId,
                  onTap: () => onThemeSelected(item.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
