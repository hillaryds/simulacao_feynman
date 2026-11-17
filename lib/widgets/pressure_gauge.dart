import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lab/lab_painters.dart';

/// Manômetro do painel "Análise em tempo real".
/// Usa o mesmo desenho do manômetro do palco (estilo PhET), em kPa.
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
    final radius = math.min(size.width, size.height) / 2 - 2;

    paintPhetGauge(
      canvas,
      center,
      radius,
      pressureKPa / gaugeMax(PressureUnit.kPa),
      scale: gaugeScale(PressureUnit.kPa),
    );
  }

  @override
  bool shouldRepaint(covariant _PressureGaugePainter oldDelegate) {
    return oldDelegate.pressureKPa != pressureKPa;
  }
}
