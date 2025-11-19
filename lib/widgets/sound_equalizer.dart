import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SoundEqualizer extends StatefulWidget {
  final AudioPlayer player;
  final double height;

  const SoundEqualizer({
    super.key,
    required this.player,
    this.height = 120,
  });

  @override
  State<SoundEqualizer> createState() => _SoundEqualizerState();
}

class _SoundEqualizerState extends State<SoundEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = List.generate(30, (_) => 0.2);
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    widget.player.playerStateStream.listen((state) {
      if (state.playing && mounted) {
        _controller.repeat();
      } else if (mounted) {
        _controller.stop();
        _controller.reset();
        setState(() {
          for (int i = 0; i < _barHeights.length; i++) {
            _barHeights[i] = 0.2;
          }
        });
      }
    });
    _controller.addListener(_updateBars);
  }

  void _updateBars() {
    if (!mounted) return;
    final state = widget.player.playerState;
    if (state.playing) {
      setState(() {
        for (int i = 0; i < _barHeights.length; i++) {
          final phase = i * 0.15; // more separation between bars
          final base = math.sin((_controller.value * 2 * math.pi) + phase) * 0.5 + 0.5;
          final noise = _random.nextDouble() * 0.15; // reduce noise
          _barHeights[i] = (base * 0.55 + noise * 0.45).clamp(0.15, 0.9);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final palette = <Color>[
      color.primary,
      color.secondary,
      // Tertiary may not exist on older schemes; fallback to primaryContainer
      Theme.of(context).colorScheme.tertiary,
      color.primaryContainer,
    ];
    return StreamBuilder<PlayerState>(
      stream: widget.player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        return Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barHeights.length, (index) {
              final height = _barHeights[index];
              final barHeight = height * widget.height * 0.8;
              final opacity = playing ? 0.6 + (height * 0.4) : 0.3;
              final barColor = palette[index % palette.length];
              return Container(
                width: 3,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      barColor.withAlpha((255 * opacity).round()),
                      barColor.withAlpha((255 * (opacity * 0.75)).round()),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

