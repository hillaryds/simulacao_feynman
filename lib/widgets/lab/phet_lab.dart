import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/physgame_theme.dart';
import '../../simulation/gas_engine.dart';
import '../../simulation/gas_particle.dart';
import 'lab_painters.dart';
import 'lab_stage.dart';

/// Moldura do palco: a câmara dentro de um cartão que mantém a proporção
/// do desenho e ocupa o maior espaço disponível.
class LabStageCard extends StatelessWidget {
  final GasEngine engine;
  final LabViewState view;
  final VoidCallback onChanged;
  final VoidCallback onReset;

  const LabStageCard({
    super.key,
    required this.engine,
    required this.view,
    required this.onChanged,
    required this.onReset,
  });

  static const double _padding = 12;

  /// Proporção do cartão inteiro (palco + margem interna).
  static const double aspectRatio = (StageGeometry.width + 2 * _padding) /
      (StageGeometry.height + 2 * _padding);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        padding: EdgeInsets.all(_padding),
        decoration: BoxDecoration(
          color: PhysGameColors.stage,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PhysGameColors.line),
        ),
        child: LabStage(
          engine: engine,
          view: view,
          onChanged: onChanged,
          onReset: onReset,
        ),
      ),
    );
  }
}

/// Painéis de controle do laboratório: partículas, variável constante,
/// ferramentas de medida e ajuste fino.
class LabPanels extends StatelessWidget {
  final GasEngine engine;
  final LabViewState view;
  final VoidCallback onChanged;

  const LabPanels({
    super.key,
    required this.engine,
    required this.view,
    required this.onChanged,
  });

  static const int _maxParticles = 150;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _particlesPanel(),
        SizedBox(height: 12),
        _constantPanel(),
        SizedBox(height: 12),
        _toolsPanel(),
        SizedBox(height: 12),
        _finePanel(context),
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhysGameColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhysGameColors.line),
      ),
      child: child,
    );
  }

  static TextStyle get _label => TextStyle(
        color: PhysGameColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  Widget _header(
    IconData icon,
    String title, {
    bool? open,
    VoidCallback? onToggle,
  }) {
    final row = Row(
      children: [
        Icon(icon, size: 18, color: PhysGameColors.accentText),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: PhysGameColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (open != null)
          Icon(
            open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 22,
            color: PhysGameColors.muted,
          ),
      ],
    );

    if (onToggle == null) return row;

    return Semantics(
      button: true,
      label: open == true ? 'Recolher painel' : 'Expandir painel',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: row,
        ),
      ),
    );
  }

  // ── Partículas ──────────────────────────────────────────────────────
  Widget _particlesPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            Icons.bubble_chart_rounded,
            'Partículas',
            open: view.particlesPanelOpen,
            onToggle: () {
              view.particlesPanelOpen = !view.particlesPanelOpen;
              onChanged();
            },
          ),
          if (view.particlesPanelOpen) ...[
            SizedBox(height: 14),
            _speciesBlock(
              color: PhysGameColors.lightParticle,
              label: 'Leve',
              species: ParticleSpecies.light,
              count: engine.lightCount,
            ),
            SizedBox(height: 12),
            _speciesBlock(
              color: PhysGameColors.heavyParticle,
              label: 'Pesada',
              species: ParticleSpecies.heavy,
              count: engine.heavyCount,
            ),
          ],
        ],
      ),
    );
  }

  Widget _speciesBlock({
    required Color color,
    required String label,
    required ParticleSpecies species,
    required int count,
  }) {
    void add(int n) {
      final room = math.max(0, _maxParticles - engine.totalCount);
      engine.addParticles(species, math.min(n, room));
      onChanged();
    }

    void remove(int n) {
      engine.removeParticles(species, n);
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 8),
            Text(label, style: _label),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _stepButton('−5', 'Remover 5', () => remove(5)),
            SizedBox(width: 6),
            _stepButton('−1', 'Remover 1', () => remove(1)),
            SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PhysGameColors.bg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: color.withValues(alpha: .6)),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: PhysGameColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            SizedBox(width: 6),
            _stepButton('+1', 'Adicionar 1', () => add(1)),
            SizedBox(width: 6),
            _stepButton('+5', 'Adicionar 5', () => add(5)),
          ],
        ),
      ],
    );
  }

  Widget _stepButton(String text, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PhysGameColors.surfaceHi,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 34,
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: PhysGameColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Manter constante ────────────────────────────────────────────────
  Widget _constantPanel() {
    final hasGas = engine.totalCount > 0;

    Widget radio(
      String text,
      String hint,
      ConstantMode mode, {
      bool enabled = true,
    }) {
      final selected = engine.constantMode == mode;

      return Padding(
        padding: EdgeInsets.only(top: 6),
        child: Opacity(
          opacity: enabled ? 1 : .4,
          child: Material(
            color: selected
                ? PhysGameColors.purple2.withValues(alpha: .16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled
                  ? () {
                      engine.setConstantMode(mode);
                      onChanged();
                    }
                  : null,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        selected ? PhysGameColors.purple2 : PhysGameColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? PhysGameColors.purple2
                              : PhysGameColors.muted,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: PhysGameColors.purple2,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: _label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      hint,
                      style: TextStyle(
                        color: PhysGameColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(Icons.lock_outline_rounded, 'Manter constante'),
          SizedBox(height: 6),
          radio('Nada', 'livre', ConstantMode.none),
          radio('Volume (V)', 'tampa fixa', ConstantMode.volume),
          radio(
            'Temperatura (T)',
            'termostato',
            ConstantMode.temperature,
            enabled: hasGas,
          ),
          radio(
            'Pressão',
            'V varia',
            ConstantMode.pressure,
            enabled: hasGas,
          ),
          radio(
            'Pressão',
            'T varia',
            ConstantMode.pressureT,
            enabled: hasGas,
          ),
        ],
      ),
    );
  }

  // ── Régua / cronômetro / contador ───────────────────────────────────
  Widget _toolsPanel() {
    Widget check({
      required String text,
      required bool value,
      required ValueChanged<bool> onChanged,
      required Color color,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: value ? color : PhysGameColors.muted,
                    width: 2,
                  ),
                ),
                child: value
                    ? Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: PhysGameColors.navy,
                      )
                    : null,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: _label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(Icons.straighten_rounded, 'Ferramentas'),
          SizedBox(height: 6),
          check(
            text: 'Régua de volume',
            value: view.showRuler,
            color: PhysGameColors.amber,
            onChanged: (v) {
              view.showRuler = v;
              onChanged();
            },
          ),
          check(
            text: 'Cronômetro',
            value: view.showStopwatch,
            color: PhysGameColors.accentText,
            onChanged: (v) {
              view.showStopwatch = v;
              onChanged();
            },
          ),
          check(
            text: 'Contador de colisões',
            value: view.showCollisions,
            color: PhysGameColors.amber,
            onChanged: (v) {
              view.showCollisions = v;
              onChanged();
            },
          ),
        ],
      ),
    );
  }

  // ── Ajuste fino (sliders originais do protótipo) ────────────────────
  Widget _finePanel(BuildContext context) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            Icons.tune_rounded,
            'Ajuste fino',
            open: view.finePanelOpen,
            onToggle: () {
              view.finePanelOpen = !view.finePanelOpen;
              onChanged();
            },
          ),
          if (view.finePanelOpen) ...[
            SizedBox(height: 12),
            _slider(
              title: 'Volume',
              valueText:
                  '${engine.targetVolumeL.toStringAsFixed(2).replaceAll('.', ',')} L',
              value: engine.targetVolumeL,
              min: 1,
              max: 5,
              enabled: engine.volumeEditable,
              onChanged: engine.setVolume,
            ),
            _slider(
              title: 'Temperatura',
              valueText: '${engine.temperatureK.toStringAsFixed(0)} K',
              value: engine.temperatureK,
              min: GasEngine.minTemperatureK,
              max: GasEngine.maxTemperatureK,
              enabled: engine.temperatureEditable,
              onChanged: engine.setTemperature,
            ),
            _slider(
              title: 'Gravidade',
              valueText: engine.gravity == 0
                  ? '0'
                  : '${(engine.gravity * 100).round()}%',
              value: engine.gravity,
              min: 0,
              max: 1,
              enabled: true,
              onChanged: engine.setGravity,
            ),
          ],
        ],
      ),
    );
  }

  Widget _slider({
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: _label)),
              Text(
                valueText,
                style: _label.copyWith(
                  color: PhysGameColors.accentText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: enabled
                ? (v) {
                    onChanged(v);
                    this.onChanged();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Laboratório completo em um único widget: palco à esquerda e painéis à
/// direita (abaixo em telas estreitas). A tela principal monta as mesmas
/// peças ([LabStageCard] e [LabPanels]) em um layout próprio.
class PhetLab extends StatefulWidget {
  final GasEngine engine;

  /// Chamado sempre que algo muda e a tela precisa redesenhar.
  final VoidCallback onChanged;

  /// Chamado pelo botão laranja de reiniciar.
  final VoidCallback onReset;

  const PhetLab({
    super.key,
    required this.engine,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<PhetLab> createState() => _PhetLabState();
}

class _PhetLabState extends State<PhetLab> {
  final LabViewState view = LabViewState();

  void _reset() {
    widget.onReset();
    view.resetTools();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;

        final stage = LabStageCard(
          engine: widget.engine,
          view: view,
          onChanged: widget.onChanged,
          onReset: _reset,
        );

        final panels = LabPanels(
          engine: widget.engine,
          view: view,
          onChanged: widget.onChanged,
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: stage),
              SizedBox(width: 16),
              SizedBox(width: 320, child: panels),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stage,
            SizedBox(height: 16),
            panels,
          ],
        );
      },
    );
  }
}
