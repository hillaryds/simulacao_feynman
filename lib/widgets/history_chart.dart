import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/physgame_theme.dart';
import '../simulation/gas_engine.dart';

class HistoryChart extends StatelessWidget {
  final List<SimulationSample> samples;

  const HistoryChart({
    super.key,
    required this.samples,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HistoryChartPainter(samples),
      child: SizedBox.expand(),
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  final List<SimulationSample> samples;

  _HistoryChartPainter(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(50, 12, size.width - 12, size.height - 32);

    for (int i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = PhysGameColors.line
          ..strokeWidth = 1,
      );
    }

    final axis = Paint()
      ..color = PhysGameColors.muted
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axis,
    );
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axis,
    );

    if (samples.length < 2) return;

    final minT = samples.first.time;
    final maxT = samples.last.time;

    double maxP = 100;
    for (final s in samples) {
      maxP = math.max(maxP, s.pressureKPa);
    }
    maxP *= 1.12;

    Offset mapPoint(SimulationSample s) {
      final nx = maxT == minT ? 0.0 : (s.time - minT) / (maxT - minT);
      final ny = (s.pressureKPa / maxP).clamp(0.0, 1.0);

      return Offset(
        plot.left + nx * plot.width,
        plot.bottom - ny * plot.height,
      );
    }

    final path = Path();

    for (int i = 0; i < samples.length; i++) {
      final p = mapPoint(samples[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = PhysGameColors.purple2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _label(canvas, 'P (kPa)', Offset(4, 2));
    _label(
      canvas,
      'tempo',
      Offset(plot.center.dx - 16, size.height - 20),
    );
    _label(canvas, maxP.toStringAsFixed(0), Offset(5, plot.top + 10));
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: PhysGameColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter oldDelegate) => true;
}
