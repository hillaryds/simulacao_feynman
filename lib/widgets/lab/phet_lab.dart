import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/physgame_theme.dart';
import '../../simulation/gas_engine.dart';
import '../../simulation/gas_particle.dart';
import 'lab_painters.dart';
import 'lab_stage.dart';

/// Laboratório completo no estilo PhET "Propriedades dos Gases":
/// palco à esquerda e painéis escuros à direita (abaixo em telas estreitas).
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
  static const int _maxParticles = 150;

  final LabViewState view = LabViewState();

  GasEngine get engine => widget.engine;

  void _changed() => widget.onChanged();

  void _reset() {
    widget.onReset();
    view.resetTools();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;

        final stage = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PhysGameColors.stage,
            borderRadius: BorderRadius.circular(24),
          ),
          child: LabStage(
            engine: engine,
            view: view,
            onChanged: _changed,
            onReset: _reset,
          ),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: stage),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: _panels()),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stage,
            const SizedBox(height: 16),
            _panels(),
          ],
        );
      },
    );
  }

  // ── Painéis laterais ────────────────────────────────────────────────
  Widget _panels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _particlesPanel(),
        const SizedBox(height: 14),
        _constantPanel(),
        const SizedBox(height: 14),
        _toolsPanel(),
        const SizedBox(height: 14),
        _finePanel(),
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhysGameColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PhysGameColors.panelBorder),
      ),
      child: child,
    );
  }

  static const TextStyle _title = TextStyle(
    color: Colors.white,
    fontSize: 19,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle _label = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  Widget _collapseButton(bool open, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: open ? 'Recolher painel' : 'Expandir painel',
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: PhysGameColors.orange,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            open ? Icons.remove : Icons.add,
            size: 16,
            color: Colors.white,
          ),
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
          Row(
            children: [
              _collapseButton(view.particlesPanelOpen, () {
                view.particlesPanelOpen = !view.particlesPanelOpen;
                _changed();
              }),
              const SizedBox(width: 12),
              const Text('Partículas', style: _title),
            ],
          ),
          if (view.particlesPanelOpen) ...[
            const SizedBox(height: 14),
            _speciesBlock(
              color: PhysGameColors.lightParticle,
              label: 'Leve',
              species: ParticleSpecies.light,
              count: engine.lightCount,
            ),
            const SizedBox(height: 14),
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
      _changed();
    }

    void remove(int n) {
      engine.removeParticles(species, n);
      _changed();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: _label.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _stepButton(Icons.arrow_left, 'Remover 1', () => remove(1)),
            const SizedBox(width: 5),
            _stepButton(Icons.fast_rewind, 'Remover 5', () => remove(5)),
            const SizedBox(width: 5),
            Expanded(
              child: Container(
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: PhysGameColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            _stepButton(Icons.fast_forward, 'Adicionar 5', () => add(5)),
            const SizedBox(width: 5),
            _stepButton(Icons.arrow_right, 'Adicionar 1', () => add(1)),
          ],
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PhysGameColors.metalMid,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 28,
            child: Icon(icon, size: 20, color: PhysGameColors.navy),
          ),
        ),
      ),
    );
  }

  // ── Manter constante ────────────────────────────────────────────────
  Widget _constantPanel() {
    final hasGas = engine.totalCount > 0;

    Widget radio(String text, ConstantMode mode, {bool enabled = true}) {
      final selected = engine.constantMode == mode;
      final fg = enabled ? Colors.white : PhysGameColors.metalDark;

      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled
            ? () {
                engine.setConstantMode(mode);
                _changed();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? PhysGameColors.purple2 : Colors.transparent,
                  border: Border.all(
                    color: enabled ? Colors.white : PhysGameColors.metalEdge,
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(text, style: _label.copyWith(color: fg)),
            ],
          ),
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Manter constante', style: _title),
          const SizedBox(height: 8),
          radio('Nada', ConstantMode.none),
          radio('Volume (V)', ConstantMode.volume),
          radio('Temperatura (T)', ConstantMode.temperature, enabled: hasGas),
          radio('Pressão ↕V', ConstantMode.pressure, enabled: hasGas),
          radio('Pressão ↕T', ConstantMode.pressureT, enabled: hasGas),
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
      required Widget trailing,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: value
                    ? const Icon(Icons.check, size: 17, color: PhysGameColors.navy)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: _label.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing,
            ],
          ),
        ),
      );
    }

    Widget swatch(Color fill, Color edge) => Container(
          width: 36,
          height: 20,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: edge, width: 1.5),
          ),
        );

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          check(
            text: 'Régua de volume',
            value: view.showRuler,
            onChanged: (v) {
              view.showRuler = v;
              _changed();
            },
            trailing: const Icon(
              Icons.height,
              size: 22,
              color: PhysGameColors.amber,
            ),
          ),
          check(
            text: 'Cronômetro',
            value: view.showStopwatch,
            onChanged: (v) {
              view.showStopwatch = v;
              _changed();
            },
            trailing: swatch(PhysGameColors.purple2, const Color(0xFFC7C0FF)),
          ),
          check(
            text: 'Contador de colisões',
            value: view.showCollisions,
            onChanged: (v) {
              view.showCollisions = v;
              _changed();
            },
            trailing: swatch(PhysGameColors.amber, const Color(0xFFFDE68A)),
          ),
        ],
      ),
    );
  }

  // ── Ajuste fino (sliders originais do protótipo) ────────────────────
  Widget _finePanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _collapseButton(view.finePanelOpen, () {
                view.finePanelOpen = !view.finePanelOpen;
                _changed();
              }),
              const SizedBox(width: 12),
              const Text('Ajuste fino', style: _title),
            ],
          ),
          if (view.finePanelOpen) ...[
            const SizedBox(height: 8),
            _slider(
              title: 'Volume',
              valueText: '${engine.volumeL.toStringAsFixed(2)} L',
              value: engine.volumeL,
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
      opacity: enabled ? 1 : .5,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: _label.copyWith(fontSize: 14)),
              ),
              Text(
                valueText,
                style: _label.copyWith(
                  fontSize: 14,
                  color: const Color(0xFFC7C0FF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: PhysGameColors.purple2,
              inactiveTrackColor: PhysGameColors.panelBorder,
              thumbColor: Colors.white,
              overlayColor: PhysGameColors.purple2.withOpacity(.2),
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: enabled
                  ? (v) {
                      onChanged(v);
                      _changed();
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
