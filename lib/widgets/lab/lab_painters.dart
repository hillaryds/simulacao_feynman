import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/physgame_theme.dart';
import '../../simulation/gas_engine.dart';
import '../../simulation/gas_particle.dart';

enum PressureUnit { kPa, atm, mmHg }

enum TemperatureUnit { kelvin, celsius, fahrenheit }

// ─────────────────────────────────────────────────────────────────────────
// Estado puramente visual do palco (não faz parte da física).
// ─────────────────────────────────────────────────────────────────────────
class LabViewState {
  /// Espécie que a bomba injeta.
  ParticleSpecies pumpSpecies = ParticleSpecies.light;

  /// Deslocamento da haste da bomba (0 = em repouso, StageGeometry.pumpTravel = embaixo).
  double pumpOffset = 0;

  PressureUnit pressureUnit = PressureUnit.kPa;
  TemperatureUnit temperatureUnit = TemperatureUnit.kelvin;

  bool showRuler = true;
  bool showStopwatch = false;
  bool showCollisions = false;

  bool particlesPanelOpen = true;
  bool finePanelOpen = false;

  bool stopwatchRunning = false;
  double _swAccum = 0;
  double _swMark = 0;
  int _collisionBase = 0;

  double stopwatchSeconds(GasEngine e) =>
      _swAccum +
      (stopwatchRunning ? math.max(0.0, e.simTime - _swMark) : 0.0);

  void toggleStopwatch(GasEngine e) {
    if (stopwatchRunning) {
      _swAccum = stopwatchSeconds(e);
      stopwatchRunning = false;
    } else {
      _swMark = e.simTime;
      stopwatchRunning = true;
    }
  }

  void resetStopwatch(GasEngine e) {
    _swAccum = 0;
    _swMark = e.simTime;
  }

  int collisions(GasEngine e) => math.max(0, e.totalCollisions - _collisionBase);

  void resetCollisions(GasEngine e) => _collisionBase = e.totalCollisions;

  /// Chamado a cada quadro: protege contra reinício do motor.
  void sync(GasEngine e) {
    if (e.totalCollisions < _collisionBase) _collisionBase = 0;
    if (e.simTime < _swMark) {
      _swMark = 0;
      _swAccum = 0;
    }
  }

  void resetTools() {
    pumpOffset = 0;
    stopwatchRunning = false;
    _swAccum = 0;
    _swMark = 0;
    _collisionBase = 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Conversões e formatação
// ─────────────────────────────────────────────────────────────────────────
String _comma(double v, int decimals) =>
    v.toStringAsFixed(decimals).replaceAll('.', ',');

String formatThousands(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

double pressureInUnit(GasEngine e, PressureUnit u) {
  switch (u) {
    case PressureUnit.kPa:
      return e.pressureKPa;
    case PressureUnit.atm:
      return e.pressureAtm;
    case PressureUnit.mmHg:
      return e.pressureMmHg;
  }
}

/// Fundo de escala do manômetro em cada unidade (≈ 350 kPa).
double gaugeMax(PressureUnit u) {
  switch (u) {
    case PressureUnit.kPa:
      return 350;
    case PressureUnit.atm:
      return 3.5;
    case PressureUnit.mmHg:
      return 2800;
  }
}

String pressureUnitLabel(PressureUnit u) {
  switch (u) {
    case PressureUnit.kPa:
      return 'kPa';
    case PressureUnit.atm:
      return 'atm';
    case PressureUnit.mmHg:
      return 'mmHg';
  }
}

String formatPressure(GasEngine e, PressureUnit u) {
  final v = pressureInUnit(e, u);
  final digits = u == PressureUnit.kPa ? 1 : (u == PressureUnit.atm ? 2 : 0);
  return '${_comma(v, digits)} ${pressureUnitLabel(u)}';
}

String temperatureUnitLabel(TemperatureUnit u) {
  switch (u) {
    case TemperatureUnit.kelvin:
      return 'K';
    case TemperatureUnit.celsius:
      return '°C';
    case TemperatureUnit.fahrenheit:
      return '°F';
  }
}

String formatTemperature(GasEngine e, TemperatureUnit u) {
  final k = e.temperatureK;
  switch (u) {
    case TemperatureUnit.kelvin:
      return '${k.round()} K';
    case TemperatureUnit.celsius:
      return '${(k - 273.15).round()} °C';
    case TemperatureUnit.fahrenheit:
      return '${((k - 273.15) * 9 / 5 + 32).round()} °F';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Geometria do palco (coordenadas lógicas 760 × 600).
// A mesma geometria é usada para desenhar e para detectar toques.
// ─────────────────────────────────────────────────────────────────────────
class StageGeometry {
  static const double width = 760;
  static const double height = 600;

  // Câmara
  static const double left = 58;
  static const double right = 458;
  static const double top = 96;
  static const double bottom = 476;
  static const double chamberW = right - left;
  static const double chamberH = bottom - top;

  /// Y (no palco) da face inferior da tampa = topo do gás.
  static double lidY(GasEngine e) => top + e.pistonY * chamberH;

  /// Barra da tampa + alça.
  static Rect lidHit(GasEngine e) {
    final y = lidY(e);
    return Rect.fromLTRB(46, y - 48, 470, y + 4);
  }

  // Manômetro / termômetro
  static const Offset gaugeCenter = Offset(612, 215);
  static const double gaugeRadius = 70;
  static const Rect pressureReadout = Rect.fromLTRB(556, 292, 668, 320);
  static const Rect temperatureReadout = Rect.fromLTRB(452, 14, 564, 42);

  // Bomba
  static const double pumpTravel = 40;
  static const double pumpHandleRestY = 372;
  static Rect pumpHandleHit(double offset) =>
      Rect.fromLTRB(588, pumpHandleRestY - 6 + offset, 684, pumpHandleRestY + 22 + offset);

  // Aquecedor / resfriador (balde)
  static const Rect bucket = Rect.fromLTRB(165, 510, 305, 592);
  static const double bucketKnobCenterY = 552;
  static const double bucketKnobTravel = 28;

  // Botões inferiores
  static const Offset playCenter = Offset(46, 562);
  static const double playRadius = 26;
  static const Offset stepCenter = Offset(100, 566);
  static const double stepRadius = 18;
  static const Rect eraser = Rect.fromLTRB(322, 550, 362, 580);
  static const Rect lightButton = Rect.fromLTRB(386, 544, 434, 592);
  static const Rect heavyButton = Rect.fromLTRB(442, 544, 490, 592);
  static const Offset resetCenter = Offset(726, 566);
  static const double resetRadius = 24;

  // Instrumentos flutuantes
  static const Rect stopwatch = Rect.fromLTRB(58, 14, 238, 72);
  static const Offset stopwatchPlay = Offset(196, 48);
  static const Offset stopwatchReset = Offset(222, 48);
  static const Rect collisionCounter = Rect.fromLTRB(250, 14, 440, 72);
}

// ─────────────────────────────────────────────────────────────────────────
// Utilitários de desenho
// ─────────────────────────────────────────────────────────────────────────
Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(
  Color c,
  double w, {
  StrokeCap cap = StrokeCap.butt,
  StrokeJoin join = StrokeJoin.miter,
}) =>
    Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = cap
      ..strokeJoin = join;

Shader _vGrad(Rect r, List<Color> colors, [List<double>? stops]) =>
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(r);

Shader _hGrad(Rect r, List<Color> colors, [List<double>? stops]) =>
    LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: colors,
      stops: stops,
    ).createShader(r);

void _drawText(
  Canvas canvas,
  String text,
  Offset anchor, {
  double size = 14,
  Color color = Colors.white,
  FontWeight weight = FontWeight.w700,
  TextAlign align = TextAlign.left,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  double dx = anchor.dx;
  if (align == TextAlign.center) dx = anchor.dx - tp.width / 2;
  if (align == TextAlign.right) dx = anchor.dx - tp.width;

  tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
}

/// Esfera com brilho (visual PhET): luz vinda do canto superior esquerdo.
Paint _spherePaint(Color base, double r) {
  return Paint()
    ..shader = ui.Gradient.radial(
      Offset(-r * 0.35, -r * 0.4),
      r * 1.7,
      [
        Color.lerp(base, Colors.white, 0.6)!,
        base,
        Color.lerp(base, Colors.black, 0.5)!,
      ],
      [0.0, 0.5, 1.0],
    );
}

void _drawSphere(Canvas canvas, Offset c, double r, Paint paint) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.drawCircle(Offset.zero, r, paint);
  canvas.restore();
}

void _drawDropArrow(Canvas canvas, Offset topLeft) {
  final path = Path()
    ..moveTo(topLeft.dx, topLeft.dy)
    ..lineTo(topLeft.dx + 10, topLeft.dy)
    ..lineTo(topLeft.dx + 5, topLeft.dy + 6)
    ..close();
  canvas.drawPath(path, _fill(PhysGameColors.navy));
}

// ─────────────────────────────────────────────────────────────────────────
// Manômetro estilo PhET (também usado no painel "Análise em tempo real").
// [fraction] vai de 0 a 1 ao longo de 240° (de 150° a 390°).
// ─────────────────────────────────────────────────────────────────────────
void paintPhetGauge(
  Canvas canvas,
  Offset center,
  double outerRadius,
  double fraction, {
  String label = 'Pressão',
}) {
  final s = outerRadius / 70.0;

  // Aro metálico
  canvas.drawCircle(
    center,
    outerRadius,
    Paint()
      ..shader = ui.Gradient.radial(
        center.translate(0, -outerRadius * 0.2),
        outerRadius * 1.1,
        const [Color(0xFFE4E7EC), PhysGameColors.metalEdge],
      ),
  );
  canvas.drawCircle(center, outerRadius, _stroke(const Color(0xFF475467), 1.5 * s));

  // Mostrador
  canvas.drawCircle(center, 62 * s, _fill(const Color(0xFFF9FAFB)));
  canvas.drawCircle(center, 62 * s, _stroke(PhysGameColors.metalDark, 1.5 * s));

  // Marcas (25 → uma maior a cada 4)
  for (int i = 0; i <= 24; i++) {
    final a = (150 + 240 * (i / 24)) * math.pi / 180;
    final major = i % 4 == 0;
    final r1 = (major ? 44 : 50) * s;
    final r2 = 58 * s;
    canvas.drawLine(
      Offset(center.dx + math.cos(a) * r1, center.dy + math.sin(a) * r1),
      Offset(center.dx + math.cos(a) * r2, center.dy + math.sin(a) * r2),
      _stroke(
        PhysGameColors.navy,
        (major ? 2.6 : 1.4) * s,
        cap: StrokeCap.round,
      ),
    );
  }

  _drawText(
    canvas,
    label,
    center.translate(0, -15 * s),
    size: 15 * s,
    color: PhysGameColors.navy,
    align: TextAlign.center,
  );

  // Ponteiro
  final f = fraction.clamp(0.0, 1.0);
  final angle = (150 + 240 * f) * math.pi / 180;
  final tip = Offset(
    center.dx + math.cos(angle) * 46 * s,
    center.dy + math.sin(angle) * 46 * s,
  );

  canvas.drawLine(
    center,
    tip,
    _stroke(PhysGameColors.mercury, 4 * s, cap: StrokeCap.round),
  );
  canvas.drawCircle(center, 6 * s, _fill(PhysGameColors.navy));
  canvas.drawCircle(center, 2.5 * s, _fill(PhysGameColors.mercury));
}

// ─────────────────────────────────────────────────────────────────────────
// Painter do palco completo
// ─────────────────────────────────────────────────────────────────────────
class LabStagePainter extends CustomPainter {
  final GasEngine engine;
  final LabViewState view;

  LabStagePainter(this.engine, this.view);

  static const double _l = StageGeometry.left;
  static const double _r = StageGeometry.right;
  static const double _t = StageGeometry.top;
  static const double _b = StageGeometry.bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final lid = StageGeometry.lidY(engine);

    _paintChamber(canvas, lid);
    _paintParticles(canvas, lid);
    if (engine.diffusionMode) _paintBarrier(canvas, lid);
    if (view.showRuler) _paintRuler(canvas, lid);
    _paintWalls(canvas, lid);
    _paintLid(canvas, lid);
    _paintPipeAndGauge(canvas);
    _paintThermometer(canvas);
    _paintPumpAndHose(canvas);
    _paintBucket(canvas);
    _paintBottomControls(canvas);
    if (view.showStopwatch) _paintStopwatch(canvas);
    if (view.showCollisions) _paintCollisionCounter(canvas);
  }

  // ── Câmara ──────────────────────────────────────────────────────────
  void _paintChamber(Canvas canvas, double lid) {
    // Cilindro acima da tampa (esmaecido).
    canvas.drawRect(
      Rect.fromLTRB(_l, _t, _r, lid),
      _stroke(Colors.white.withOpacity(.22), 3),
    );

    // Escala de volume (à esquerda).
    for (int i = 1; i <= 5; i++) {
      final y = _t + (0.69 - ((i - 1) / 4.0) * 0.56) * StageGeometry.chamberH;
      canvas.drawLine(
        Offset(44, y),
        Offset(54, y),
        _stroke(PhysGameColors.metalDark, 1.5),
      );
      _drawText(
        canvas,
        '$i L',
        Offset(40, y),
        size: 11,
        color: PhysGameColors.metalDark,
        weight: FontWeight.w600,
        align: TextAlign.right,
      );
    }

    // Interior do gás.
    final gas = Rect.fromLTRB(_l, lid, _r, _b);
    canvas.drawRect(
      gas,
      Paint()
        ..shader = _vGrad(
          gas,
          const [PhysGameColors.gasTop, PhysGameColors.gasBottom],
        ),
    );

    // Brilho do aquecedor / resfriador no piso.
    final h = engine.heaterLevel;
    if (h.abs() > 0.02) {
      final c = h > 0 ? PhysGameColors.heatColor : PhysGameColors.coolColor;
      final glowTop = math.max(lid, _b - 90);
      canvas.drawRect(
        Rect.fromLTRB(_l, glowTop, _r, _b),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, _b),
            Offset(0, glowTop),
            [c.withOpacity(.55 * h.abs()), c.withOpacity(0)],
          ),
      );
    }
  }

  void _paintParticles(Canvas canvas, double lid) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_l, lid, _r, _b));

    final lightR = GasEngine.lightRadius * StageGeometry.chamberW;
    final heavyR = GasEngine.heavyRadius * StageGeometry.chamberW;
    final lightPaint = _spherePaint(PhysGameColors.lightParticle, lightR);
    final heavyPaint = _spherePaint(PhysGameColors.heavyParticle, heavyR);

    for (final p in engine.particles) {
      final x = _l + p.position.dx * StageGeometry.chamberW;
      final y = _t + p.position.dy * StageGeometry.chamberH;
      final isLight = p.species == ParticleSpecies.light;

      _drawSphere(
        canvas,
        Offset(x, y),
        isLight ? lightR : heavyR,
        isLight ? lightPaint : heavyPaint,
      );
    }

    canvas.restore();
  }

  void _paintBarrier(Canvas canvas, double lid) {
    final x = (_l + _r) / 2;

    if (!engine.barrierOpen) {
      canvas.drawRect(
        Rect.fromLTRB(x - 5, lid, x + 5, _b),
        Paint()
          ..shader = _hGrad(
            Rect.fromLTRB(x - 5, lid, x + 5, _b),
            const [PhysGameColors.metalDark, PhysGameColors.metalLight, PhysGameColors.metalDark],
          ),
      );
    } else {
      final p = _stroke(PhysGameColors.metalDark, 4, cap: StrokeCap.round);
      canvas.drawLine(Offset(x, lid + 2), Offset(x, lid + 44), p);
      canvas.drawLine(Offset(x, _b - 44), Offset(x, _b), p);
    }
  }

  void _paintRuler(Canvas canvas, double lid) {
    const x = _l + 26.0;
    final y1 = lid + 8;
    final y2 = _b - 8;
    if (y2 - y1 < 30) return;

    const amber = PhysGameColors.amber;
    final line = _stroke(amber, 2, cap: StrokeCap.round);

    // Linha tracejada
    double y = y1 + 6;
    while (y < y2 - 6) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 6, y2 - 6)), line);
      y += 10;
    }

    // Pontas de seta
    final up = Path()
      ..moveTo(x, y1)
      ..lineTo(x - 5, y1 + 10)
      ..lineTo(x + 5, y1 + 10)
      ..close();
    final down = Path()
      ..moveTo(x, y2)
      ..lineTo(x - 5, y2 - 10)
      ..lineTo(x + 5, y2 - 10)
      ..close();
    canvas.drawPath(up, _fill(amber));
    canvas.drawPath(down, _fill(amber));

    // Etiqueta
    final mid = (y1 + y2) / 2;
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + 10, mid - 12, 86, 24),
      const Radius.circular(12),
    );
    canvas.drawRRect(pill, _fill(amber));
    _drawText(
      canvas,
      'V = ${_comma(engine.volumeL, 2)} L',
      Offset(x + 10 + 43, mid),
      size: 13,
      color: PhysGameColors.navy,
      weight: FontWeight.w800,
      align: TextAlign.center,
    );
  }

  void _paintWalls(Canvas canvas, double lid) {
    final walls = Path()
      ..moveTo(_l, lid)
      ..lineTo(_l, _b)
      ..lineTo(_r, _b)
      ..lineTo(_r, lid);

    canvas.drawPath(walls, _stroke(Colors.white, 4));
  }

  // ── Tampa (pistão) com alça ranhurada ──────────────────────────────
  void _paintLid(Canvas canvas, double lid) {
    final bar = Rect.fromLTRB(50, lid - 14, 466, lid);
    final barR = RRect.fromRectAndRadius(bar, const Radius.circular(3));
    canvas.drawRRect(
      barR,
      Paint()
        ..shader = _vGrad(
          bar,
          const [PhysGameColors.metalLight, PhysGameColors.metalDark],
        ),
    );
    canvas.drawRRect(barR, _stroke(PhysGameColors.metalEdge, 1.5));

    // Haste que liga a alça à tampa.
    final stem = Rect.fromLTRB(424, lid - 28, 434, lid - 14);
    canvas.drawRect(stem, _fill(PhysGameColors.metalDark));
    canvas.drawRect(stem, _stroke(PhysGameColors.metalEdge, 1));

    // Alça
    final grip = Rect.fromLTRB(366, lid - 44, 432, lid - 20);
    final gripR = RRect.fromRectAndRadius(grip, const Radius.circular(8));
    canvas.drawRRect(
      gripR,
      Paint()
        ..shader = _vGrad(
          grip,
          const [PhysGameColors.metalLight, PhysGameColors.metalDark],
        ),
    );
    canvas.drawRRect(gripR, _stroke(PhysGameColors.metalEdge, 1.5));

    final groove = _stroke(PhysGameColors.metalEdge, 2, cap: StrokeCap.round);
    for (int i = 0; i < 6; i++) {
      final gx = 380.0 + i * 9;
      canvas.drawLine(Offset(gx, lid - 38), Offset(gx, lid - 26), groove);
    }
  }

  // ── Tubo + manômetro ───────────────────────────────────────────────
  void _paintPipeAndGauge(Canvas canvas) {
    final pipe = Rect.fromLTRB(458, 207, 550, 223);
    canvas.drawRect(
      pipe,
      Paint()
        ..shader = _vGrad(
          pipe,
          const [PhysGameColors.metalLight, PhysGameColors.metalDark],
        ),
    );
    canvas.drawRect(pipe, _stroke(PhysGameColors.metalEdge, 1));

    for (final r in const [
      Rect.fromLTRB(446, 199, 460, 231),
      Rect.fromLTRB(540, 200, 552, 230),
    ]) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
      canvas.drawRRect(rr, _fill(PhysGameColors.metalDark));
      canvas.drawRRect(rr, _stroke(PhysGameColors.metalEdge, 1));
    }

    final unit = view.pressureUnit;
    paintPhetGauge(
      canvas,
      StageGeometry.gaugeCenter,
      StageGeometry.gaugeRadius,
      pressureInUnit(engine, unit) / gaugeMax(unit),
    );

    _paintReadout(
      canvas,
      StageGeometry.pressureReadout,
      formatPressure(engine, unit),
    );
  }

  void _paintReadout(Canvas canvas, Rect box, String text) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      _fill(Colors.white),
    );
    _drawText(
      canvas,
      text,
      Offset(box.right - 34, box.center.dy),
      size: 14,
      color: PhysGameColors.navy,
      align: TextAlign.right,
    );
    _drawDropArrow(canvas, Offset(box.right - 18, box.center.dy - 3));
  }

  // ── Termômetro ─────────────────────────────────────────────────────
  void _paintThermometer(Canvas canvas) {
    final connector = Rect.fromLTRB(458, 172, 492, 180);
    canvas.drawRect(
      connector,
      Paint()
        ..shader = _vGrad(
          connector,
          const [PhysGameColors.metalLight, PhysGameColors.metalDark],
        ),
    );
    canvas.drawRect(connector, _stroke(PhysGameColors.metalEdge, 1));

    final glassFill = _fill(Colors.white.withOpacity(.10));
    final glassEdge = _stroke(PhysGameColors.metalMid, 2);

    final tube = RRect.fromRectAndRadius(
      Rect.fromLTRB(498, 62, 516, 182),
      const Radius.circular(9),
    );
    canvas.drawRRect(tube, glassFill);
    canvas.drawRRect(tube, glassEdge);
    canvas.drawCircle(const Offset(507, 178), 16, glassFill);
    canvas.drawCircle(const Offset(507, 178), 16, glassEdge);

    // Mercúrio
    canvas.drawCircle(const Offset(507, 178), 11, _fill(PhysGameColors.mercury));
    final frac = (engine.temperatureK / 700.0).clamp(0.0, 1.0);
    final merc = frac * 112;
    canvas.drawRect(
      Rect.fromLTRB(503, 178 - merc, 511, 178),
      _fill(PhysGameColors.mercury),
    );

    // Marcas
    final tick = _stroke(PhysGameColors.metalMid, 1.5);
    for (int i = 0; i <= 8; i++) {
      final y = 70.0 + i * 13;
      canvas.drawLine(Offset(522, y), Offset(i.isEven ? 532 : 527, y), tick);
    }

    _paintReadout(
      canvas,
      StageGeometry.temperatureReadout,
      formatTemperature(engine, view.temperatureUnit),
    );
  }

  // ── Bomba + mangueira ──────────────────────────────────────────────
  void _paintPumpAndHose(Canvas canvas) {
    final hose = Path()
      ..moveTo(614, 520)
      ..cubicTo(540, 520, 520, 420, 458, 420);
    canvas.drawPath(
      hose,
      _stroke(PhysGameColors.slate, 11, cap: StrokeCap.round),
    );
    canvas.drawPath(
      hose,
      _stroke(PhysGameColors.metalDark, 7, cap: StrokeCap.round),
    );

    final collar = RRect.fromRectAndRadius(
      Rect.fromLTRB(446, 409, 460, 431),
      const Radius.circular(3),
    );
    canvas.drawRRect(collar, _fill(PhysGameColors.metalDark));
    canvas.drawRRect(collar, _stroke(PhysGameColors.metalEdge, 1));

    // Base
    final base = Rect.fromLTRB(586, 566, 686, 582);
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, const Radius.circular(6)),
      Paint()
        ..shader = _vGrad(
          base,
          const [PhysGameColors.metalLight, PhysGameColors.metalDark],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, const Radius.circular(6)),
      _stroke(PhysGameColors.metalEdge, 1),
    );
    final foot = Rect.fromLTRB(606, 552, 666, 568);
    canvas.drawRRect(
      RRect.fromRectAndRadius(foot, const Radius.circular(4)),
      Paint()
        ..shader = _hGrad(
          foot,
          const [
            PhysGameColors.metalDark,
            PhysGameColors.metalLight,
            PhysGameColors.metalDark,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Cilindro (roxo PhysGame)
    final barrel = Rect.fromLTRB(614, 430, 658, 554);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barrel, const Radius.circular(6)),
      Paint()
        ..shader = _hGrad(
          barrel,
          const [Color(0xFF4A38C9), Color(0xFF8277F5), Color(0xFF4A38C9)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barrel, const Radius.circular(6)),
      _stroke(const Color(0xFF2E2399), 1.5),
    );

    // Faixa graduada
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(628, 438, 644, 546),
        const Radius.circular(3),
      ),
      _fill(PhysGameColors.metalMid.withOpacity(.92)),
    );
    final tick = _stroke(PhysGameColors.metalEdge, 1.2);
    for (int i = 0; i < 12; i++) {
      final y = 441.0 + i * 9;
      canvas.drawLine(Offset(628, y), Offset(i % 3 == 0 ? 644 : 638, y), tick);
    }

    // Conexão da mangueira
    final fit = RRect.fromRectAndRadius(
      Rect.fromLTRB(607, 508, 616, 532),
      const Radius.circular(2),
    );
    canvas.drawRRect(fit, _fill(PhysGameColors.metalDark));
    canvas.drawRRect(fit, _stroke(PhysGameColors.metalEdge, 1));

    // Haste + puxador (descem com pumpOffset)
    final hy = StageGeometry.pumpHandleRestY + view.pumpOffset;
    canvas.drawRect(
      Rect.fromLTRB(633, hy + 12, 639, 432),
      _fill(PhysGameColors.metalDark),
    );

    final handle = Rect.fromLTRB(596, hy, 676, hy + 14);
    final handleR = RRect.fromRectAndRadius(handle, const Radius.circular(7));
    canvas.drawRRect(
      handleR,
      Paint()
        ..shader = _vGrad(
          handle,
          const [PhysGameColors.metalLight, PhysGameColors.metalDark],
        ),
    );
    canvas.drawRRect(handleR, _stroke(PhysGameColors.metalEdge, 1.5));
    final groove = _stroke(PhysGameColors.metalEdge, 1.5, cap: StrokeCap.round);
    for (int i = 0; i < 7; i++) {
      final gx = 606.0 + i * 11;
      canvas.drawLine(Offset(gx, hy + 3), Offset(gx, hy + 11), groove);
    }
  }

  // ── Balde aquecedor / resfriador ───────────────────────────────────
  void _paintBucket(Canvas canvas) {
    final body = Path()
      ..moveTo(165, 514)
      ..lineTo(305, 514)
      ..lineTo(291, 590)
      ..lineTo(179, 590)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = _hGrad(
          const Rect.fromLTRB(165, 514, 305, 590),
          const [
            PhysGameColors.metalDark,
            PhysGameColors.metalLight,
            PhysGameColors.metalDark,
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
    canvas.drawPath(body, _stroke(PhysGameColors.metalEdge, 1.5));

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(235, 514), width: 140, height: 18),
      _fill(const Color(0xFFE4E7EC)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(235, 514), width: 140, height: 18),
      _stroke(PhysGameColors.metalDark, 1),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(235, 515), width: 128, height: 12),
      _fill(PhysGameColors.slate),
    );

    // Trilho: laranja (aquecer) em cima, azul (arrefecer) embaixo.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(229, 526, 241, 554),
        const Radius.circular(6),
      ),
      _fill(PhysGameColors.heatColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(229, 552, 241, 580),
        const Radius.circular(6),
      ),
      _fill(PhysGameColors.coolColor),
    );

    _drawText(
      canvas,
      'Aquecer',
      const Offset(222, 536),
      size: 10,
      color: PhysGameColors.navy,
      align: TextAlign.right,
    );
    _drawText(
      canvas,
      'Arrefecer',
      const Offset(222, 581),
      size: 10,
      color: PhysGameColors.navy,
      align: TextAlign.right,
    );

    // Manopla (sobe ao aquecer, desce ao arrefecer)
    final ky = StageGeometry.bucketKnobCenterY -
        engine.heaterLevel * StageGeometry.bucketKnobTravel;
    final knob = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(235, ky), width: 52, height: 16),
      const Radius.circular(6),
    );
    canvas.drawRRect(knob, _fill(PhysGameColors.knob));
    canvas.drawRRect(knob, _stroke(PhysGameColors.knobEdge, 1.5));
    canvas.drawLine(
      Offset(217, ky),
      Offset(253, ky),
      _stroke(PhysGameColors.knobEdge, 1.5),
    );
  }

  // ── Controles inferiores ───────────────────────────────────────────
  void _paintBottomControls(Canvas canvas) {
    // Play / pausa
    const pc = StageGeometry.playCenter;
    const pr = StageGeometry.playRadius;
    final playRect = Rect.fromCircle(center: pc, radius: pr);
    canvas.drawCircle(
      pc,
      pr,
      Paint()
        ..shader = _vGrad(
          playRect,
          const [PhysGameColors.purple2, PhysGameColors.purple],
        ),
    );
    canvas.drawCircle(pc, pr, _stroke(Colors.white, 3));

    if (engine.paused) {
      final tri = Path()
        ..moveTo(pc.dx - 7, pc.dy - 12)
        ..lineTo(pc.dx + 13, pc.dy)
        ..lineTo(pc.dx - 7, pc.dy + 12)
        ..close();
      canvas.drawPath(tri, _fill(Colors.white));
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pc.dx - 9, pc.dy - 11, 7, 22),
          const Radius.circular(2),
        ),
        _fill(Colors.white),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pc.dx + 3, pc.dy - 11, 7, 22),
          const Radius.circular(2),
        ),
        _fill(Colors.white),
      );
    }

    // Passo
    const sc = StageGeometry.stepCenter;
    canvas.drawCircle(sc, StageGeometry.stepRadius, _fill(PhysGameColors.metalMid));
    canvas.drawCircle(sc, StageGeometry.stepRadius, _stroke(Colors.white, 2));
    final stepTri = Path()
      ..moveTo(sc.dx - 7, sc.dy - 8)
      ..lineTo(sc.dx - 7, sc.dy + 8)
      ..lineTo(sc.dx + 4, sc.dy)
      ..close();
    canvas.drawPath(stepTri, _fill(PhysGameColors.navy));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sc.dx + 6, sc.dy - 8, 3.5, 16),
        const Radius.circular(1),
      ),
      _fill(PhysGameColors.navy),
    );

    // Borracha (esvazia a câmara)
    final er = RRect.fromRectAndRadius(
      StageGeometry.eraser,
      const Radius.circular(6),
    );
    canvas.drawRRect(er, _fill(const Color(0xFFE4E7EC)));
    canvas.drawRRect(er, _stroke(PhysGameColors.metalDark, 1));
    final eraserShape = Path()
      ..moveTo(332, 572)
      ..lineTo(346, 556)
      ..lineTo(354, 562)
      ..lineTo(340, 576)
      ..close();
    canvas.drawPath(eraserShape, _fill(PhysGameColors.metalLight));
    canvas.drawPath(
      eraserShape,
      _stroke(PhysGameColors.slate, 1.5, join: StrokeJoin.round),
    );
    canvas.drawLine(
      const Offset(340, 576),
      const Offset(352, 576),
      _stroke(PhysGameColors.slate, 1.5, cap: StrokeCap.round),
    );

    // Seletor da espécie injetada pela bomba
    _paintSpeciesButton(
      canvas,
      StageGeometry.lightButton,
      PhysGameColors.lightParticle,
      GasEngine.lightRadius * StageGeometry.chamberW * 1.4,
      view.pumpSpecies == ParticleSpecies.light,
    );
    _paintSpeciesButton(
      canvas,
      StageGeometry.heavyButton,
      PhysGameColors.heavyParticle,
      GasEngine.heavyRadius * StageGeometry.chamberW * 1.4,
      view.pumpSpecies == ParticleSpecies.heavy,
    );

    // Reiniciar
    const rc = StageGeometry.resetCenter;
    const rr = StageGeometry.resetRadius;
    canvas.drawCircle(rc, rr, _fill(PhysGameColors.orange));
    canvas.drawCircle(rc, rr, _stroke(Colors.white, 3));

    const startAngle = -math.pi / 6;
    const sweep = -math.pi * 1.6;
    canvas.drawArc(
      Rect.fromCircle(center: rc, radius: 12),
      startAngle,
      sweep,
      false,
      _stroke(Colors.white, 3.5, cap: StrokeCap.round),
    );

    // Ponta da seta no fim do arco (sentido anti-horário).
    const endAngle = startAngle + sweep;
    final ca = math.cos(endAngle);
    final sa = math.sin(endAngle);
    final p = Offset(rc.dx + 12 * ca, rc.dy + 12 * sa);
    final tangent = Offset(sa, -ca);
    final normal = Offset(ca, sa);
    final head = Path()
      ..moveTo(p.dx + tangent.dx * 8, p.dy + tangent.dy * 8)
      ..lineTo(p.dx + normal.dx * 6.5, p.dy + normal.dy * 6.5)
      ..lineTo(p.dx - normal.dx * 6.5, p.dy - normal.dy * 6.5)
      ..close();
    canvas.drawPath(head, _fill(Colors.white));
  }

  void _paintSpeciesButton(
    Canvas canvas,
    Rect rect,
    Color color,
    double radius,
    bool selected,
  ) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rr, _fill(PhysGameColors.gasTop));
    canvas.drawRRect(
      rr,
      _stroke(
        selected ? PhysGameColors.purple2 : PhysGameColors.panelBorder,
        selected ? 3 : 2,
      ),
    );
    _drawSphere(canvas, rect.center, radius, _spherePaint(color, radius));
  }

  // ── Cronômetro ─────────────────────────────────────────────────────
  void _paintStopwatch(Canvas canvas) {
    final box = RRect.fromRectAndRadius(
      StageGeometry.stopwatch,
      const Radius.circular(10),
    );
    canvas.drawRRect(box, _fill(const Color(0xFF1E1B4B)));
    canvas.drawRRect(box, _stroke(PhysGameColors.purple2, 1.5));

    final r = StageGeometry.stopwatch;
    _drawText(
      canvas,
      'CRONÔMETRO',
      Offset(r.left + 14, r.top + 19),
      size: 11,
      color: const Color(0xFFC7C0FF),
    );
    _drawText(
      canvas,
      '${_comma(view.stopwatchSeconds(engine), 2)} s',
      Offset(r.left + 14, r.top + 41),
      size: 22,
      weight: FontWeight.w800,
    );

    // ▶ / ❚❚
    canvas.drawCircle(StageGeometry.stopwatchPlay, 13, _fill(PhysGameColors.purple2));
    final c = StageGeometry.stopwatchPlay;
    if (view.stopwatchRunning) {
      canvas.drawRect(Rect.fromLTWH(c.dx - 5, c.dy - 6, 3.5, 12), _fill(Colors.white));
      canvas.drawRect(Rect.fromLTWH(c.dx + 1.5, c.dy - 6, 3.5, 12), _fill(Colors.white));
    } else {
      final tri = Path()
        ..moveTo(c.dx - 4, c.dy - 7)
        ..lineTo(c.dx + 6, c.dy)
        ..lineTo(c.dx - 4, c.dy + 7)
        ..close();
      canvas.drawPath(tri, _fill(Colors.white));
    }

    // ↺
    final rc = StageGeometry.stopwatchReset;
    canvas.drawCircle(rc, 13, _fill(PhysGameColors.metalMid));
    canvas.drawArc(
      Rect.fromCircle(center: rc, radius: 6),
      -math.pi / 4,
      -math.pi * 1.5,
      false,
      _stroke(PhysGameColors.navy, 2, cap: StrokeCap.round),
    );
  }

  // ── Contador de colisões ───────────────────────────────────────────
  void _paintCollisionCounter(Canvas canvas) {
    final r = StageGeometry.collisionCounter;
    final box = RRect.fromRectAndRadius(r, const Radius.circular(10));
    canvas.drawRRect(box, _fill(const Color(0xFF3A2A08)));
    canvas.drawRRect(box, _stroke(PhysGameColors.amber, 1.5));

    _drawText(
      canvas,
      'COLISÕES COM A PAREDE',
      Offset(r.left + 14, r.top + 19),
      size: 11,
      color: const Color(0xFFFDE68A),
    );
    _drawText(
      canvas,
      formatThousands(view.collisions(engine)),
      Offset(r.left + 14, r.top + 41),
      size: 22,
      weight: FontWeight.w800,
    );
    _drawText(
      canvas,
      '${engine.collisionRate.round()}/s',
      Offset(r.right - 14, r.top + 41),
      size: 14,
      color: const Color(0xFFFDE68A),
      align: TextAlign.right,
    );
  }

  @override
  bool shouldRepaint(covariant LabStagePainter oldDelegate) => true;
}
