import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/physgame_theme.dart';
import '../../simulation/gas_engine.dart';
import '../../simulation/gas_particle.dart';
import 'lab_painters.dart';

enum _Drag { none, lid, heater, pump }

/// Elementos do palco que têm uma dica explicativa (pop-up).
enum _Hint {
  lid,
  heater,
  pump,
  gauge,
  pressureReadout,
  thermometer,
  temperatureReadout,
  play,
  step,
  eraser,
  lightButton,
  heavyButton,
  reset,
  stopwatch,
  collisions,
}

/// Palco interativo: câmara com tampa arrastável, termômetro, manômetro,
/// bomba, aquecedor/resfriador e botões de controle.
///
/// Desenha tudo em um espaço lógico fixo de 760 × 600 e escala com FittedBox,
/// então a geometria de desenho e a de toque são sempre as mesmas.
///
/// Ao passar o mouse (ou tocar) em um elemento, aparece um pop-up dizendo
/// o que ele faz e que efeito tem sobre o gás.
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

  _Hint? _hint;
  bool _hovering = false;
  Timer? _hintTimer;

  GasEngine get engine => widget.engine;
  LabViewState get view => widget.view;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

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

  // ── Dicas (pop-ups) ─────────────────────────────────────────────────
  static const Rect _thermometerRect = Rect.fromLTRB(490, 56, 536, 196);

  Rect get _gaugeRect => Rect.fromCircle(
        center: StageGeometry.gaugeCenter,
        radius: StageGeometry.gaugeRadius,
      );

  Rect _circle(Offset center, double radius) =>
      Rect.fromCircle(center: center, radius: radius);

  /// Região de cada elemento, usada para detectar o mouse e ancorar o pop-up.
  Rect _hintRect(_Hint hint) {
    switch (hint) {
      case _Hint.lid:
        return StageGeometry.lidHit(engine);
      case _Hint.heater:
        return StageGeometry.bucket;
      case _Hint.pump:
        return Rect.fromLTRB(
          588,
          StageGeometry.pumpHandleRestY - 6,
          684,
          582,
        );
      case _Hint.gauge:
        return _gaugeRect;
      case _Hint.pressureReadout:
        return StageGeometry.pressureReadout;
      case _Hint.thermometer:
        return _thermometerRect;
      case _Hint.temperatureReadout:
        return StageGeometry.temperatureReadout;
      case _Hint.play:
        return _circle(StageGeometry.playCenter, StageGeometry.playRadius);
      case _Hint.step:
        return _circle(StageGeometry.stepCenter, StageGeometry.stepRadius);
      case _Hint.eraser:
        return StageGeometry.eraser;
      case _Hint.lightButton:
        return StageGeometry.lightButton;
      case _Hint.heavyButton:
        return StageGeometry.heavyButton;
      case _Hint.reset:
        return _circle(StageGeometry.resetCenter, StageGeometry.resetRadius);
      case _Hint.stopwatch:
        return StageGeometry.stopwatch;
      case _Hint.collisions:
        return StageGeometry.collisionCounter;
    }
  }

  String _hintTitle(_Hint hint) {
    switch (hint) {
      case _Hint.lid:
        return 'Tampa móvel';
      case _Hint.heater:
        return 'Aquecedor e resfriador';
      case _Hint.pump:
        return 'Bomba de gás';
      case _Hint.gauge:
        return 'Manômetro';
      case _Hint.pressureReadout:
        return 'Leitura de pressão';
      case _Hint.thermometer:
        return 'Termômetro';
      case _Hint.temperatureReadout:
        return 'Leitura de temperatura';
      case _Hint.play:
        return engine.paused ? 'Continuar' : 'Pausar';
      case _Hint.step:
        return 'Avançar um passo';
      case _Hint.eraser:
        return 'Esvaziar a câmara';
      case _Hint.lightButton:
        return 'Partículas leves';
      case _Hint.heavyButton:
        return 'Partículas pesadas';
      case _Hint.reset:
        return 'Reiniciar';
      case _Hint.stopwatch:
        return 'Cronômetro';
      case _Hint.collisions:
        return 'Contador de colisões';
    }
  }

  String _hintText(_Hint hint) {
    switch (hint) {
      case _Hint.lid:
        if (!engine.volumeEditable) {
          return 'A tampa está travada pela opção escolhida em "Manter constante". '
              'Escolha outra opção para poder movê-la.';
        }
        return 'Se você mover a tampa, cria uma variação de pressão: '
            'descer comprime o gás e a pressão sobe; subir expande o gás e a pressão cai.';
      case _Hint.heater:
        if (!engine.temperatureEditable) {
          return 'A temperatura está travada pela opção escolhida em "Manter constante".';
        }
        return 'Se você arrastar para cima, aquece o gás: as partículas ficam mais rápidas '
            'e a pressão sobe. Para baixo, resfria e a pressão cai.';
      case _Hint.pump:
        return 'Se você empurrar a bomba para baixo, injeta mais partículas. '
            'Mais partículas batem mais vezes nas paredes, e a pressão sobe.';
      case _Hint.gauge:
        return 'Mede a pressão do gás, que vem das colisões das partículas com as paredes. '
            'O ponteiro oscila um pouco porque as colisões são aleatórias.';
      case _Hint.pressureReadout:
        return 'Clique para trocar a unidade: kPa, atm, mmHg, kgf/cm², bar ou psi.';
      case _Hint.thermometer:
        return 'Mede a temperatura, que é a energia de movimento média das partículas. '
            'Quanto mais rápidas, mais quente.';
      case _Hint.temperatureReadout:
        return 'Clique para trocar a unidade: K, °C ou °F.';
      case _Hint.play:
        return 'Pausa ou continua o movimento das partículas.';
      case _Hint.step:
        return 'Com a simulação pausada, avança um instante de cada vez para observar as colisões.';
      case _Hint.eraser:
        return 'Remove todas as partículas. Sem gás, a pressão vai a zero.';
      case _Hint.lightButton:
        return 'Escolhe partículas leves para a bomba injetar. Na mesma temperatura, elas são mais rápidas.';
      case _Hint.heavyButton:
        return 'Escolhe partículas pesadas para a bomba injetar. Na mesma temperatura, elas são mais lentas.';
      case _Hint.reset:
        return 'Volta o experimento ao estado inicial.';
      case _Hint.stopwatch:
        return 'Mede o tempo da simulação. Use os botões para iniciar, pausar e zerar.';
      case _Hint.collisions:
        return 'Conta as colisões das partículas com as paredes. Clique para zerar a contagem.';
    }
  }

  /// Elemento sob o ponto [p], respeitando a ordem de quem está por cima.
  _Hint? _hintAt(Offset p) {
    const order = [
      _Hint.pressureReadout,
      _Hint.temperatureReadout,
      _Hint.play,
      _Hint.step,
      _Hint.eraser,
      _Hint.lightButton,
      _Hint.heavyButton,
      _Hint.reset,
      _Hint.heater,
      _Hint.gauge,
      _Hint.thermometer,
      _Hint.pump,
      _Hint.lid,
    ];

    if (view.showStopwatch && StageGeometry.stopwatch.contains(p)) {
      return _Hint.stopwatch;
    }
    if (view.showCollisions && StageGeometry.collisionCounter.contains(p)) {
      return _Hint.collisions;
    }

    for (final hint in order) {
      if (_hintRect(hint).contains(p)) return hint;
    }
    return null;
  }

  void _setHint(_Hint? hint) {
    if (hint == _hint) return;
    setState(() => _hint = hint);
  }

  /// Toque (sem mouse): mostra a dica por alguns segundos.
  void _flashHint(Offset p) {
    final hint = _hintAt(p);
    if (hint == null) return;

    _setHint(hint);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_hovering && _drag == _Drag.none) _setHint(null);
    });
  }

  // ── Arrastar ────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    final p = d.localPosition;
    _flashHint(p);

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
        // Cada litro ocupa GasEngine.heightPerL da altura da câmara.
        // O arrasto move o ALVO da tampa, que a segue com velocidade finita.
        final dV =
            -d.delta.dy / (StageGeometry.chamberH * GasEngine.heightPerL);
        engine.setVolume(engine.targetVolumeL + dV);
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

    // No toque não há "sair com o mouse": a dica some pouco depois de soltar.
    if (!_hovering && _hint != null) {
      _hintTimer?.cancel();
      _hintTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && !_hovering && _drag == _Drag.none) _setHint(null);
      });
    }

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
    if (!_hovering) _flashHint(p);

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

  // ── Pop-up ──────────────────────────────────────────────────────────
  static const double _bubbleWidth = 250;

  Widget _hintBubble(_Hint hint) {
    final rect = _hintRect(hint);

    final left = (rect.center.dx - _bubbleWidth / 2)
        .clamp(8.0, StageGeometry.width - _bubbleWidth - 8)
        .toDouble();

    // Acima do elemento quando há espaço; senão, abaixo.
    final above = rect.top > 150;

    return Positioned(
      left: left,
      width: _bubbleWidth,
      top: above ? null : math.min(rect.bottom + 10, StageGeometry.height - 120),
      bottom: above ? StageGeometry.height - rect.top + 10 : null,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
          decoration: BoxDecoration(
            color: PhysGameColors.surfaceHi,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PhysGameColors.purple2, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    size: 15,
                    color: PhysGameColors.amber,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _hintTitle(hint),
                      style: const TextStyle(
                        color: PhysGameColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _hintText(hint),
                style: const TextStyle(
                  color: PhysGameColors.muted,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hint = _hint;

    return AspectRatio(
      aspectRatio: StageGeometry.width / StageGeometry.height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: StageGeometry.width,
          height: StageGeometry.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (e) {
                    _hovering = true;
                    _setHint(_hintAt(e.localPosition));
                  },
                  onExit: (_) {
                    _hovering = false;
                    if (_drag == _Drag.none) _setHint(null);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: (_) => _onPanEnd(),
                    onPanCancel: _onPanEnd,
                    onTapUp: _onTapUp,
                    child: CustomPaint(
                      painter: LabStagePainter(engine, view),
                      size:
                          const Size(StageGeometry.width, StageGeometry.height),
                    ),
                  ),
                ),
              ),
              if (hint != null) _hintBubble(hint),
            ],
          ),
        ),
      ),
    );
  }
}
