import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/physgame_theme.dart';
import '../simulation/gas_engine.dart';
import '../simulation/gas_particle.dart';

/// Histograma das velocidades das partículas (barras) comparado com a
/// distribuição de Maxwell-Boltzmann prevista para a temperatura atual
/// (curvas).
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
      child: SizedBox.expand(),
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
        ..color = PhysGameColors.muted
        ..strokeWidth = 1.3,
    );

    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      Paint()
        ..color = PhysGameColors.muted
        ..strokeWidth = 1.3,
    );

    const bins = 16;
    final light = List<int>.filled(bins, 0);
    final heavy = List<int>.filled(bins, 0);

    // Escala fixa pela temperatura: o eixo não pula a cada quadro.
    final maxSpeed =
        math.max(0.05, 2.6 * engine.rmsSpeedFor(ParticleSpecies.light));
    final binSpeed = maxSpeed / bins;

    for (final p in engine.particles) {
      final idx = (p.velocity.distance / binSpeed).floor().clamp(0, bins - 1);

      if (p.species == ParticleSpecies.light) {
        light[idx]++;
      } else {
        heavy[idx]++;
      }
    }

    // Contagem esperada por faixa segundo Maxwell-Boltzmann.
    double expected(ParticleSpecies species, int count, double speed) =>
        count * engine.speedDensity(speed, species) * binSpeed;

    final lightCount = engine.lightCount;
    final heavyCount = engine.heavyCount;

    double maxCount = 1;
    for (final v in [...light, ...heavy]) {
      maxCount = math.max(maxCount, v.toDouble());
    }
    for (int i = 0; i < bins; i++) {
      final v = (i + 0.5) * binSpeed;
      maxCount = math.max(
        maxCount,
        math.max(
          expected(ParticleSpecies.light, lightCount, v),
          expected(ParticleSpecies.heavy, heavyCount, v),
        ),
      );
    }
    maxCount *= 1.08;

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
          Radius.circular(3),
        ),
        Paint()..color = PhysGameColors.lightParticle.withValues(alpha: .75),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + binW * .52,
            plot.bottom - heavyH,
            barW,
            heavyH,
          ),
          Radius.circular(3),
        ),
        Paint()..color = PhysGameColors.heavyParticle.withValues(alpha: .6),
      );
    }

    // Curvas teóricas.
    void curve(ParticleSpecies species, int count, Color color) {
      if (count == 0) return;

      const samples = 80;
      final path = Path();
      for (int i = 0; i <= samples; i++) {
        final v = maxSpeed * i / samples;
        final y = plot.bottom -
            plot.height * (expected(species, count, v) / maxCount);
        final x = plot.left + plot.width * i / samples;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    curve(ParticleSpecies.light, lightCount, PhysGameColors.accentText);
    curve(ParticleSpecies.heavy, heavyCount, PhysGameColors.heavyAccent);

    _label(canvas, 'quantidade', Offset(3, 2));
    _label(
      canvas,
      'velocidade →',
      Offset(plot.center.dx - 32, size.height - 20),
    );
    _label(
      canvas,
      'barras: medido   linhas: Maxwell-Boltzmann',
      Offset(plot.right - 218, 2),
    );
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
  bool shouldRepaint(covariant _SpeedHistogramPainter oldDelegate) => true;
}
