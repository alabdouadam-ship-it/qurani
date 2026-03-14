import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/responsive_config.dart';

class ModernPageScaffold extends StatelessWidget {
  const ModernPageScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.subtitle,
    this.actions,
    this.padding,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.appBarBottom,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget body;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBarBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final overlayBrightness = theme.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: colorScheme.surface,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: overlayBrightness,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        actions: actions,
        bottom: appBarBottom,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withAlpha(theme.brightness == Brightness.dark ? 50 : 30),
              colorScheme.primaryContainer.withAlpha(theme.brightness == Brightness.dark ? 60 : 70),
              colorScheme.surface,
              colorScheme.surface,
            ],
            stops: const [0, 0.18, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: padding ?? ResponsiveConfig.getPadding(context),
            child: body,
          ),
        ),
      ),
    );
  }
}

class ModernHeroHeader extends StatelessWidget {
  const ModernHeroHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveConfig.isSmallScreen(context) ? 18 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withAlpha(theme.brightness == Brightness.dark ? 150 : 210),
            colorScheme.surface.withAlpha(theme.brightness == Brightness.dark ? 180 : 245),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outline.withAlpha(36),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(theme.brightness == Brightness.dark ? 18 : 12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: colorScheme.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveConfig.getFontSize(context, 20),
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: ResponsiveConfig.getFontSize(context, 13),
                      height: 1.35,
                      color: colorScheme.onSurface.withAlpha(170),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class ModernSurfaceCard extends StatelessWidget {
  const ModernSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(
          theme.brightness == Brightness.dark ? 95 : 150,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withAlpha(36),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(theme.brightness == Brightness.dark ? 18 : 10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(ResponsiveConfig.isSmallScreen(context) ? 16 : 18),
        child: child,
      ),
    );
  }
}

class ModernFeatureTile extends StatelessWidget {
  const ModernFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.subtitle = '',
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withAlpha(theme.brightness == Brightness.dark ? 72 : 40),
                theme.colorScheme.surface.withAlpha(theme.brightness == Brightness.dark ? 160 : 230),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha(34),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(theme.brightness == Brightness.dark ? 32 : 18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactHeight = constraints.maxHeight < 96;
              final tilePadding = compactHeight
                  ? 8.0
                  : (isSmallScreen ? 12.0 : 16.0);
              final iconPadding = compactHeight
                  ? 7.0
                  : (isSmallScreen ? 10.0 : 14.0);
              final iconSize = compactHeight
                  ? 20.0
                  : (isSmallScreen ? 24.0 : 30.0);
              final titleFontSize = compactHeight
                  ? 11.0
                  : (isSmallScreen ? 12.0 : 14.0);
              final spacing = compactHeight
                  ? 5.0
                  : (isSmallScreen ? 8.0 : 12.0);
              final subtitleFontSize = compactHeight ? 10.0 : 11.0;

              return Padding(
                padding: EdgeInsets.all(tilePadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: compactHeight ? 3 : 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: EdgeInsets.all(iconPadding),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    color.withAlpha(230),
                                    color.withAlpha(150),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                icon,
                                size: iconSize,
                                color: Colors.white,
                              ),
                            ),
                            if (badgeCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      badgeCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacing),
                    Flexible(
                      flex: subtitle.isNotEmpty ? 3 : 2,
                      child: Center(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: compactHeight ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ResponsiveConfig.getFontSize(context, titleFontSize),
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: compactHeight ? 3 : 6),
                      Flexible(
                        flex: 2,
                        child: Center(
                          child: Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ResponsiveConfig.getFontSize(context, subtitleFontSize),
                              color: theme.colorScheme.onSurface.withAlpha(165),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ModernFilterChip extends StatelessWidget {
  const ModernFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    )
                  : null,
              color: selected
                  ? null
                  : theme.colorScheme.primaryContainer.withAlpha(
                      theme.brightness == Brightness.dark ? 95 : 150,
                    ),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : theme.colorScheme.outline.withAlpha(36),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
