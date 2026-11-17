import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/physgame_theme.dart';
import '../simulation/gas_engine.dart';
import '../simulation/gas_particle.dart';

class SpeedHistogram extends StatelessWidget {
  final GasEngine engine;

  const SpeedHistogram({
    super.key,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeedHistogramPainter(engine),
      child: const SizedBox.expand(),
    );
  }
}

class _SpeedHistogramPainter extends CustomPainter {
  final GasEngine engine;

  _SpeedHistogramPainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(38, 14, size.width - 12, size.height - 30);

    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      Paint()
        ..color = PhysGameColors.slate
        ..strokeWidth = 1.3,
    );

    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      Paint()
        ..color = PhysGameColors.slate
        ..strokeWidth = 1.3,
    );

    const bins = 12;
    final light = List<int>.filled(bins, 0);
    final heavy = List<int>.filled(bins, 0);

    double maxSpeed = .1;
    for (final p in engine.particles) {
      maxSpeed = math.max(maxSpeed, p.velocity.distance);
    }

    for (final p in engine.particles) {
      final idx = ((p.velocity.distance / maxSpeed) * (bins - 1))
          .floor()
          .clamp(0, bins - 1);

      if (p.species == ParticleSpecies.light) {
        light[idx]++;
      } else {
        heavy[idx]++;
      }
    }

    int maxCount = 1;
    for (final v in [...light, ...heavy]) {
      maxCount = math.max(maxCount, v);
    }

    final binW = plot.width / bins;
    final barW = binW * .34;

    for (int i = 0; i < bins; i++) {
      final x = plot.left + i * binW;

      final lightH = plot.height * (light[i] / maxCount);
      final heavyH = plot.height * (heavy[i] / maxCount);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + binW * .12,
            plot.bottom - lightH,
            barW,
            lightH,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = PhysGameColors.lightParticle.withOpacity(.78),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + binW * .52,
            plot.bottom - heavyH,
            barW,
            heavyH,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = PhysGameColors.heavyParticle.withOpacity(.78),
      );
    }

    _label(canvas, 'quantidade', const Offset(3, 2));
    _label(
      canvas,
      'velocidade →',
      Offset(plot.center.dx - 32, size.height - 20),
    );
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: PhysGameColors.slate,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SpeedHistogramPainter oldDelegate) => true;
}
