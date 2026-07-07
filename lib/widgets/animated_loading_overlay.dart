import 'dart:ui';
import 'package:flutter/material.dart';

/// Beautiful animated loading popup — dimmed blur backdrop + pulsing card.
class AnimatedLoadingOverlay {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    String message = 'Please wait…',
    String? subtitle,
    IconData icon = Icons.cloud_download_outlined,
  }) {
    hide();
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (ctx) => _LoadingPopup(
        message: message,
        subtitle: subtitle,
        icon: icon,
      ),
    );
    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  /// Runs [task] while showing the loading popup.
  static Future<T> run<T>(
    BuildContext context, {
    required Future<T> Function() task,
    String message = 'Please wait…',
    String? subtitle,
    IconData icon = Icons.cloud_download_outlined,
  }) async {
    show(context, message: message, subtitle: subtitle, icon: icon);
    try {
      return await task();
    } finally {
      hide();
    }
  }
}

class _LoadingPopup extends StatefulWidget {
  final String message;
  final String? subtitle;
  final IconData icon;

  const _LoadingPopup({
    required this.message,
    this.subtitle,
    required this.icon,
  });

  @override
  State<_LoadingPopup> createState() => _LoadingPopupState();
}

class _LoadingPopupState extends State<_LoadingPopup> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;
  late final AnimationController _dots;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _fade = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {},
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.18),
                        blurRadius: 32,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                    ],
                    border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: AnimatedBuilder(
                          animation: _spin,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _RingPainter(
                                progress: _spin.value,
                                color: cs.primary,
                                trackColor: cs.primaryContainer.withValues(alpha: 0.4),
                              ),
                              child: Center(child: child),
                            );
                          },
                          child: Icon(widget.icon, size: 34, color: cs.primary),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _BouncingDots(controller: _dots, color: cs.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _BouncingDots({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value + i * 0.2) % 1.0;
            final y = -6 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.1), color, color.withValues(alpha: 0.6)],
        transform: GradientRotation(progress * 6.283),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 6.283,
      2.2,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
