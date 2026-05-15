import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ScannerOverlay extends StatefulWidget {
  final bool edgeDetected;
  const ScannerOverlay({super.key, this.edgeDetected = false});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.edgeDetected ? AppColors.success : AppColors.accent;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final pulse =
            1 + (_controller.value * (widget.edgeDetected ? 0.05 : 0.02));
        return Center(
          child: Transform.scale(
            scale: pulse,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.78,
              height: MediaQuery.of(context).size.height * 0.52,
              child: CustomPaint(
                painter: _ScannerCornerPainter(color: color),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScannerCornerPainter extends CustomPainter {
  final Color color;
  _ScannerCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const c = 34.0;
    canvas.drawLine(const Offset(0, c), const Offset(0, 0), p);
    canvas.drawLine(const Offset(0, 0), const Offset(c, 0), p);
    canvas.drawLine(Offset(size.width - c, 0), Offset(size.width, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, c), p);
    canvas.drawLine(Offset(0, size.height - c), Offset(0, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(c, size.height), p);
    canvas.drawLine(
      Offset(size.width - c, size.height),
      Offset(size.width, size.height),
      p,
    );
    canvas.drawLine(
      Offset(size.width, size.height - c),
      Offset(size.width, size.height),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerCornerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
