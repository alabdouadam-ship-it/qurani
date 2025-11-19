import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'l10n/app_localizations.dart';
import 'responsive_config.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with WidgetsBindingObserver {
  final StreamController<LocationStatus> _locationStatusController =
      StreamController<LocationStatus>.broadcast();
  bool _hasSensorSupport = true;
  bool _isCheckingStatus = false;

  Stream<LocationStatus> get _locationStatusStream =>
      _locationStatusController.stream;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationStatusController.close();
    FlutterQiblah().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationStatus();
    }
  }

  Future<void> _checkLocationStatus() async {
    if (_isCheckingStatus) return;
    _isCheckingStatus = true;

    final status = await FlutterQiblah.checkLocationStatus();
    final enabled = status.enabled;
    var permission = status.status;

    if (enabled && permission == LocationPermission.denied) {
      permission = await FlutterQiblah.requestPermissions();
    }

    final sensorSupported = await FlutterQiblah.androidDeviceSensorSupport();

    if (mounted) {
      setState(() => _hasSensorSupport = sensorSupported ?? true);
      _locationStatusController.add(LocationStatus(enabled, permission));
    }

    _isCheckingStatus = false;
  }

  Future<void> _requestPermission() async {
    final permission = await FlutterQiblah.requestPermissions();
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) {
      _locationStatusController.add(LocationStatus(enabled, permission));
    }
    await _checkLocationStatus();
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await _checkLocationStatus();
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
    await _checkLocationStatus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmall = ResponsiveConfig.isSmallScreen(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore),
            const SizedBox(width: 8),
            Text(
              l10n.qiblaTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveConfig.getFontSize(context, 18),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkLocationStatus,
            tooltip: l10n.qiblaRetry,
          ),
        ],
      ),
      body: StreamBuilder<LocationStatus>(
        stream: _locationStatusStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return _buildStatus(
              colorScheme: colorScheme,
              icon: Icons.location_searching,
              message: l10n.qiblaCheckingStatus,
              actions: [
                FilledButton.icon(
                  onPressed: _checkLocationStatus,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.qiblaRetry),
                ),
              ],
            );
          }

          final status = snapshot.data!;

          if (!status.enabled) {
            return _buildStatus(
              colorScheme: colorScheme,
              icon: Icons.location_disabled,
              message: l10n.qiblaLocationDisabled,
              actions: [
                FilledButton.icon(
                  onPressed: _openLocationSettings,
                  icon: const Icon(Icons.settings),
                  label: Text(l10n.qiblaOpenLocationSettings),
                ),
                TextButton(
                  onPressed: _checkLocationStatus,
                  child: Text(l10n.qiblaRetry),
                ),
              ],
            );
          }

          switch (status.status) {
            case LocationPermission.always:
            case LocationPermission.whileInUse:
              if (!_hasSensorSupport) {
                return _buildStatus(
                  colorScheme: colorScheme,
                  icon: Icons.sensors_off,
                  message: l10n.qiblaSensorNotSupported,
                  actions: [
                    TextButton(
                      onPressed: _checkLocationStatus,
                      child: Text(l10n.qiblaRetry),
                    ),
                  ],
                );
              }
              return _buildCompass(colorScheme, isSmall);
            case LocationPermission.denied:
              return _buildStatus(
                colorScheme: colorScheme,
                icon: Icons.location_off,
                message: l10n.qiblaPermissionRequired,
                actions: [
                  FilledButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.qiblaRetry),
                  ),
                  TextButton(
                    onPressed: _openAppSettings,
                    child: Text(l10n.qiblaOpenAppSettings),
                  ),
                ],
              );
            case LocationPermission.deniedForever:
              return _buildStatus(
                colorScheme: colorScheme,
                icon: Icons.lock_outline,
                message: l10n.qiblaPermissionRequired,
                actions: [
                  FilledButton.icon(
                    onPressed: _openAppSettings,
                    icon: const Icon(Icons.settings),
                    label: Text(l10n.qiblaOpenAppSettings),
                  ),
                ],
              );
            case LocationPermission.unableToDetermine:
              return _buildStatus(
                colorScheme: colorScheme,
                icon: Icons.error_outline,
                message: l10n.unknownError,
                actions: [
                  FilledButton.icon(
                    onPressed: _checkLocationStatus,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.qiblaRetry),
                  ),
                ],
              );
          }
        },
      ),
    );
  }

  Widget _buildCompass(ColorScheme colorScheme, bool isSmall) {
    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildStatus(
            colorScheme: colorScheme,
            icon: Icons.error_outline,
            message: snapshot.error.toString(),
            actions: [
              FilledButton.icon(
                onPressed: _checkLocationStatus,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.qiblaRetry),
              ),
            ],
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return _buildStatus(
            colorScheme: colorScheme,
            icon: Icons.error_outline,
            message: l10n.unknownError,
            actions: [
              FilledButton.icon(
                onPressed: _checkLocationStatus,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.qiblaRetry),
              ),
            ],
          );
        }

        final compassAngle = -(data.direction * (math.pi / 180));
        final needleAngle = -(data.qiblah * (math.pi / 180));

        return Center(
          child: Padding(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CompassCard(
                  compassAngle: compassAngle,
                  needleAngle: needleAngle,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.qiblaTurnUntilArrowUp,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withAlpha((255 * 0.8).round()),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.qiblaAngleLabel(data.offset.toStringAsFixed(1)),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _TipChip(icon: Icons.my_location, label: l10n.qiblaTipGps),
                    _TipChip(icon: Icons.screen_rotation, label: l10n.qiblaTipCalibrate),
                    _TipChip(icon: Icons.sensors, label: l10n.qiblaTipInterference),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatus({
    required ColorScheme colorScheme,
    required IconData icon,
    required String message,
    List<Widget>? actions,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (actions != null && actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompassCard extends StatelessWidget {
  const _CompassCard({
    required this.compassAngle,
    required this.needleAngle,
  });

  final double compassAngle;
  final double needleAngle;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final diameter = math.min(size.width, size.height) * 0.6;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.primaryContainer.withAlpha((255 * 0.4).round()), color.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.06).round()),
            blurRadius: 12,
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: compassAngle,
            child: _CompassFace(diameter: diameter),
          ),
          Transform.rotate(
            angle: needleAngle,
            child: _Needle(diameter: diameter),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassFace extends StatelessWidget {
  const _CompassFace({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.outline.withAlpha((255 * 0.2).round()),
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(top: 12, child: const _Cardinal('N')),
          Positioned(bottom: 12, child: const _Cardinal('S')),
          Positioned(left: 12, child: const _Cardinal('W')),
          Positioned(right: 12, child: const _Cardinal('E')),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CustomPaint(
                painter: _CompassGuidePainter(color: color.outline.withAlpha((255 * 0.15).round())),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassGuidePainter extends CustomPainter {
  const _CompassGuidePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paint);

    final axisPaint = Paint()
      ..color = color
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      axisPaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      axisPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Needle extends StatelessWidget {
  const _Needle({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.navigation, size: diameter * 0.28, color: color),
        Container(
          width: 4,
          height: diameter * 0.18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _Cardinal extends StatelessWidget {
  const _Cardinal(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color.onSurfaceVariant)),
        ],
      ),
    );
  }
}


