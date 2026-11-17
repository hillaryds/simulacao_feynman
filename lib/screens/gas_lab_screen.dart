import 'package:flutter/material.dart';
import '../core/physgame_theme.dart';
import '../simulation/gas_engine.dart';
import '../simulation/gas_particle.dart';
import '../widgets/history_chart.dart';
import '../widgets/lab/phet_lab.dart';
import '../widgets/pressure_gauge.dart';
import '../widgets/speed_histogram.dart';

enum LabSection { explore, energy, diffusion, mission }

class GasLabScreen extends StatefulWidget {
  const GasLabScreen({super.key});

  @override
  State<GasLabScreen> createState() => _GasLabScreenState();
}

class _GasLabScreenState extends State<GasLabScreen>
    with SingleTickerProviderStateMixin {
  final GasEngine engine = GasEngine();

  late final AnimationController ticker;
  Duration? lastTick;

  LabSection section = LabSection.explore;

  int missionStep = 0;
  int xp = 0;
  bool missionDone = false;
  int? answer;
  bool answerLocked = false;

  double? pInitial;
  double? pCompressed;
  double? pHeated;

  @override
  void initState() {
    super.initState();

    ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )
      ..addListener(_tick)
      ..repeat();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void _tick() {
    final elapsed = ticker.lastElapsedDuration ?? Duration.zero;
    double dt = .016;

    if (lastTick != null) {
      dt = (elapsed - lastTick!).inMicroseconds / 1000000.0;
    }

    lastTick = elapsed;
    engine.update(dt);

    if (mounted) setState(() {});
  }

  void _switchSection(LabSection next) {
    setState(() {
      section = next;

      if (next == LabSection.diffusion) {
        engine.resetDiffusion();
      } else {
        engine.resetExplore();
      }

      missionStep = 0;
      xp = 0;
      missionDone = false;
      answer = null;
      answerLocked = false;
      pInitial = null;
      pCompressed = null;
      pHeated = null;
    });
  }

  void _resetCurrent() {
    setState(() {
      if (section == LabSection.diffusion) {
        engine.resetDiffusion();
      } else {
        engine.resetExplore();
      }

      missionStep = 0;
      xp = 0;
      missionDone = false;
      answer = null;
      answerLocked = false;
      pInitial = null;
      pCompressed = null;
      pHeated = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: PhysGameColors.purple,
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PhysGame Lab',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Propriedades dos gases',
                  style: TextStyle(
                    fontSize: 11,
                    color: PhysGameColors.slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (section == LabSection.mission)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(child: _xpBadge()),
            ),
          IconButton(
            tooltip: 'Reiniciar',
            onPressed: _resetCurrent,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTabs(),
                  const SizedBox(height: 16),

                  // Missão: as etapas ficam acima do laboratório.
                  if (section == LabSection.mission) ...[
                    _rightPanel(),
                    const SizedBox(height: 16),
                  ],

                  // Laboratório no estilo PhET (câmara + painéis laterais).
                  PhetLab(
                    engine: engine,
                    onChanged: () => setState(() {}),
                    onReset: _resetCurrent,
                  ),

                  // Energia e Difusão: painel extra abaixo do laboratório.
                  if (section == LabSection.energy ||
                      section == LabSection.diffusion) ...[
                    const SizedBox(height: 16),
                    _rightPanel(),
                  ],

                  const SizedBox(height: 16),
                  _analysisPanel(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PhysGameColors.border),
      ),
      child: Row(
        children: [
          _tab(LabSection.explore, Icons.science_rounded, 'Exploração'),
          _tab(LabSection.energy, Icons.bolt_rounded, 'Energia'),
          _tab(LabSection.diffusion, Icons.swap_horiz_rounded, 'Difusão'),
          _tab(LabSection.mission, Icons.flag_rounded, 'Missão'),
        ],
      ),
    );
  }

  Widget _tab(LabSection value, IconData icon, String label) {
    final active = section == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _switchSection(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? PhysGameColors.purpleSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? PhysGameColors.purple : PhysGameColors.slate,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? PhysGameColors.purple : PhysGameColors.slate,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rightPanel() {
    switch (section) {
      case LabSection.explore:
        return const SizedBox.shrink();
      case LabSection.energy:
        return _energyPanel();
      case LabSection.diffusion:
        return _diffusionPanel();
      case LabSection.mission:
        return _missionPanel();
    }
  }

  Widget _energyPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Energia e velocidades',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Partículas leves atingem velocidades maiores que as pesadas na mesma temperatura.',
            style: TextStyle(
              color: PhysGameColors.slate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 220,
            child: SpeedHistogram(engine: engine),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _legendMetric(
                  PhysGameColors.lightParticle,
                  'Leves',
                  engine.averageSpeedFor(ParticleSpecies.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _legendMetric(
                  PhysGameColors.heavyParticle,
                  'Pesadas',
                  engine.averageSpeedFor(ParticleSpecies.heavy),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          _thermalControls(),

          const SizedBox(height: 18),
          _infoBox(
            'Trabalho P·V',
            'Trabalho acumulado sobre o gás: '
                '${engine.workOnGasJ.toStringAsFixed(2)} J\n\n'
                'Arraste a tampa para comprimir e expandir o gás e observar o sinal e a magnitude do trabalho.',
          ),
        ],
      ),
    );
  }

  Widget _diffusionPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Experimento de difusão',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'As espécies começam separadas. Abra a divisória e observe a mistura ao longo do tempo.',
            style: TextStyle(
              color: PhysGameColors.slate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: () {
              setState(engine.toggleBarrier);
            },
            icon: Icon(
              engine.barrierOpen
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded,
            ),
            label: Text(
              engine.barrierOpen
                  ? 'Fechar divisória'
                  : 'Abrir divisória',
            ),
          ),

          const SizedBox(height: 14),

          _infoBox(
            'Configuração',
            'Lado esquerdo: partículas leves\n'
                'Lado direito: partículas pesadas\n'
                'T = ${engine.temperatureK.toStringAsFixed(0)} K',
          ),

          const SizedBox(height: 16),
          _slider(
            title: 'Temperatura',
            value: engine.temperatureK,
            min: 200,
            max: 600,
            divisions: 80,
            valueText: '${engine.temperatureK.toStringAsFixed(0)} K',
            icon: Icons.thermostat_rounded,
            enabled: true,
            onChanged: engine.setTemperature,
          ),

          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              setState(engine.resetDiffusion);
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reiniciar difusão'),
          ),
        ],
      ),
    );
  }

  Widget _missionPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Missão: investigue P, V e T',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _xpBadge(),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: missionDone ? 1 : missionStep / 5,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: PhysGameColors.purple.withOpacity(.12),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _missionContent(),
          ),
        ],
      ),
    );
  }

  Widget _missionContent() {
    if (missionDone) {
      return Column(
        key: const ValueKey('done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFABEFC6)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: PhysGameColors.amber,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Missão concluída!',
                  style: TextStyle(
                    color: Color(0xFF067647),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Você relacionou pressão, volume, temperatura e colisões.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF067647)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _infoBox(
            'Resultado',
            'P inicial: ${pInitial?.toStringAsFixed(1) ?? '-'} kPa\n'
                'P após compressão: ${pCompressed?.toStringAsFixed(1) ?? '-'} kPa\n'
                'P após aquecimento: ${pHeated?.toStringAsFixed(1) ?? '-'} kPa\n\n'
                'XP obtido: $xp',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _resetCurrent,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Refazer missão'),
          ),
        ],
      );
    }

    switch (missionStep) {
      case 0:
        return Column(
          key: const ValueKey('m0'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Objetivo',
              style: TextStyle(
                color: PhysGameColors.purple,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Você vai alterar uma variável por vez e observar a resposta do sistema.',
              style: TextStyle(
                color: PhysGameColors.slate,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _infoBox(
              'Condição inicial',
              'V = 4,00 L\nT = 300 K\n32 partículas',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  engine.resetExplore();
                  missionStep = 1;
                });
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Começar'),
            ),
          ],
        );

      case 1:
        final ready = (engine.volumeL - 4).abs() < .08 &&
            (engine.temperatureK - 300).abs() < 2 &&
            engine.totalCount == 32;

        return _missionStep(
          number: 1,
          title: 'Registre o estado inicial',
          description: 'Mantenha 4,00 L, 300 K e 32 partículas.',
          ready: ready,
          readyText: 'Condição inicial correta.',
          pendingText: 'Ajuste o sistema para a condição inicial.',
          buttonText: 'Registrar',
          onPressed: ready
              ? () {
                  setState(() {
                    pInitial = engine.pressureKPa;
                    xp += 25;
                    missionStep = 2;
                  });
                }
              : null,
        );

      case 2:
        final ready = (engine.volumeL - 2).abs() < .08 &&
            (engine.temperatureK - 300).abs() < 2 &&
            engine.totalCount == 32;

        return _missionStep(
          number: 2,
          title: 'Comprima o gás',
          description:
              'Reduza somente o volume para aproximadamente 2,00 L.',
          ready: ready,
          readyText: 'Volume alvo atingido.',
          pendingText: 'Arraste a tampa até V ≈ 2,00 L.',
          buttonText: 'Confirmar compressão',
          onPressed: ready
              ? () {
                  setState(() {
                    pCompressed = engine.pressureKPa;
                    xp += 50;
                    missionStep = 3;
                  });
                }
              : null,
        );

      case 3:
        final ready = engine.temperatureK >= 395 &&
            (engine.volumeL - 2).abs() < .08;

        return _missionStep(
          number: 3,
          title: 'Aqueça o gás',
          description:
              'Mantenha o volume e aumente a temperatura para cerca de 400 K.',
          ready: ready,
          readyText: 'Temperatura alvo atingida.',
          pendingText:
              'Use o aquecedor (balde) ou os botões. Atual: ${engine.temperatureK.toStringAsFixed(0)} K.',
          buttonText: 'Confirmar aquecimento',
          onPressed: ready
              ? () {
                  setState(() {
                    pHeated = engine.pressureKPa;
                    xp += 50;
                    missionStep = 4;
                  });
                }
              : null,
        );

      case 4:
        return Column(
          key: const ValueKey('m4'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ETAPA 4 DE 4',
              style: TextStyle(
                color: PhysGameColors.purple,
                fontSize: 11,
                letterSpacing: .7,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Interprete os resultados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Qual alternativa descreve melhor o que você observou?',
              style: TextStyle(
                color: PhysGameColors.slate,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _answerOption(
              0,
              'Diminuir o volume e aumentar a temperatura elevaram a pressão.',
            ),
            _answerOption(
              1,
              'Diminuir o volume reduziu a pressão.',
            ),
            _answerOption(
              2,
              'A temperatura não teve efeito sobre a pressão.',
            ),
            if (answerLocked && answer != 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    answerLocked = false;
                    answer = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _missionStep({
    required int number,
    required String title,
    required String description,
    required bool ready,
    required String readyText,
    required String pendingText,
    required String buttonText,
    required VoidCallback? onPressed,
  }) {
    return Column(
      key: ValueKey('mission-step-$number'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ETAPA $number DE 4',
          style: const TextStyle(
            color: PhysGameColors.purple,
            fontSize: 11,
            letterSpacing: .7,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: PhysGameColors.slate,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        _statusBox(
          ready: ready,
          text: ready ? readyText : pendingText,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(buttonText),
        ),
      ],
    );
  }

  Widget _analysisPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Análise em tempo real',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 760;

              final gauge = SizedBox(
                height: 220,
                child: Row(
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: PressureGauge(
                        pressureKPa: engine.pressureKPa,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _infoBox(
                        'Leituras',
                        'Pressão: ${engine.pressureKPa.toStringAsFixed(1)} kPa\n'
                            'Equivale a: ${engine.pressureMmHg.toStringAsFixed(0)} mmHg\n'
                            'Partículas: ${engine.totalCount}\n'
                            'Colisões: ${engine.collisionRate.toStringAsFixed(0)}/s\n'
                            'Trabalho sobre o gás: ${engine.workOnGasJ.toStringAsFixed(2)} J',
                      ),
                    ),
                  ],
                ),
              );

              final chart = SizedBox(
                height: 220,
                child: HistoryChart(
                  samples: List<SimulationSample>.from(engine.history),
                ),
              );

              if (wide) {
                return Row(
                  children: [
                    Expanded(child: gauge),
                    const SizedBox(width: 16),
                    Expanded(child: chart),
                  ],
                );
              }

              return Column(
                children: [
                  gauge,
                  const SizedBox(height: 12),
                  chart,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _thermalControls() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: engine.constantMode == ConstantMode.temperature
                ? null
                : () => setState(() => engine.cool(25)),
            icon: const Icon(
              Icons.ac_unit_rounded,
              color: Color(0xFF2E90FA),
            ),
            label: const Text('Resfriar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: engine.constantMode == ConstantMode.temperature
                ? null
                : () => setState(() => engine.heat(25)),
            icon: const Icon(
              Icons.local_fire_department_rounded,
              color: PhysGameColors.orange,
            ),
            label: const Text('Aquecer'),
          ),
        ),
      ],
    );
  }

  Widget _slider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueText,
    required IconData icon,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: PhysGameColors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  color: PhysGameColors.purple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled
                ? (v) {
                    setState(() => onChanged(v));
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _legendMetric(Color color, String label, double speed) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'v média visual: ${speed.toStringAsFixed(3)}',
                  style: const TextStyle(
                    color: PhysGameColors.slate,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerOption(int index, String label) {
    final selected = answer == index;
    final correct = index == 0;

    Color bg = Colors.white;
    Color border = PhysGameColors.border;
    Color text = PhysGameColors.navy;

    if (answerLocked && selected) {
      if (correct) {
        bg = const Color(0xFFECFDF3);
        border = const Color(0xFF12B76A);
        text = const Color(0xFF067647);
      } else {
        bg = const Color(0xFFFEF3F2);
        border = const Color(0xFFF04438);
        text = const Color(0xFFB42318);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: answerLocked
            ? null
            : () {
                setState(() {
                  answer = index;
                  answerLocked = true;

                  if (correct) {
                    xp += 100;
                    missionDone = true;
                  }
                });
              },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: border.withOpacity(.10),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBox({
    required bool ready,
    required String text,
  }) {
    final color = ready ? PhysGameColors.success : PhysGameColors.orange;
    final bg =
        ready ? const Color(0xFFECFDF3) : const Color(0xFFFFF6ED);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.info_rounded,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ready
                    ? const Color(0xFF067647)
                    : const Color(0xFFB54708),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _xpBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.stars_rounded,
            size: 18,
            color: Color(0xFFF79009),
          ),
          const SizedBox(width: 4),
          Text(
            '$xp XP',
            style: const TextStyle(
              color: Color(0xFFB54708),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhysGameColors.purpleSoft.withOpacity(.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: PhysGameColors.purple,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              color: PhysGameColors.slate,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PhysGameColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  String get _sectionTitle {
    switch (section) {
      case LabSection.explore:
        return 'Câmara experimental';
      case LabSection.energy:
        return 'Energia molecular';
      case LabSection.diffusion:
        return 'Mistura e difusão';
      case LabSection.mission:
        return 'Experimento guiado';
    }
  }

  String get _sectionSubtitle {
    switch (section) {
      case LabSection.explore:
        return 'Arraste a tampa, use a bomba e o aquecedor para alterar as variáveis.';
      case LabSection.energy:
        return 'Compare velocidades de partículas leves e pesadas.';
      case LabSection.diffusion:
        return 'Abra a divisória e observe a mistura das espécies.';
      case LabSection.mission:
        return 'Siga as etapas, valide os resultados e ganhe XP.';
    }
  }
}
