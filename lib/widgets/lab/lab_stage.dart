import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../simulation/gas_engine.dart';
import '../../simulation/gas_particle.dart';
import 'lab_painters.dart';

enum _Drag { none, lid, heater, pump }

/// Palco interativo: câmara com tampa arrastável, termômetro, manômetro,
/// bomba, aquecedor/resfriador e botões de controle.
///
/// Desenha tudo em um espaço lógico fixo de 760 × 600 e escala com FittedBox,
/// então a geometria de desenho e a de toque são sempre as mesmas.
class LabStage extends StatefulWidget {
  final GasEngine engine;
  final LabViewState view;
  final VoidCallback onChanged;
  final VoidCallback onReset;

  const LabStage({
    super.key,
    required this.engine,
    required this.view,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<LabStage> createState() => _LabStageState();
}

class _LabStageState extends State<LabStage> {
  _Drag _drag = _Drag.none;
  bool _pumpFired = false;

  GasEngine get engine => widget.engine;
  LabViewState get view => widget.view;

  @override
  void didUpdateWidget(covariant LabStage oldWidget) {
    super.didUpdateWidget(oldWidget);

    view.sync(engine);

    // A haste da bomba volta sozinha para cima quando solta.
    if (_drag != _Drag.pump && view.pumpOffset > 0) {
      view.pumpOffset = math.max(0.0, view.pumpOffset - 2.5);
    }
  }

  void _changed() {
    widget.onChanged();
  }

  // ── Arrastar ────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    final p = d.localPosition;

    if (StageGeometry.bucket.contains(p)) {
      _drag = _Drag.heater;
      _setHeater(p.dy);
    } else if (StageGeometry.pumpHandleHit(view.pumpOffset).contains(p)) {
      _drag = _Drag.pump;
    } else if (StageGeometry.lidHit(engine).contains(p)) {
      _drag = _Drag.lid;
    } else {
      _drag = _Drag.none;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    switch (_drag) {
      case _Drag.lid:
        // 4 L correspondem a 0,56 da altura da câmara.
        final dV = -d.delta.dy / (StageGeometry.chamberH * 0.56) * 4.0;
        engine.setVolume(engine.volumeL + dV);
        _changed();
        break;

      case _Drag.heater:
        _setHeater(d.localPosition.dy);
        break;

      case _Drag.pump:
        view.pumpOffset = (view.pumpOffset + d.delta.dy)
            .clamp(0.0, StageGeometry.pumpTravel)
            .toDouble();

        if (view.pumpOffset >= StageGeometry.pumpTravel - 0.5 && !_pumpFired) {
          _pumpFired = true;
          if (engine.totalCount < _maxParticles) {
            engine.addParticles(view.pumpSpecies, 4);
          }
        } else if (view.pumpOffset < 10) {
          _pumpFired = false;
        }
        _changed();
        break;

      case _Drag.none:
        break;
    }
  }

  void _onPanEnd() {
    if (_drag == _Drag.heater) {
      engine.heaterLevel = 0;
    }
    _drag = _Drag.none;
    _pumpFired = false;
    _changed();
  }

  void _setHeater(double localY) {
    final level = (StageGeometry.bucketKnobCenterY - localY) /
        StageGeometry.bucketKnobTravel;
    engine.heaterLevel = level.clamp(-1.0, 1.0).toDouble();
    _changed();
  }

  static const int _maxParticles = 150;

  // ── Toques ──────────────────────────────────────────────────────────
  void _onTapUp(TapUpDetails d) {
    final p = d.localPosition;

    if ((p - StageGeometry.playCenter).distance <= StageGeometry.playRadius) {
      engine.paused = !engine.paused;
    } else if ((p - StageGeometry.stepCenter).distance <=
        StageGeometry.stepRadius) {
      engine.step();
    } else if (StageGeometry.eraser.contains(p)) {
      engine.clearParticles();
    } else if (StageGeometry.lightButton.contains(p)) {
      view.pumpSpecies = ParticleSpecies.light;
    } else if (StageGeometry.heavyButton.contains(p)) {
      view.pumpSpecies = ParticleSpecies.heavy;
    } else if ((p - StageGeometry.resetCenter).distance <=
        StageGeometry.resetRadius) {
      widget.onReset();
      return;
    } else if (StageGeometry.temperatureReadout.contains(p)) {
      _pickUnit<TemperatureUnit>(
        d.globalPosition,
        TemperatureUnit.values,
        temperatureUnitLabel,
        (u) => view.temperatureUnit = u,
      );
      return;
    } else if (StageGeometry.pressureReadout.contains(p)) {
      _pickUnit<PressureUnit>(
        d.globalPosition,
        PressureUnit.values,
        pressureUnitLabel,
        (u) => view.pressureUnit = u,
      );
      return;
    } else if (view.showStopwatch &&
        (p - StageGeometry.stopwatchPlay).distance <= 14) {
      view.toggleStopwatch(engine);
    } else if (view.showStopwatch &&
        (p - StageGeometry.stopwatchReset).distance <= 14) {
      view.resetStopwatch(engine);
    } else if (view.showCollisions &&
        StageGeometry.collisionCounter.contains(p)) {
      view.resetCollisions(engine);
    } else {
      return;
    }

    _changed();
  }

  Future<void> _pickUnit<T>(
    Offset global,
    List<T> values,
    String Function(T) label,
    ValueChanged<T> onPick,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final picked = await showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(global.dx, global.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final v in values)
          PopupMenuItem<T>(value: v, child: Text(label(v))),
      ],
    );

    if (picked != null) {
      onPick(picked);
      _changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: StageGeometry.width / StageGeometry.height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: StageGeometry.width,
          height: StageGeometry.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: _onPanEnd,
            onTapUp: _onTapUp,
            child: CustomPaint(
              painter: LabStagePainter(engine, view),
              size: const Size(StageGeometry.width, StageGeometry.height),
            ),
          ),
        ),
      ),
    );
  }
}
