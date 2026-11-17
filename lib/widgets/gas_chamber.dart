import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/physgame_theme.dart';
import '../simulation/gas_engine.dart';
import '../simulation/gas_particle.dart';

class GasChamber extends StatelessWidget {
  final GasEngine engine;
  final ValueChanged<double> onVolumeChanged;

  const GasChamber({
    super.key,
    required this.engine,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            if (engine.constantMode == ConstantMode.volume) return;

            final delta =
                -details.delta.dy / math.max(1.0, constraints.maxHeight);

            onVolumeChanged(
              (engine.volumeL + delta * 5.0).clamp(1.0, 5.0),
            );
          },
          child: CustomPaint(
            painter: _GasChamberPainter(engine),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _GasChamberPainter extends CustomPainter {
  final GasEngine engine;

  _GasChamberPainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width * .08;
    final right = size.width * .88;
    final top = size.height * .06;
    final bottom = size.height * .90;
    final chamberH = bottom - top;
    final chamberW = right - left;

    final chamber = Rect.fromLTRB(left, top, right, bottom);

    canvas.drawRRect(
      RRect.fromRectAndRadius(chamber, const Radius.circular(28)),
      Paint()..color = const Color(0xFFFBFAFF),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(chamber, const Radius.circular(28)),
      Paint()
        ..color = const Color(0xFFD8D4F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final pistonY = top + engine.pistonY * chamberH;

    final gasRect = Rect.fromLTRB(
      left + 4,
      pistonY + 13,
      right - 4,
      bottom - 4,
    );

    canvas.drawRect(
      gasRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PhysGameColors.purple.withOpacity(.035),
            PhysGameColors.orange.withOpacity(.08),
          ],
        ).createShader(gasRect),
    );

    // Haste + pegador.
    final rodHeight = math.max(10.0, pistonY - top);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, top + rodHeight / 2),
          width: 18,
          height: rodHeight,
        ),
        const Radius.circular(9),
      ),
      Paint()..color = const Color(0xFFC9C4EE),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, top + 12),
          width: 82,
          height: 18,
        ),
        const Radius.circular(9),
      ),
      Paint()..color = PhysGameColors.navy,
    );

    final piston = Rect.fromLTRB(
      left + 8,
      pistonY,
      right - 8,
      pistonY + 18,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(piston, const Radius.circular(9)),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            PhysGameColors.purple2,
            PhysGameColors.purple,
          ],
        ).createShader(piston),
    );

    // Divisória de difusão.
    if (engine.diffusionMode) {
      final x = (left + right) / 2;

      if (!engine.barrierOpen) {
        canvas.drawRect(
          Rect.fromLTRB(x - 5, pistonY + 18, x + 5, bottom),
          Paint()..color = const Color(0xFF667085),
        );
      } else {
        canvas.drawLine(
          Offset(x, pistonY + 20),
          Offset(x, pistonY + 62),
          Paint()
            ..color = const Color(0xFF98A2B3)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(x, bottom - 44),
          Offset(x, bottom),
          Paint()
            ..color = const Color(0xFF98A2B3)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    for (final p in engine.particles) {
      final x = left + p.position.dx * chamberW;
      final y = top + p.position.dy * chamberH;
      if (y < pistonY || y > bottom) continue;

      final radius = p.radius * chamberW;
      final color = p.species == ParticleSpecies.light
          ? PhysGameColors.lightParticle
          : PhysGameColors.heavyParticle;

      canvas.drawCircle(
        Offset(x, y),
        radius + 3,
        Paint()..color = color.withOpacity(.09),
      );

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withOpacity(.92),
      );

      canvas.drawCircle(
        Offset(x - radius * .28, y - radius * .3),
        math.max(1.0, radius * .22),
        Paint()..color = Colors.white.withOpacity(.76),
      );

      if (p.velocity.distance > .18) {
        final d = p.velocity / p.velocity.distance;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + d.dx * 9, y + d.dy * 9),
          Paint()
            ..color = color.withOpacity(.38)
            ..strokeWidth = 1.1
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Escala de volume.
    for (int i = 1; i <= 5; i++) {
      final normalized = (i - 1) / 4.0;
      final engineY = .69 - normalized * .56;
      final y = top + engineY * chamberH;

      canvas.drawLine(
        Offset(right + 4, y),
        Offset(right + 14, y),
        Paint()
          ..color = PhysGameColors.slate
          ..strokeWidth = 1,
      );

      _text(
        canvas,
        '$i L',
        Offset(right + 18, y - 7),
        10,
        PhysGameColors.slate,
      );
    }

    // Base.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, bottom + 13),
          width: size.width * .60,
          height: 12,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = PhysGameColors.navy,
    );

    _textCentered(
      canvas,
      '${engine.pressureKPa.toStringAsFixed(1)} kPa',
      Offset(size.width / 2, math.min(bottom - 36, pistonY + 40)),
      13,
      PhysGameColors.slate,
      bold: true,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset pos,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, pos);
  }

  void _textCentered(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
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
  bool shouldRepaint(covariant _GasChamberPainter oldDelegate) => true;
}
