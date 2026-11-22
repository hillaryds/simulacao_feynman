import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/physgame_theme.dart';
import '../../simulation/boyle_engine.dart';
import 'lab_painters.dart';

/// Conversões das unidades que já existem no laboratório PhysGame.
double boylePressureInUnit(double pressurePa, PressureUnit unit) {
  switch (unit) {
    case PressureUnit.kPa:
      return pressurePa / 1000;
    case PressureUnit.atm:
      return pressurePa / 101325;
    case PressureUnit.mmHg:
      return pressurePa / 133.322;
    case PressureUnit.kgfCm2:
      return pressurePa / 98066.5;
    case PressureUnit.bar:
      return pressurePa / 100000;
    case PressureUnit.psi:
      return pressurePa / 6894.757;
  }
}

String boyleFormatPressure(double pressurePa, PressureUnit unit) {
  final value = boylePressureInUnit(pressurePa, unit);
  final decimals = switch (unit) {
    PressureUnit.mmHg => 1,
    PressureUnit.kPa || PressureUnit.psi => 2,
    _ => 3,
  };
  return '${value.toStringAsFixed(decimals).replaceAll('.', ',')} '
      '${pressureUnitLabel(unit)}';
}

/// Fundo de escala de 600 mmHg para a compressão de 10 a 6 mL.
/// Em mmHg, cada marca menor vale 5 mmHg, com números a cada 100 mmHg.
GaugeScale boyleGaugeScale(PressureUnit unit) {
  switch (unit) {
    case PressureUnit.mmHg:
      return GaugeScale(max: 600, majors: 12, minorsPerMajor: 10,
          labelEvery: 2, unit: 'mmHg');
    case PressureUnit.kPa:
      return GaugeScale(max: 80, majors: 8, minorsPerMajor: 10,
          labelEvery: 2, unit: 'kPa');
    case PressureUnit.atm:
      return GaugeScale(max: .8, majors: 8, minorsPerMajor: 10,
          labelEvery: 2, unit: 'atm');
    case PressureUnit.kgfCm2:
      return GaugeScale(max: .8, majors: 8, minorsPerMajor: 10,
          labelEvery: 2, unit: 'kgf/cm²');
    case PressureUnit.bar:
      return GaugeScale(max: .8, majors: 8, minorsPerMajor: 10,
          labelEvery: 2, unit: 'bar');
    case PressureUnit.psi:
      return GaugeScale(max: 12, majors: 6, minorsPerMajor: 20,
          labelEvery: 1, unit: 'psi');
  }
}

/// Mostrador exclusivo de Boyle: marcas e ponteiro usam exatamente a mesma
/// transformação linear entre pressão e ângulo. O texto fica no centro,
/// sem invadir os algarismos da graduação.
void paintBoyleGauge(Canvas canvas, Offset center, double radius,
    double pressure, GaugeScale scale) {
  const startDegrees = 120.0;
  const sweepDegrees = 300.0;
  final outer = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(center, radius, Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD9DFEC), Color(0xFF667085), Color(0xFF475467)],
    ).createShader(outer));
  canvas.drawCircle(center, radius, Paint()
    ..color = const Color(0xFF475467)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke);
  canvas.drawCircle(center, radius - 9, Paint()..color = Colors.white);
  canvas.drawCircle(center, radius - 9, Paint()
    ..color = const Color(0xFFCDD5E3)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke);

  final total = scale.majors * scale.minorsPerMajor;
  final labelDistance = radius - 57;
  for (var i = 0; i <= total; i++) {
    final a = (startDegrees + sweepDegrees * i / total) * math.pi / 180;
    final major = i % scale.minorsPerMajor == 0;
    final intermediate = i % math.max(1, scale.minorsPerMajor ~/ 2) == 0;
    final r1 = radius - (major ? 38 : intermediate ? 32 : 27);
    final r2 = radius - 17;
    final stroke = Paint()
      ..color = const Color(0xFF1D2939)
      ..strokeWidth = major ? 2.5 : intermediate ? 1.8 : 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + Offset(math.cos(a) * r1, math.sin(a) * r1),
      center + Offset(math.cos(a) * r2, math.sin(a) * r2),
      stroke,
    );
    if (major && (i ~/ scale.minorsPerMajor) % scale.labelEvery == 0) {
      final mark = scale.max * i / total;
      final markLabel = mark >= 1
          ? mark.round().toString()
          : mark.toStringAsFixed(1).replaceAll('.', ',');
      final position = center + Offset(
        math.cos(a) * labelDistance,
        math.sin(a) * labelDistance,
      );
      final tp = TextPainter(
        text: TextSpan(text: markLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: Color(0xFF1D2939))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // A agulha é calculada pela mesma função que posiciona as marcas.
  final fraction = (pressure / scale.max).clamp(0.0, 1.0).toDouble();
  final angle = (startDegrees + sweepDegrees * fraction) * math.pi / 180;
  final tip = center + Offset(
    math.cos(angle) * (radius - 27),
    math.sin(angle) * (radius - 27),
  );
  canvas.drawLine(center, tip, Paint()
    ..color = PhysGameColors.mercury
    ..strokeWidth = 3.8
    ..strokeCap = StrokeCap.round);
  canvas.drawCircle(center, 9, Paint()..color = const Color(0xFF1D2939));
  canvas.drawCircle(center, 4, Paint()..color = PhysGameColors.mercury);

  void centralLabel(String text, double offsetY, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        fontSize: fontSize, fontWeight: FontWeight.w800, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + offsetY));
  }
  centralLabel('PRESSÃO', -31, 11, const Color(0xFF475467));
  centralLabel('MANOMÉTRICA', -18, 11, const Color(0xFF475467));
  centralLabel(scale.unit, 31, 14, PhysGameColors.purple);
}

/// Pintura da bancada, em coordenadas lógicas 760×490.
/// A representação das moléculas é apenas ilustrativa; a pressão é obtida
/// pela equação de estado do gás ideal, não por colisões simuladas.
class BoyleApparatusPainter extends CustomPainter {
  static const double width = 760;
  static const double height = 490;
  static const double pistonStartY = 157;
  static const double pistonTravel = 120;
  static const double pistonLeft = 517;
  static const double pistonRight = 604;

  final BoyleEngine engine;
  final PressureUnit unit;
  final bool analog;
  final double time;

  const BoyleApparatusPainter({
    required this.engine,
    required this.unit,
    required this.analog,
    required this.time,
  });

  double get pistonY => pistonStartY + pistonTravel *
      (engine.initialVolumeMl - engine.volumeMl) /
      (engine.initialVolumeMl - engine.minVolumeMl);

  @override
  void paint(Canvas canvas, Size size) {
    final background = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(background, Paint()..color = PhysGameColors.stage);
    _grid(canvas);
    _tubes(canvas);
    _gauge(canvas);
    _syringe(canvas);
    _bottomLabel(canvas);
  }

  Paint fill(Color color) => Paint()..color = color;
  Paint line(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void label(Canvas canvas, String text, Offset pos, {
    double size = 14, Color? color, FontWeight weight = FontWeight.w600,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text,
          style: TextStyle(fontSize: size, color: color ?? PhysGameColors.text,
              fontWeight: weight, height: 1.1)),
      textDirection: TextDirection.ltr,
    )..layout();
    double x = pos.dx;
    if (align == TextAlign.center) x -= tp.width / 2;
    if (align == TextAlign.right) x -= tp.width;
    tp.paint(canvas, Offset(x, pos.dy - tp.height / 2));
  }

  void _grid(Canvas c) {
    final p = line(PhysGameColors.line.withValues(alpha: .24), 1);
    for (double x = 0; x < width; x += 32) {
      c.drawLine(Offset(x, 0), Offset(x, height), p);
    }
    for (double y = 0; y < height; y += 32) {
      c.drawLine(Offset(0, y), Offset(width, y), p);
    }
    label(c, 'MANÔMETRO', const Offset(195, 24),
        size: 15, color: PhysGameColors.muted, align: TextAlign.center,
        weight: FontWeight.w800);
    label(c, 'PISTÃO GRADUADO', const Offset(567, 28),
        size: 15, color: PhysGameColors.muted, align: TextAlign.center,
        weight: FontWeight.w800);
  }

  void _tubes(Canvas c) {
    final tube = Path()
      ..moveTo(193, 313)
      ..lineTo(193, 438)
      ..quadraticBezierTo(193, 451, 207, 451)
      ..lineTo(529, 451)
      ..lineTo(529, 432);
    c.drawPath(tube, line(PhysGameColors.metalEdge, 16));
    c.drawPath(tube, line(PhysGameColors.metalMid, 10));
    c.drawPath(tube, line(PhysGameColors.purple2.withValues(alpha: .5), 4));
  }

  void _gauge(Canvas c) {
    const center = Offset(193, 186);
    const radius = 129.0;
    final scale = boyleGaugeScale(unit);
    final value = math.max(0.0,
        boylePressureInUnit(engine.gaugePressurePa, unit));

    if (analog) {
      paintBoyleGauge(c, center, radius, value, scale);
    } else {
      c.drawCircle(center, radius, fill(PhysGameColors.metalDark));
      c.drawCircle(center, radius - 8, fill(PhysGameColors.surface));
      c.drawCircle(center, radius - 8,
          line(PhysGameColors.line, 2));
      final display = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 205, height: 92),
          const Radius.circular(16));
      c.drawRRect(display, fill(PhysGameColors.surfaceHi));
      c.drawRRect(display, line(PhysGameColors.purple2, 2));
      label(c, 'PRESSÃO MANOMÉTRICA', center.translate(0, -75),
          size: 12, color: PhysGameColors.muted, align: TextAlign.center,
          weight: FontWeight.w800);
      label(c, value.toStringAsFixed(unit == PressureUnit.mmHg ? 1 : 2)
          .replaceAll('.', ','), center.translate(0, -9),
          size: 34, color: PhysGameColors.accentText,
          weight: FontWeight.w900, align: TextAlign.center);
      label(c, pressureUnitLabel(unit), center.translate(0, 34),
          size: 17, color: PhysGameColors.text, align: TextAlign.center);
      label(c, 'Leitura digital', center.translate(0, 88),
          size: 13, color: PhysGameColors.muted, align: TextAlign.center);
    }

    final readout = RRect.fromRectAndRadius(
        const Rect.fromLTWH(59, 337, 270, 62),
        const Radius.circular(14));
    c.drawRRect(readout, fill(PhysGameColors.surface));
    c.drawRRect(readout, line(PhysGameColors.line, 1.5));
    label(c, 'PRESSÃO RELATIVA', const Offset(194, 354),
        size: 12, color: PhysGameColors.muted,
        weight: FontWeight.w800, align: TextAlign.center);
    label(c, boyleFormatPressure(math.max(0.0, engine.gaugePressurePa), unit),
        const Offset(194, 377), size: 21, color: PhysGameColors.accentText,
        weight: FontWeight.w900, align: TextAlign.center);
  }

  void _syringe(Canvas c) {
    final py = pistonY;
    final outside = RRect.fromRectAndRadius(
        const Rect.fromLTRB(514, 133, 606, 445),
        const Radius.circular(9));
    c.drawRRect(outside, fill(PhysGameColors.glass.withValues(alpha: .24)));
    c.drawRRect(outside, line(PhysGameColors.metalEdge, 3));

    // Coluna de gás e moléculas ilustrativas (quantidade mantida).
    final gas = Rect.fromLTRB(521, py + 11, 599, 440);
    c.drawRect(gas, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [PhysGameColors.gasTop, PhysGameColors.gasBottom],
    ).createShader(gas));
    c.save();
    c.clipRect(gas);
    for (int i = 0; i < 43; i++) {
      final ax = _fract(math.sin(i * 17.17 + 0.5) * 15321.71);
      final ay = _fract(math.sin(i * 37.81 + 2.3) * 9832.48);
      final motion = math.sin(time * (0.65 + (i % 7) * .17) + i * 1.2);
      final motionY = math.cos(time * (0.45 + (i % 5) * .12) + i * 1.7);
      final x = gas.left + 7 + (gas.width - 14) *
          (ax + motion * 0.035).clamp(0.0, 1.0);
      final y = gas.top + 7 + (gas.height - 14) *
          (ay + motionY * 0.025).clamp(0.0, 1.0);
      final center = Offset(x, y);
      c.drawCircle(center, 3.4, fill(PhysGameColors.purple2));
      c.drawCircle(center.translate(-1, -1), 1.0,
          fill(Colors.white.withValues(alpha: .75)));
    }
    c.restore();

    // Escala: 10 a 6 mL nos parâmetros padrão; quatro divisões maiores.
    for (int tick = 0; tick <= 40; tick++) {
      final v = engine.initialVolumeMl -
          (engine.initialVolumeMl - engine.minVolumeMl) * tick / 40;
      final y = pistonStartY + pistonTravel * tick / 40;
      final major = tick % 10 == 0;
      c.drawLine(Offset(609, y), Offset(major ? 629 : 619, y),
          line(PhysGameColors.text, major ? 2 : 1));
      if (major) {
        label(c, '${v.toStringAsFixed(1).replaceAll('.', ',')} mL',
            Offset(635, y), size: 14, color: PhysGameColors.text,
            weight: FontWeight.w700);
      }
    }

    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(519, py - 11, 601, py + 11),
        const Radius.circular(3)), fill(PhysGameColors.metalDark));
    c.drawLine(Offset(520, py + 10), Offset(600, py + 10),
        line(PhysGameColors.metalEdge, 2));
    // Haste e alça acompanham a compressão.
    final stem = Rect.fromLTRB(552, py - 67, 569, py - 11);
    c.drawRect(stem, fill(PhysGameColors.metalMid));
    c.drawRect(stem, line(PhysGameColors.metalEdge, 1));
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(526, py - 87, 70, 20),
        const Radius.circular(8)), fill(PhysGameColors.purple2));
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(526, py - 87, 70, 20),
        const Radius.circular(8)), line(Colors.white.withValues(alpha: .6), 1));
    label(c, 'ARRASTE', Offset(561, py - 77), size: 11,
        color: Colors.white, weight: FontWeight.w900,
        align: TextAlign.center);
    label(c, 'V = ${engine.volumeMl.toStringAsFixed(2).replaceAll('.', ',')} mL',
        const Offset(564, 473), size: 17,
        color: PhysGameColors.accentText,
        weight: FontWeight.w900, align: TextAlign.center);
  }

  double _fract(double x) => x - x.floor();

  void _bottomLabel(Canvas c) {
    label(c, 'Compressão isotérmica • T = ${engine.temperatureC.toStringAsFixed(0)} °C',
        const Offset(30, 470), size: 13, color: PhysGameColors.muted);
  }

  @override
  bool shouldRepaint(covariant BoyleApparatusPainter old) => true;
}

/// Curva teórica absoluta P(V) e pontos registrados durante o experimento.
class BoylePVChart extends StatelessWidget {
  final BoyleEngine engine;
  const BoylePVChart({super.key, required this.engine});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BoylePVChartPainter(engine),
        child: const SizedBox.expand(),
      );
}

class _BoylePVChartPainter extends CustomPainter {
  final BoyleEngine engine;
  _BoylePVChartPainter(this.engine);

  @override
  void paint(Canvas c, Size size) {
    // A versão anterior retornava se height < 125, deixando o gráfico
    // em branco no layout compacto (que oferece cerca de 110 px aqui).
    if (size.width < 160 || size.height < 74) return;
    final plot = Rect.fromLTRB(55, 20, size.width - 16, size.height - 32);
    final vmin = engine.minVolumeMl;
    final vmax = engine.initialVolumeMl;
    final pmin = engine.atmosphericPressurePa * 0.92 / 1000;
    final pmax = engine.pressureAtVolumePa(vmin) * 1.06 / 1000;

    Offset pt(double v, double pKPa) => Offset(
      plot.left + (v - vmin) / (vmax - vmin) * plot.width,
      plot.bottom - (pKPa - pmin) / (pmax - pmin) * plot.height,
    );

    final gridPaint = Paint()..color = PhysGameColors.line..strokeWidth = 1;
    final axisPaint = Paint()..color = PhysGameColors.muted..strokeWidth = 1.3;
    for (int i = 0; i <= 4; i++) {
      final fy = i / 4;
      final y = plot.bottom - plot.height * fy;
      c.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(c, (pmin + (pmax - pmin) * fy).toStringAsFixed(0),
          Offset(plot.left - 8, y), align: TextAlign.right);
      final x = plot.left + plot.width * i / 4;
      c.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      _text(c, (vmin + (vmax - vmin) * i / 4).toStringAsFixed(1)
          .replaceAll('.', ','), Offset(x, plot.bottom + 17),
          align: TextAlign.center);
    }
    c.drawLine(plot.bottomLeft, plot.topLeft, axisPaint);
    c.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);

    final theoretical = Path();
    for (int i = 0; i <= 96; i++) {
      final v = vmin + (vmax - vmin) * i / 96;
      final point = pt(v, engine.pressureAtVolumePa(v) / 1000);
      if (i == 0) {
        theoretical.moveTo(point.dx, point.dy);
      } else {
        theoretical.lineTo(point.dx, point.dy);
      }
    }
    c.drawPath(theoretical, Paint()
      ..color = PhysGameColors.purple2
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);

    for (final sample in engine.readings) {
      final p = pt(sample.volumeMl, sample.absolutePressurePa / 1000);
      c.drawCircle(p, 5.4, Paint()..color = PhysGameColors.orange);
      c.drawCircle(p, 2.4, Paint()..color = Colors.white);
    }
    final current = pt(engine.volumeMl, engine.absolutePressureKPa);
    c.drawCircle(current, 8, Paint()
      ..color = PhysGameColors.accentText.withValues(alpha: .2));
    c.drawCircle(current, 4, Paint()..color = PhysGameColors.accentText);

    _text(c, 'P absoluta (kPa)', const Offset(5, 8), fontSize: 11);
    _text(c, 'Volume (mL)',
        Offset(plot.center.dx, size.height - 8), align: TextAlign.center,
        fontSize: 11);
  }

  void _text(Canvas canvas, String text, Offset offset, {
    TextAlign align = TextAlign.left, double fontSize = 10,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: PhysGameColors.muted, fontSize: fontSize,
        fontWeight: FontWeight.w600,
      )), textDirection: TextDirection.ltr,
    )..layout();
    var x = offset.dx;
    if (align == TextAlign.center) x -= tp.width / 2;
    if (align == TextAlign.right) x -= tp.width;
    tp.paint(canvas, Offset(x, offset.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoylePVChartPainter old) => true;
}
