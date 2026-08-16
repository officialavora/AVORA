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

void showAvoraGiftCelebration(
  BuildContext context, {
  required String emoji,
  required String giftName,
  required int quantity,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AvoraGiftCelebration(
      emoji: emoji,
      giftName: giftName,
      quantity: quantity,
      onFinished: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class AvoraGiftCelebration extends StatefulWidget {
  const AvoraGiftCelebration({
    super.key,
    required this.emoji,
    required this.giftName,
    required this.quantity,
    required this.onFinished,
  });
  final String emoji;
  final String giftName;
  final int quantity;
  final VoidCallback onFinished;

  @override
  State<AvoraGiftCelebration> createState() => _AvoraGiftCelebrationState();
}

class _AvoraGiftCelebrationState extends State<AvoraGiftCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  )..forward().whenComplete(widget.onFinished);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final value = _controller.value;
              final entrance = Curves.easeOutBack.transform(math.min(1, value * 2.4));
              final fade = value < .72 ? 1.0 : (1 - value) / .28;
              return Opacity(
                opacity: fade.clamp(0, 1).toDouble(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black.withValues(alpha: .38)),
                    for (var i = 0; i < 18; i++)
                      Positioned(
                        left: MediaQuery.sizeOf(context).width / 2 +
                            math.cos(i * .72 + value * 3) * (45 + value * 170),
                        top: MediaQuery.sizeOf(context).height / 2 +
                            math.sin(i * .72 + value * 3) * (45 + value * 210),
                        child: Transform.rotate(
                          angle: value * 5 + i,
                          child: Icon(
                            i.isEven ? Icons.auto_awesome : Icons.star_rounded,
                            color: i % 3 == 0 ? avoraGold : avoraMagenta,
                            size: 10 + (i % 4) * 4,
                          ),
                        ),
                      ),
                    Center(
                      child: Transform.scale(
                        scale: entrance,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              avoraGold.withValues(alpha: .34),
                              avoraRoyal.withValues(alpha: .18),
                              Colors.transparent,
                            ]),
                            boxShadow: const [
                              BoxShadow(color: Color(0xAAE154FF), blurRadius: 70, spreadRadius: 14),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.emoji, style: const TextStyle(fontSize: 96)),
                              Text(widget.giftName,
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                              Text('COMBO ×${widget.quantity}',
                                  style: const TextStyle(
                                    color: avoraGold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

class AvoraRoomEntryBanner extends StatefulWidget {
  const AvoraRoomEntryBanner({
    super.key,
    required this.name,
    this.prestige = 'NOBLE ENTRY',
  });
  final String name;
  final String prestige;

  @override
  State<AvoraRoomEntryBanner> createState() => _AvoraRoomEntryBannerState();
}

class _AvoraRoomEntryBannerState extends State<AvoraRoomEntryBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: Tween(begin: const Offset(-1.2, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(
          opacity: _controller,
          child: AvoraGlassPanel(
            radius: 18,
            accent: avoraGold,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.workspace_premium_rounded, color: avoraGold),
              const SizedBox(width: 9),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.prestige,
                    style: const TextStyle(color: avoraGold, fontSize: 10, letterSpacing: 1.6)),
                Text('${widget.name} entered the room',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ]),
          ),
        ),
      );
}
