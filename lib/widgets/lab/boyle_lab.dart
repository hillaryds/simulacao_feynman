import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/physgame_theme.dart';
import '../../simulation/boyle_engine.dart';
import 'boyle_painters.dart';
import 'lab_painters.dart';

/// Experimento de Boyle integrado à navegação do PhysGame Lab.
/// Não altera a simulação microscópica existente de Propriedades dos Gases.
class BoyleLab extends StatefulWidget {
  const BoyleLab({super.key});

  @override
  State<BoyleLab> createState() => _BoyleLabState();
}

class _BoyleLabState extends State<BoyleLab>
    with SingleTickerProviderStateMixin {
  final BoyleEngine engine = BoyleEngine();
  late final AnimationController ticker;
  Duration? previousFrame;
  PressureUnit pressureUnit = PressureUnit.mmHg;
  bool analogMode = true;
  bool dragging = false;

  @override
  void initState() {
    super.initState();
    ticker = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_tick)
      ..repeat();
  }

  void _tick() {
    final elapsed = ticker.lastElapsedDuration ?? Duration.zero;
    final dt = previousFrame == null
        ? 1 / 60
        : (elapsed - previousFrame!).inMicroseconds / 1e6;
    previousFrame = elapsed;
    engine.update(dt);
    if (mounted && engine.running) setState(() {});
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  String _n(double value, int digits) =>
      value.toStringAsFixed(digits).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    // Em telas de computador, todos os painéis principais cabem na área
    // disponível, sem rolagem da página e sem zoom do navegador.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1000 && constraints.maxHeight >= 470) {
          return _desktopDashboard();
        }
        return _responsiveBody();
      },
    );
  }

  Widget _responsiveBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: Column(children: [
                _apparatus(),
                const SizedBox(height: 14),
                _chart(),
                const SizedBox(height: 14),
                _table(),
              ])),
              const SizedBox(width: 16),
              SizedBox(width: 330, child: Column(children: [
                _controls(),
                const SizedBox(height: 14),
                _parameters(),
                const SizedBox(height: 14),
                _readings(),
                const SizedBox(height: 14),
                _explanation(),
              ])),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _intro(),
            const SizedBox(height: 12),
            _apparatus(),
            const SizedBox(height: 12),
            if (constraints.maxWidth >= 720)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _controls()),
                  const SizedBox(width: 12),
                  Expanded(child: _parameters()),
                ],
              )
            else ...[
              _controls(),
              const SizedBox(height: 12),
              _parameters(),
            ],
            const SizedBox(height: 12),
            _readings(),
            const SizedBox(height: 12),
            _chart(),
            const SizedBox(height: 12),
            _table(),
            const SizedBox(height: 12),
            _explanation(),
          ],
        );
      }),
    );
  }

  // ── Dashboard compacto para notebook / desktop ───────────────────────
  // Bancada mais ampla e coluna central mais estreita (sem ampliar a página).
  // A soma das alturas e larguras permanece constante: todas as áreas
  // cabem na mesma janela e o FittedBox mantém a escala responsiva.
  Widget _desktopDashboard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 1320,
            height: 662,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bancada: 555 -> 650 (+95). Controles: 372 -> 277 (-95).
                // Total da grade: 650 + 12 + 277 + 12 + 369 = 1320.
                SizedBox(width: 650, child: Column(children: [
                  _dashApparatus(),
                  const SizedBox(height: 12),
                  _dashChart(),
                ])),
                const SizedBox(width: 12),
                SizedBox(width: 277, child: Column(children: [
                  _dashControls(),
                  const SizedBox(height: 12),
                  _dashReadings(),
                ])),
                const SizedBox(width: 12),
                SizedBox(width: 369, child: Column(children: [
                  _dashParameters(),
                  const SizedBox(height: 12),
                  _dashTable(),
                  const SizedBox(height: 12),
                  _dashExplanation(),
                ])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashCard({required double height, required Widget child}) {
    return SizedBox(
      height: height,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: PhysGameColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PhysGameColors.line),
        ),
        child: child,
      ),
    );
  }

  Widget _dashApparatus() => _dashCard(
    height: 450,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(Icons.precision_manufacturing_rounded, 'Bancada experimental • Lei de Boyle'),
      const SizedBox(height: 4),
      Text('Arraste a alça do pistão ou ajuste o volume ao lado.',
        style: TextStyle(color: PhysGameColors.muted, fontSize: 11)),
      const SizedBox(height: 6),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _apparatusCanvas(),
      )),
      const SizedBox(height: 3),
      Text('Partículas ilustrativas • pressão obtida por PV = nRT.',
        style: TextStyle(color: PhysGameColors.muted, fontSize: 10)),
    ]),
  );

  Widget _dashChart() => _dashCard(
    height: 200,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(Icons.show_chart_rounded, 'Pressão absoluta × volume'),
      const SizedBox(height: 7),
      Expanded(child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: PhysGameColors.bg,
          borderRadius: BorderRadius.circular(10)),
        child: BoylePVChart(engine: engine),
      )),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _legend(PhysGameColors.purple2, 'Curva teórica'),
        _legend(PhysGameColors.orange, 'Registros'),
        _legend(PhysGameColors.accentText, 'Atual'),
      ]),
    ]),
  );

  Widget _dashControls() {
    final delta = (engine.initialVolumeMl - engine.minVolumeMl) / 20;
    final ready = (engine.volumeMl - engine.targetVolumeMl).abs() < 0.03;
    final distinct = !engine.readings.any((r) =>
        (r.volumeMl - engine.volumeMl).abs() < 0.04);
    return _dashCard(height: 335, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title(Icons.tune_rounded, 'Controle do experimento'),
        const SizedBox(height: 8),
        SizedBox(height: 35, child: Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: () => setState(() => engine.running
                ? engine.pause() : engine.start()),
            icon: Icon(engine.running ? Icons.pause_rounded
                : Icons.play_arrow_rounded, size: 18),
            label: Text(engine.running ? 'Pausar' : 'Iniciar'),
            style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          )),
          const SizedBox(width: 6),
          IconButton.outlined(
            onPressed: () => setState(engine.resetExperiment),
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reiniciar experimento',
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(minWidth: 35, minHeight: 35),
          ),
        ])),
        const SizedBox(height: 9),
        _valueHeader('Volume de destino', '${_n(engine.targetVolumeMl, 2)} mL'),
        _dashSlider(engine.targetVolumeMl, engine.minVolumeMl,
          engine.initialVolumeMl, 40, (v) {
            engine.setTargetVolume(v);
            engine.start();
          }),
        const SizedBox(height: 3),
        SizedBox(height: 34, child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() {
              engine.changeTargetVolume(-delta); engine.start();
            }),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('−ΔV'),
          )),
          const SizedBox(width: 7),
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() {
              engine.changeTargetVolume(delta); engine.start();
            }),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('+ΔV'),
          )),
        ])),
        const SizedBox(height: 10),
        _valueHeader('Unidade da pressão', 'manométrica'),
        const SizedBox(height: 3),
        Container(height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: PhysGameColors.surfaceHi,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PhysGameColors.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PressureUnit>(
              value: pressureUnit,
              isDense: true,
              isExpanded: true,
              dropdownColor: PhysGameColors.surfaceHi,
              items: PressureUnit.values.map((u) => DropdownMenuItem(
                  value: u, child: Text(pressureUnitLabel(u)))).toList(),
              onChanged: (u) {
                if (u != null) setState(() => pressureUnit = u);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 32, child: Row(children: [
          Expanded(child: _modeButton('Analógico', Icons.speed_rounded, true, compact: true)),
          const SizedBox(width: 6),
          Expanded(child: _modeButton('Digital', Icons.numbers_rounded, false, compact: true)),
        ])),
        const SizedBox(height: 8),
        SizedBox(height: 34, child: FilledButton.tonalIcon(
          onPressed: ready && distinct
              ? () => setState(engine.registerReading) : null,
          icon: const Icon(Icons.add_chart_rounded, size: 18),
          label: const Text('Registrar leitura'),
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        )),
      ],
    ));
  }

  // A coluna central tem altura limitada no dashboard. Evitamos Spacer
  // com conteúdo de altura mínima maior que o espaço disponível.
  Widget _dashReadings() => _dashCard(
    height: 315,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(Icons.monitor_heart_rounded, 'Leituras em tempo real'),
      const SizedBox(height: 8),
      _dashMetricRow('P absoluta', '${_n(engine.absolutePressureKPa, 2)} kPa',
          'P atmosférica', '${_n(engine.atmosphericPressurePa, 0)} Pa'),
      const SizedBox(height: 6),
      _dashMetricRow('P manométrica',
          boyleFormatPressure(math.max(0.0, engine.gaugePressurePa), pressureUnit),
          'Volume', '${_n(engine.volumeMl, 2)} mL'),
      const SizedBox(height: 6),
      _dashMetricRow('Quantidade n', '${engine.moles.toStringAsExponential(3)} mol',
          'P × V', '${_n(engine.pvJ, 4)} J'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: PhysGameColors.purple2.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('P₁V₁ = P₂V₂', style: TextStyle(
              color: PhysGameColors.accentText,
              fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('Variação de PV: ${_n(engine.relativePVErrorPercent, 5)}%',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: PhysGameColors.muted, fontSize: 10.5)),
          Text('Compressão: ${_n(engine.compression * 100, 1)}%',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: PhysGameColors.muted, fontSize: 10.5)),
        ]),
      ),
    ]),
  );

  Widget _dashMetricRow(String firstLabel, String firstValue,
      String secondLabel, String secondValue) => SizedBox(
    height: 50,
    child: Row(children: [
      Expanded(child: _dashMetric(firstLabel, firstValue)),
      const SizedBox(width: 7),
      Expanded(child: _dashMetric(secondLabel, secondValue)),
    ]),
  );

  Widget _dashMetric(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: PhysGameColors.surfaceHi,
      borderRadius: BorderRadius.circular(9)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: PhysGameColors.muted, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: PhysGameColors.text, fontSize: 13,
              fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _dashSlider(double value, double min, double max, int divisions,
      ValueChanged<double> onChanged) => SizedBox(
    height: 24,
    child: SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(
        value: value.clamp(min, max).toDouble(),
        min: min, max: max, divisions: divisions,
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    ),
  );

  Widget _dashParameters() => _dashCard(
    // +15 px para não cortar o botão inferior em algumas fontes/escala.
    height: 250,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(Icons.settings_input_component_rounded, 'Parâmetros iniciais'),
      const SizedBox(height: 4),
      Text('Alterações reiniciam o experimento.',
          style: TextStyle(color: PhysGameColors.muted, fontSize: 10)),
      const SizedBox(height: 9),
      _valueHeader('Volume inicial', '${_n(engine.initialVolumeMl, 1)} mL'),
      _dashSlider(engine.initialVolumeMl, 8, 12, 8, engine.setInitialVolume),
      const SizedBox(height: 3),
      _valueHeader('Temperatura fixa', '${_n(engine.temperatureC, 0)} °C'),
      _dashSlider(engine.temperatureC, 0, 80, 80, engine.setTemperature),
      const SizedBox(height: 3),
      _valueHeader('Altitude', '${_n(engine.altitudeM, 0)} m'),
      _dashSlider(engine.altitudeM, 0, 3000, 120, engine.setAltitude),
      const Spacer(),
      SizedBox(height: 30, child: OutlinedButton.icon(
        onPressed: () => setState(engine.resetDefaults),
        icon: const Icon(Icons.settings_backup_restore_rounded, size: 17),
        label: const Text('Restaurar padrões'),
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
      )),
    ]),
  );

  Widget _dashTable() {
    // Mantém o dashboard legível com muitas leituras. O CSV contém todas.
    final rows = engine.readings.toList()
      ..sort((a, b) => b.timeS.compareTo(a.timeS));
    final visibleRows = rows.take(5).toList();
    return _dashCard(height: 255, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _title(Icons.table_chart_outlined,
              'Resultados (${engine.readings.length})')),
          TextButton.icon(
            onPressed: _copyCsv,
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('CSV', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(padding: const EdgeInsets.all(3),
                minimumSize: const Size(48, 25)),
          ),
        ]),
        const SizedBox(height: 2),
        Text('Últimas 5 leituras • valores calculados pelo modelo ideal.',
            style: TextStyle(color: PhysGameColors.muted, fontSize: 10)),
        const SizedBox(height: 9),
        _dashDataRow(const ['V (mL)', 'Pabs (kPa)', 'Pman (mmHg)', 'PV (J)'],
            header: true),
        const Divider(height: 8),
        for (final r in visibleRows) ...[
          _dashDataRow([
            _n(r.volumeMl, 2),
            _n(r.absolutePressurePa / 1000, 2),
            _n(r.gaugePressurePa / 133.322, 1),
            _n(r.pvJ, 4),
          ]),
          const SizedBox(height: 4),
        ],
      ],
    ));
  }

  Widget _dashDataRow(List<String> values, {bool header = false}) => SizedBox(
    height: header ? 23 : 25,
    child: Row(children: [
      for (final value in values)
        Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: header ? PhysGameColors.accentText : PhysGameColors.text,
              fontSize: header ? 10 : 11,
              fontWeight: header ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        )),
    ]),
  );

  Widget _dashExplanation() => _dashCard(
    height: 133,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(Icons.menu_book_rounded, 'Como interpretar'),
      const SizedBox(height: 7),
      Text('Com T e n constantes, a pressão ABSOLUTA é inversamente '
           'proporcional ao volume: PV = constante.\n'
           'O manômetro mostra Pabs − Patm. Para aplicar a Lei de Boyle, '
           'use Pabs, não a pressão relativa.',
        style: TextStyle(color: PhysGameColors.muted,
            fontSize: 11, height: 1.35)),
    ]),
  );

  Widget _intro() => _card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.science_rounded, 'Lei de Boyle — Processo isotérmico'),
          const SizedBox(height: 6),
          Text('Comprima o gás mantendo a temperatura e a quantidade '
              'de matéria constantes. Observe como a pressão aumenta.',
              style: TextStyle(color: PhysGameColors.muted, height: 1.4)),
        ],
      ));

  Widget _apparatus() => _card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.precision_manufacturing_rounded,
              'Bancada experimental • Lei de Boyle'),
          const SizedBox(height: 5),
          Text('Arraste a alça do pistão ou use os controles de volume.',
              style: TextStyle(color: PhysGameColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: BoyleApparatusPainter.width /
                  BoyleApparatusPainter.height,
              child: _apparatusCanvas(),
            ),
          ),
          const SizedBox(height: 9),
          Row(children: [
            Icon(Icons.info_outline_rounded,
                size: 15, color: PhysGameColors.accentText),
            const SizedBox(width: 6),
            Expanded(child: Text(
                'As partículas desenhadas são ilustrativas; o modelo '
                'físico é a equação do gás ideal.',
                style: TextStyle(color: PhysGameColors.muted, fontSize: 11))),
          ]),
        ],
      ));

  // A bancada mantém as coordenadas de toque corretas ao mudar de tamanho.
  Widget _apparatusCanvas() => FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: BoyleApparatusPainter.width,
                  height: BoyleApparatusPainter.height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) {
                      final p = d.localPosition;
                      dragging = p.dx >= 505 && p.dx <= 682 &&
                          p.dy >= 62 && p.dy <= 380;
                    },
                    onPanUpdate: (d) {
                      if (!dragging) return;
                      final fraction = ((d.localPosition.dy -
                              BoyleApparatusPainter.pistonStartY) /
                          BoyleApparatusPainter.pistonTravel).clamp(0.0, 1.0);
                      final volume = engine.initialVolumeMl - fraction *
                          (engine.initialVolumeMl - engine.minVolumeMl);
                      setState(() {
                        engine.setTargetVolume(volume);
                        engine.start();
                      });
                    },
                    onPanEnd: (_) => dragging = false,
                    onPanCancel: () => dragging = false,
                    child: CustomPaint(
                      size: const Size(BoyleApparatusPainter.width,
                          BoyleApparatusPainter.height),
                      painter: BoyleApparatusPainter(
                        engine: engine,
                        unit: pressureUnit,
                        analog: analogMode,
                        time: engine.timeS,
                      ),
                    ),
                  ),
                ),
              );

  Widget _controls() {
    final delta = (engine.initialVolumeMl - engine.minVolumeMl) / 20;
    final ready = (engine.volumeMl - engine.targetVolumeMl).abs() < 0.03;
    final distinct = !engine.readings.any((r) =>
        (r.volumeMl - engine.volumeMl).abs() < 0.04);
    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(Icons.tune_rounded, 'Controle do experimento'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: () => setState(() {
              engine.running ? engine.pause() : engine.start();
            }),
            icon: Icon(engine.running
                ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(engine.running ? 'Pausar' : 'Iniciar'),
          )),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: () => setState(engine.resetExperiment),
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reiniciar experimento',
          ),
        ]),
        const SizedBox(height: 16),
        _valueHeader('Volume de destino',
            '${_n(engine.targetVolumeMl, 2)} mL'),
        Slider(
          value: engine.targetVolumeMl,
          min: engine.minVolumeMl,
          max: engine.initialVolumeMl,
          divisions: 40,
          onChanged: (v) => setState(() {
            engine.setTargetVolume(v);
            engine.start();
          }),
        ),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => setState(() {
              engine.changeTargetVolume(-delta);
              engine.start();
            }),
            icon: const Icon(Icons.remove_rounded, size: 18),
            label: const Text('−ΔV'),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => setState(() {
              engine.changeTargetVolume(delta);
              engine.start();
            }),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('+ΔV'),
          )),
        ]),
        const SizedBox(height: 8),
        Text('Passo ΔV = ${_n(delta, 2)} mL • '
            'Faixa ${_n(engine.minVolumeMl, 1)}–'
            '${_n(engine.initialVolumeMl, 1)} mL',
            style: TextStyle(color: PhysGameColors.muted, fontSize: 11)),
        const Divider(height: 28),
        _valueHeader('Unidade do manômetro', 'Pressão relativa'),
        const SizedBox(height: 6),
        DropdownButtonFormField<PressureUnit>(
          initialValue: pressureUnit,
          dropdownColor: PhysGameColors.surfaceHi,
          decoration: InputDecoration(
            filled: true,
            fillColor: PhysGameColors.surfaceHi,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12,
                vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: PhysGameColors.line),
            ),
          ),
          items: PressureUnit.values.map((u) => DropdownMenuItem(
            value: u, child: Text(pressureUnitLabel(u)),
          )).toList(),
          onChanged: (u) {
            if (u != null) setState(() => pressureUnit = u);
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _modeButton('Analógico', Icons.speed_rounded, true)),
          const SizedBox(width: 8),
          Expanded(child: _modeButton('Digital', Icons.numbers_rounded, false)),
        ]),
        const SizedBox(height: 15),
        FilledButton.tonalIcon(
          onPressed: ready && distinct
              ? () => setState(engine.registerReading)
              : null,
          icon: const Icon(Icons.add_chart_rounded),
          label: const Text('Registrar leitura'),
        ),
        const SizedBox(height: 7),
        Text('Registre diferentes volumes após o pistão parar. '
            'A condição inicial já está registrada.',
            style: TextStyle(color: PhysGameColors.muted, fontSize: 11,
                height: 1.35)),
      ],
    ));
  }

  Widget _modeButton(String title, IconData icon, bool analog, {bool compact = false}) {
    final selected = analogMode == analog;
    return OutlinedButton.icon(
      onPressed: () => setState(() => analogMode = analog),
      icon: Icon(icon, size: 17),
      label: Text(title, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? PhysGameColors.purple2.withValues(alpha: .18) : null,
        side: BorderSide(color: selected
            ? PhysGameColors.purple2 : PhysGameColors.line),
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: compact ? 3 : 11),
      ),
    );
  }

  Widget _parameters() => _card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(Icons.settings_input_component_rounded, 'Parâmetros iniciais'),
      const SizedBox(height: 7),
      Text('Alterar um parâmetro reinicia o experimento e as medições.',
          style: TextStyle(color: PhysGameColors.muted, fontSize: 11,
              height: 1.3)),
      const SizedBox(height: 14),
      _slider('Volume inicial', engine.initialVolumeMl, 8, 12, 8,
          '${_n(engine.initialVolumeMl, 1)} mL',
          (v) => engine.setInitialVolume(v)),
      _slider('Temperatura fixa', engine.temperatureC, 0, 80, 80,
          '${_n(engine.temperatureC, 0)} °C',
          (v) => engine.setTemperature(v)),
      _slider('Altitude', engine.altitudeM, 0, 3000, 120,
          '${_n(engine.altitudeM, 0)} m',
          (v) => engine.setAltitude(v)),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => setState(engine.resetDefaults),
        icon: const Icon(Icons.settings_backup_restore_rounded),
        label: const Text('Restaurar valores iniciais'),
      ),
    ],
  ));

  Widget _slider(String title, double value, double min, double max,
      int divisions, String label, ValueChanged<double> callback) {
    return Column(children: [
      _valueHeader(title, label),
      Slider(
        value: value.clamp(min, max).toDouble(),
        min: min, max: max, divisions: divisions,
        onChanged: (v) => setState(() => callback(v)),
      ),
    ]);
  }

  Widget _readings() => _card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(Icons.monitor_heart_rounded, 'Leituras em tempo real'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _metric('Pressão absoluta',
            '${_n(engine.absolutePressureKPa, 2)} kPa', highlighted: true)),
        const SizedBox(width: 8),
        Expanded(child: _metric('Pressão atmosférica',
            '${_n(engine.atmosphericPressurePa, 1)} Pa')),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _metric('Pressão manométrica',
            boyleFormatPressure(math.max(0.0, engine.gaugePressurePa),
                pressureUnit))),
        const SizedBox(width: 8),
        Expanded(child: _metric('Volume atual',
            '${_n(engine.volumeMl, 2)} mL')),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _metric('n (constante)',
            '${engine.moles.toStringAsExponential(4)} mol')),
        const SizedBox(width: 8),
        Expanded(child: _metric('P × V',
            '${_n(engine.pvJ, 4)} Pa·m³')),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PhysGameColors.purple2.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PhysGameColors.purple2.withValues(alpha: .4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('P₁V₁ = P₂V₂', style: TextStyle(
              color: PhysGameColors.accentText, fontSize: 17,
              fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Variação de P × V: '
              '${_n(engine.relativePVErrorPercent, 8)}%  •  '
              'compressão: ${_n(engine.compression * 100, 1)}%',
              style: TextStyle(color: PhysGameColors.muted, fontSize: 12)),
        ]),
      ),
    ],
  ));

  Widget _metric(String title, String value, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PhysGameColors.surfaceHi,
        borderRadius: BorderRadius.circular(10),
        border: highlighted ? Border.all(color: PhysGameColors.purple2) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: PhysGameColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlighted
                  ? PhysGameColors.accentText : PhysGameColors.text,
              fontSize: 14, fontWeight: FontWeight.w800,
            )),
      ]),
    );
  }

  Widget _chart() => _card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(Icons.show_chart_rounded, 'Gráfico pressão × volume'),
      const SizedBox(height: 6),
      Text('Curva teórica isotérmica e leituras registradas.',
          style: TextStyle(color: PhysGameColors.muted, fontSize: 12)),
      const SizedBox(height: 12),
      Container(
        height: 230,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: PhysGameColors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: BoylePVChart(engine: engine),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 18, runSpacing: 6, children: [
        _legend(PhysGameColors.purple2, 'Previsão P(V)'),
        _legend(PhysGameColors.orange, 'Leituras registradas'),
        _legend(PhysGameColors.accentText, 'Estado atual'),
      ]),
    ],
  ));

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(
        color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: PhysGameColors.muted, fontSize: 11)),
    ],
  );

  Widget _table() => _card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(Icons.table_chart_outlined,
          'Tabela de resultados (${engine.readings.length})'),
      const SizedBox(height: 4),
      Text('Valores calculados pelo modelo ideal (não medições reais).',
          style: TextStyle(color: PhysGameColors.muted, fontSize: 11)),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _copyCsv,
          icon: const Icon(Icons.content_copy_rounded, size: 17),
          label: const Text('Copiar CSV'),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 42,
          columnSpacing: 22,
          headingTextStyle: TextStyle(color: PhysGameColors.accentText,
              fontWeight: FontWeight.w800, fontSize: 12),
          dataTextStyle: TextStyle(color: PhysGameColors.text, fontSize: 12),
          columns: const [
            DataColumn(label: Text('Volume (mL)')),
            DataColumn(label: Text('P abs. (kPa)')),
            DataColumn(label: Text('P man. (mmHg)')),
            DataColumn(label: Text('P×V (J)')),
          ],
          rows: engine.readings.map((r) => DataRow(cells: [
            DataCell(Text(_n(r.volumeMl, 2))),
            DataCell(Text(_n(r.absolutePressurePa / 1000, 2))),
            DataCell(Text(_n(r.gaugePressurePa / 133.322, 1))),
            DataCell(Text(_n(r.pvJ, 5))),
          ])).toList(),
        ),
      ),
    ],
  ));

  Future<void> _copyCsv() async {
    final csv = StringBuffer('volume_ml,pressao_absoluta_pa,'
        'pressao_manometrica_pa,pv_j,tempo_s\n');
    for (final reading in engine.readings) {
      csv.writeln('${reading.volumeMl},${reading.absolutePressurePa},'
          '${reading.gaugePressurePa},${reading.pvJ},${reading.timeS}');
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tabela CSV copiada.')),
    );
  }

  Widget _explanation() => _card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(Icons.menu_book_rounded, 'Como interpretar'),
      const SizedBox(height: 9),
      Text(
        'Com temperatura (T) e quantidade de gás (n) constantes, '
        'o produto da pressão ABSOLUTA pelo volume é constante. '
        'Ao reduzir o volume, a pressão aumenta de forma inversamente proporcional.\n\n'
        'A pressão manométrica é Pabs − Patm. '
        'Não use a leitura manométrica diretamente em P₁V₁ = P₂V₂.\n\n'
        'A pressão atmosférica é estimada a partir da altitude por '
        'uma aproximação barométrica isotérmica.',
        style: TextStyle(color: PhysGameColors.muted,
            fontSize: 12, height: 1.48),
      ),
    ],
  ));

  Widget _valueHeader(String title, String value) => Row(
    children: [
      Expanded(child: Text(title, style: TextStyle(
          color: PhysGameColors.text, fontSize: 13,
          fontWeight: FontWeight.w700))),
      Text(value, style: TextStyle(color: PhysGameColors.accentText,
          fontSize: 12, fontWeight: FontWeight.w800)),
    ],
  );

  Widget _title(IconData icon, String text) => Row(children: [
    Icon(icon, size: 19, color: PhysGameColors.accentText),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: TextStyle(
      color: PhysGameColors.text, fontSize: 15,
      fontWeight: FontWeight.w800,
    ))),
  ]);

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PhysGameColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: PhysGameColors.line),
    ),
    child: child,
  );
}
