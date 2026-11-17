import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/physgame_theme.dart';

class PressureGauge extends StatelessWidget {
  final double pressureKPa;

  const PressureGauge({
    super.key,
    required this.pressureKPa,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PressureGaugePainter(pressureKPa),
      child: const SizedBox.expand(),
    );
  }
}

class _PressureGaugePainter extends CustomPainter {
  final double pressureKPa;

  _PressureGaugePainter(this.pressureKPa);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * .42;

    canvas.drawCircle(
      center,
      r + 6,
      Paint()..color = PhysGameColors.navy,
    );

    canvas.drawCircle(
      center,
      r,
      Paint()..color = Colors.white,
    );

    const start = 135.0;
    const sweep = 270.0;
    const maxPressure = 350.0;

    for (int i = 0; i <= 35; i++) {
      final t = i / 35;
      final a = (start + sweep * t) * math.pi / 180;
      final major = i % 5 == 0;

      final p1 = Offset(
        center.dx + math.cos(a) * r * (major ? .71 : .79),
        center.dy + math.sin(a) * r * (major ? .71 : .79),
      );
      final p2 = Offset(
        center.dx + math.cos(a) * r * .91,
        center.dy + math.sin(a) * r * .91,
      );

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = PhysGameColors.navy
          ..strokeWidth = major ? 2.2 : 1.0
          ..strokeCap = StrokeCap.round,
      );

      if (major) {
        _text(
          canvas,
          '${(maxPressure * t).round()}',
          Offset(
            center.dx + math.cos(a) * r * .56,
            center.dy + math.sin(a) * r * .56,
          ),
          8,
          PhysGameColors.navy,
        );
      }
    }

    _text(
      canvas,
      'kPa',
      Offset(center.dx, center.dy + r * .43),
      10,
      PhysGameColors.purple,
      bold: true,
    );

    final normalized = (pressureKPa / maxPressure).clamp(0.0, 1.0);
    final angle = (start + sweep * normalized) * math.pi / 180;

    final end = Offset(
      center.dx + math.cos(angle) * r * .68,
      center.dy + math.sin(angle) * r * .68,
    );

    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = PhysGameColors.orange
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, 8, Paint()..color = PhysGameColors.navy);
    canvas.drawCircle(center, 3.5, Paint()..color = PhysGameColors.orange);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PressureGaugePainter oldDelegate) {
    return oldDelegate.pressureKPa != pressureKPa;
  }
}
