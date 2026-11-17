import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/physgame_theme.dart';
import '../simulation/gas_engine.dart';
import '../simulation/gas_particle.dart';
import '../widgets/history_chart.dart';
import '../widgets/lab/lab_painters.dart';
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

  /// Estado visual do palco (régua, cronômetro, unidades, bomba).
  final LabViewState view = LabViewState();

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

  // Tons usados nos avisos sobre fundo escuro.
  static const Color _okText = Color(0xFF6CE9A6);
  static const Color _warnText = Color(0xFFFDBA74);
  static const Color _badText = Color(0xFFFDA29B);

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

  String _n(double value, int decimals) =>
      value.toStringAsFixed(decimals).replaceAll('.', ',');

  // ── Estrutura da página ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final Widget body;
            if (width >= 1180) {
              body = _wideBody();
            } else if (width >= 820) {
              body = _mediumBody(height);
            } else {
              body = _narrowBody(height);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _header(width),
                ),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Tela larga: análise à esquerda, câmara no centro, controles à direita.
  /// A câmara sempre cabe inteira na altura da janela.
  Widget _wideBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 330,
            child: _scrollColumn([
              if (section != LabSection.explore) _rightPanel(),
              _analysisPanel(),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: _stage(),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: _scrollColumn([_controls()]),
          ),
        ],
      ),
    );
  }

  /// Tela média: câmara e análise à esquerda, controles à direita.
  Widget _mediumBody(double height) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _scrollColumn([
              if (section == LabSection.mission) _rightPanel(),
              _boundedStage(height),
              if (section == LabSection.energy ||
                  section == LabSection.diffusion)
                _rightPanel(),
              _analysisPanel(),
            ]),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 300,
            child: _scrollColumn([_controls()]),
          ),
        ],
      ),
    );
  }

  /// Tela estreita (celular): tudo em uma coluna.
  Widget _narrowBody(double height) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _scrollColumn([
        // Missão: as etapas ficam acima do laboratório.
        if (section == LabSection.mission) _rightPanel(),
        _boundedStage(height),
        // Energia e Difusão: painel extra abaixo do laboratório.
        if (section == LabSection.energy || section == LabSection.diffusion)
          _rightPanel(),
        _controls(),
        _analysisPanel(),
      ]),
    );
  }

  Widget _scrollColumn(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _stage() {
    return LabStageCard(
      engine: engine,
      view: view,
      onChanged: () => setState(() {}),
      onReset: () {
        _resetCurrent();
        view.resetTools();
      },
    );
  }

  /// Câmara limitada à altura visível, para não precisar rolar ao usá-la.
  Widget _boundedStage(double viewportHeight) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.max(300.0, viewportHeight - 110),
      ),
      child: Align(
        alignment: Alignment.center,
        heightFactor: 1,
        child: _stage(),
      ),
    );
  }

  Widget _controls() {
    return LabPanels(
      engine: engine,
      view: view,
      onChanged: () => setState(() {}),
    );
  }

  // ── Cabeçalho ───────────────────────────────────────────────────────
  Widget _header(double width) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [PhysGameColors.purple2, PhysGameColors.purple],
            ),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PhysGame Lab',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: PhysGameColors.text,
                ),
              ),
              Text(
                'Propriedades dos gases',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: PhysGameColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (section == LabSection.mission) ...[
          _xpBadge(),
          const SizedBox(width: 8),
        ],
        Tooltip(
          message: 'Reiniciar',
          child: Material(
            color: PhysGameColors.surface,
            shape: const CircleBorder(
              side: BorderSide(color: PhysGameColors.line),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _resetCurrent,
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.restart_alt_rounded,
                  size: 20,
                  color: PhysGameColors.text,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (width >= 900) {
      return Row(
        children: [
          brand,
          const SizedBox(width: 24),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: _sectionTabs(showIcons: true),
              ),
            ),
          ),
          const SizedBox(width: 24),
          actions,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: brand),
            ),
            const SizedBox(width: 8),
            actions,
          ],
        ),
        const SizedBox(height: 10),
        _sectionTabs(showIcons: width >= 480),
      ],
    );
  }

  Widget _sectionTabs({required bool showIcons}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PhysGameColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PhysGameColors.line),
      ),
      child: Row(
        children: [
          _tab(LabSection.explore, Icons.science_rounded, 'Exploração',
              showIcons),
          _tab(LabSection.energy, Icons.bolt_rounded, 'Energia', showIcons),
          _tab(LabSection.diffusion, Icons.swap_horiz_rounded, 'Difusão',
              showIcons),
          _tab(LabSection.mission, Icons.flag_rounded, 'Missão', showIcons),
        ],
      ),
    );
  }

  Widget _tab(LabSection value, IconData icon, String label, bool showIcon) {
    final active = section == value;
    final color = active ? Colors.white : PhysGameColors.muted;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _switchSection(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? PhysGameColors.purple : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showIcon) ...[
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Painel da aba atual ─────────────────────────────────────────────
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
          _cardTitle(Icons.bolt_rounded, _sectionTitle),
          const SizedBox(height: 6),
          const Text(
            'Partículas leves atingem velocidades maiores que as pesadas na mesma temperatura. '
            'As barras são as velocidades medidas agora e as linhas são a previsão de Maxwell-Boltzmann.',
            style: TextStyle(
              color: PhysGameColors.muted,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 210,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PhysGameColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SpeedHistogram(engine: engine),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          _thermalControls(),
          const SizedBox(height: 12),
          _infoBox(
            'Trabalho P·V',
            'Trabalho acumulado sobre o gás: '
                '${_n(engine.workOnGasJ, 2)} J\n'
                'Energia interna: ${_n(engine.internalEnergyJ, 1)} J\n\n'
                'Arraste a tampa para comprimir e expandir o gás e observar o sinal e a magnitude do trabalho. '
                'A tampa em movimento transfere energia às partículas: sem nada mantido constante, comprimir aquece e expandir esfria.',
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
          _cardTitle(Icons.swap_horiz_rounded, _sectionTitle),
          const SizedBox(height: 6),
          const Text(
            'As espécies começam separadas. Abra a divisória e observe a mistura ao longo do tempo.',
            style: TextStyle(
              color: PhysGameColors.muted,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              setState(engine.toggleBarrier);
            },
            icon: Icon(
              engine.barrierOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
            ),
            label: Text(
              engine.barrierOpen ? 'Fechar divisória' : 'Abrir divisória',
            ),
          ),
          const SizedBox(height: 12),
          _infoBox(
            'Configuração',
            'Lado esquerdo: partículas leves\n'
                'Lado direito: partículas pesadas\n'
                'T = ${engine.temperatureK.toStringAsFixed(0)} K',
          ),
          const SizedBox(height: 14),
          _slider(
            title: 'Temperatura',
            value: engine.temperatureK.clamp(200.0, 600.0).toDouble(),
            min: 200,
            max: 600,
            divisions: 80,
            valueText: '${engine.temperatureK.toStringAsFixed(0)} K',
            icon: Icons.thermostat_rounded,
            enabled: true,
            onChanged: engine.setTemperature,
          ),
          const SizedBox(height: 8),
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
              Expanded(
                child: _cardTitle(
                  Icons.flag_rounded,
                  'Missão: investigue P, V e T',
                ),
              ),
              _xpBadge(),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: missionDone ? 1 : missionStep / 5,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
            color: PhysGameColors.purple2,
            backgroundColor: PhysGameColors.line,
          ),
          const SizedBox(height: 16),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PhysGameColors.success.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: PhysGameColors.success.withValues(alpha: .5),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: PhysGameColors.amber,
                  size: 44,
                ),
                SizedBox(height: 8),
                Text(
                  'Missão concluída!',
                  style: TextStyle(
                    color: _okText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Você relacionou pressão, volume, temperatura e colisões.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _okText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _infoBox(
            'Resultado',
            'P inicial: ${pInitial == null ? '-' : _n(pInitial!, 1)} kPa\n'
                'P após compressão: ${pCompressed == null ? '-' : _n(pCompressed!, 1)} kPa\n'
                'P após aquecimento: ${pHeated == null ? '-' : _n(pHeated!, 1)} kPa\n\n'
                'XP obtido: $xp',
          ),
          const SizedBox(height: 14),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stepEyebrow('OBJETIVO'),
            const SizedBox(height: 8),
            const Text(
              'Você vai alterar uma variável por vez e observar a resposta do sistema.',
              style: TextStyle(
                color: PhysGameColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _infoBox(
              'Condição inicial',
              'V = 4,00 L\nT = 300 K\n${GasEngine.defaultCount} partículas',
            ),
            const SizedBox(height: 14),
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
            (engine.temperatureK - 300).abs() < 5 &&
            engine.totalCount == GasEngine.defaultCount;

        return _missionStep(
          number: 1,
          title: 'Registre o estado inicial',
          description:
              'Mantenha 4,00 L, 300 K e ${GasEngine.defaultCount} partículas.',
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
            (engine.temperatureK - 300).abs() < 5 &&
            engine.totalCount == GasEngine.defaultCount;

        return _missionStep(
          number: 2,
          title: 'Comprima o gás',
          description: 'Reduza somente o volume para aproximadamente 2,00 L. '
              'Comprimir aquece o gás: em "Manter constante", marque Temperatura (T) antes de arrastar a tampa.',
          ready: ready,
          readyText: 'Volume alvo atingido.',
          pendingText: 'Arraste a tampa até V ≈ 2,00 L com T ≈ 300 K. '
              'Atual: ${_n(engine.volumeL, 2)} L e ${engine.temperatureK.toStringAsFixed(0)} K.',
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
        final ready =
            engine.temperatureK >= 395 && (engine.volumeL - 2).abs() < .08;

        return _missionStep(
          number: 3,
          title: 'Aqueça o gás',
          description:
              'Mantenha o volume e aumente a temperatura para cerca de 400 K. '
              'Em "Manter constante", troque para Volume (V) para liberar a temperatura.',
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stepEyebrow('ETAPA 4 DE 4'),
            const SizedBox(height: 8),
            const Text(
              'Interprete os resultados',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: PhysGameColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Qual alternativa descreve melhor o que você observou?',
              style: TextStyle(
                color: PhysGameColors.muted,
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
              const SizedBox(height: 6),
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

  Widget _stepEyebrow(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: PhysGameColors.accentText,
        fontSize: 11,
        letterSpacing: .8,
        fontWeight: FontWeight.w900,
      ),
    );
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepEyebrow('ETAPA $number DE 4'),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: PhysGameColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: PhysGameColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        _statusBox(
          ready: ready,
          text: ready ? readyText : pendingText,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(buttonText),
        ),
      ],
    );
  }

  // ── Análise em tempo real ───────────────────────────────────────────
  Widget _analysisPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(Icons.insights_rounded, 'Análise em tempo real'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 640;

              final gauge = SizedBox(
                width: 150,
                height: 150,
                child: PressureGauge(pressureKPa: engine.pressureKPa),
              );

              final chart = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Histórico de pressão',
                    style: TextStyle(
                      color: PhysGameColors.accentText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 170,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: PhysGameColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HistoryChart(
                      samples: List<SimulationSample>.from(engine.history),
                    ),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    gauge,
                    const SizedBox(width: 16),
                    Expanded(child: _readings()),
                    const SizedBox(width: 16),
                    Expanded(child: chart),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: gauge),
                  const SizedBox(height: 12),
                  _readings(),
                  const SizedBox(height: 14),
                  chart,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Leituras em blocos: um valor por bloco, fácil de localizar.
  Widget _readings() {
    final tiles = <Widget>[
      _metricTile(
        'Pressão medida',
        '${_n(engine.pressureKPa, 1)} kPa',
        highlight: true,
      ),
      _metricTile('Gás ideal (nRT/V)', '${_n(engine.idealPressureKPa, 1)} kPa'),
      _metricTile(
          'Equivale a', '${engine.pressureMmHg.toStringAsFixed(0)} mmHg'),
      _metricTile('Temperatura', '${engine.temperatureK.toStringAsFixed(0)} K'),
      _metricTile('Volume', '${_n(engine.volumeL, 2)} L'),
      _metricTile('Partículas', '${engine.totalCount}'),
      _metricTile('Colisões', '${engine.collisionRate.toStringAsFixed(0)}/s'),
      _metricTile('Trabalho sobre o gás', '${_n(engine.workOnGasJ, 2)} J'),
    ];

    return Column(
      children: [
        for (int i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 8),
              Expanded(child: tiles[i + 1]),
            ],
          ),
        ],
      ],
    );
  }

  Widget _metricTile(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PhysGameColors.surfaceHi,
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? Border.all(color: PhysGameColors.purple2.withValues(alpha: .7))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PhysGameColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  highlight ? PhysGameColors.accentText : PhysGameColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Peças reutilizadas ──────────────────────────────────────────────
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
              color: PhysGameColors.coolColor,
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
              Icon(icon, size: 18, color: PhysGameColors.accentText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PhysGameColors.text,
                  ),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  color: PhysGameColors.accentText,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
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
                    color: PhysGameColors.text,
                  ),
                ),
                Text(
                  'v média visual: ${_n(speed, 3)}',
                  style: const TextStyle(
                    color: PhysGameColors.muted,
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

    Color bg = PhysGameColors.surfaceHi;
    Color border = PhysGameColors.line;
    Color text = PhysGameColors.text;

    if (answerLocked && selected) {
      if (correct) {
        bg = PhysGameColors.success.withValues(alpha: .14);
        border = PhysGameColors.success;
        text = _okText;
      } else {
        bg = PhysGameColors.danger.withValues(alpha: .14);
        border = PhysGameColors.danger;
        text = _badText;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: PhysGameColors.bg,
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
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
                    fontWeight: FontWeight.w600,
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.info_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ready ? _okText : _warnText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _xpBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PhysGameColors.amber.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.stars_rounded,
            size: 17,
            color: PhysGameColors.amber,
          ),
          const SizedBox(width: 4),
          Text(
            '$xp XP',
            style: const TextStyle(
              color: Color(0xFFFCD34D),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PhysGameColors.surfaceHi,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: PhysGameColors.accentText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              color: PhysGameColors.muted,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PhysGameColors.accentText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: PhysGameColors.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhysGameColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhysGameColors.line),
      ),
      child: child,
    );
  }

  String get _sectionTitle {
    switch (section) {
      case LabSection.explore:
        return 'Câmara experimental';
      case LabSection.energy:
        return 'Energia e velocidades';
      case LabSection.diffusion:
        return 'Experimento de difusão';
      case LabSection.mission:
        return 'Experimento guiado';
    }
  }
}
