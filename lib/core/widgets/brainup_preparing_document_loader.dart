import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Colorful dotted ring shown while scan pages are processed before preview.
class BrainUpPreparingDocumentLoader extends StatefulWidget {
  final String message;

  const BrainUpPreparingDocumentLoader({
    super.key,
    this.message = 'Preparing your document',
  });

  @override
  State<BrainUpPreparingDocumentLoader> createState() =>
      _BrainUpPreparingDocumentLoaderState();
}

class _BrainUpPreparingDocumentLoaderState
    extends State<BrainUpPreparingDocumentLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dotColors = [
      colors.accent,
      colors.success,
      colors.warning,
      colors.info,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              painter: _DottedRingPainter(
                rotation: _controller.value * 2 * math.pi,
                colors: dotColors,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          widget.message,
          style: text.h4.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'This will only take a moment',
          style: text.bodySmall.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DottedRingPainter extends CustomPainter {
  final double rotation;
  final List<Color> colors;

  _DottedRingPainter({required this.rotation, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.34;
    const dotCount = 12;

    for (var i = 0; i < dotCount; i++) {
      final angle = rotation + (i * 2 * math.pi / dotCount);
      final dotCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final color = colors[i % colors.length];
      final scale = 0.72 + 0.28 * ((math.sin(angle * 2) + 1) / 2);

      canvas.drawCircle(
        dotCenter,
        4.2 * scale,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DottedRingPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
