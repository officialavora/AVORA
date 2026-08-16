import 'dart:math' as math;
import 'package:flutter/material.dart';

const avoraVoid = Color(0xFF05030B);
const avoraRoyal = Color(0xFF7A3CFF);
const avoraMagenta = Color(0xFFE154FF);
const avoraGold = Color(0xFFFFD474);
const avoraCyan = Color(0xFF57D8FF);

class AvoraCinematicBackdrop extends StatefulWidget {
  const AvoraCinematicBackdrop({super.key, required this.child});
  final Widget child;

  @override
  State<AvoraCinematicBackdrop> createState() => _AvoraCinematicBackdropState();
}

class _AvoraCinematicBackdropState extends State<AvoraCinematicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF160A2B), avoraVoid, Color(0xFF070713)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _motion,
            builder: (_, __) {
              final phase = _motion.value * math.pi * 2;
              return Stack(children: [
                Positioned(
                  top: -110 + math.sin(phase) * 28,
                  right: -90 + math.cos(phase) * 24,
                  child: const _Aura(size: 310, color: avoraRoyal),
                ),
                Positioned(
                  bottom: -150 + math.cos(phase) * 32,
                  left: -120 + math.sin(phase) * 20,
                  child: const _Aura(size: 340, color: avoraMagenta),
                ),
                Positioned(
                  top: 260 + math.sin(phase) * 22,
                  left: -120,
                  child: const _Aura(size: 230, color: avoraCyan),
                ),
              ]);
            },
          ),
          widget.child,
        ],
      );
}

class _Aura extends StatelessWidget {
  const _Aura({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.06),
            Colors.transparent,
          ]),
        ),
      );
}

class AvoraGlassPanel extends StatelessWidget {
  const AvoraGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.accent = avoraRoyal,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.105),
              Colors.white.withValues(alpha: 0.035),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class AvoraPrestigeTitle extends StatelessWidget {
  const AvoraPrestigeTitle({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, avoraGold, Colors.white],
            ).createShader(bounds),
            child: Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                )),
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      );
}
