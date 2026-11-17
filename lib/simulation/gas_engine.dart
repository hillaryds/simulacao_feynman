import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gas_particle.dart';

/// Variável mantida constante (painel "Manter constante").
///
/// - [pressure]  = "Pressão ↕V": a pressão fica fixa e o VOLUME se ajusta.
/// - [pressureT] = "Pressão ↕T": a pressão fica fixa e a TEMPERATURA se ajusta.
enum ConstantMode { none, volume, temperature, pressure, pressureT }

class SimulationSample {
  final double time;
  final double pressureKPa;
  final double volumeL;
  final double temperatureK;

  const SimulationSample({
    required this.time,
    required this.pressureKPa,
    required this.volumeL,
    required this.temperatureK,
  });
}

/// Motor de gás 2D de esferas rígidas.
///
/// As grandezas macroscópicas saem das próprias partículas:
/// - a TEMPERATURA é a energia cinética média (em 2D, ⟨½mv²⟩ = kT);
/// - a PRESSÃO é o impulso entregue às paredes por unidade de tempo e de
///   comprimento de parede;
/// - a TAMPA em movimento troca energia com as partículas que batem nela,
///   então comprimir aquece e expandir esfria (trabalho real sobre o gás);
/// - o AQUECEDOR atua no piso: só as partículas que tocam o fundo ganham ou
///   perdem energia, e o calor se espalha pelas colisões.
class GasEngine {
  static const double gasConstant = 8.314462618;
  static const double molPerParticle = 0.001;
  static const double minTemperatureK = 100.0;
  static const double maxTemperatureK = 1000.0;

  /// Estado inicial da aba de exploração e da missão.
  static const int defaultLight = 50;
  static const int defaultHeavy = 30;
  static const int defaultCount = defaultLight + defaultHeavy;

  /// Raios normalizados (fração da largura da câmara).
  static const double lightRadius = 0.008;
  static const double heavyRadius = 0.011;

  static const double lightMass = 1.0;
  static const double heavyMass = 4.0;

  /// Paredes da câmara em coordenadas normalizadas.
  static const double wallLeft = 0.006;
  static const double wallRight = 0.994;
  static const double wallBottom = 0.994;
  static const double chamberWidth = wallRight - wallLeft;

  /// Altura do gás por litro: a área ocupada é proporcional ao volume.
  static const double heightPerL = 0.172;
  static const double areaPerL = chamberWidth * heightPerL;

  /// Velocidade quadrática média de uma partícula leve a 300 K.
  static const double referenceSpeed = 0.8;

  /// Constante de Boltzmann nas unidades da simulação (2D: ⟨½mv²⟩ = kT).
  static const double kSim = referenceSpeed * referenceSpeed / (2 * 300.0);

  /// Joules por unidade de energia da simulação (N·kSim·T ↔ n·R·T).
  static const double joulePerSim = molPerParticle * gasConstant / kSim;

  /// Velocidade máxima da tampa (L/s).
  static const double maxLidSpeed = 0.6;

  /// Fração máxima da área que as partículas podem ocupar.
  static const double maxPacking = 0.5;

  static const double _gravityAccel = 1.0;
  static const double _pressureTau = 1.5;

  final math.Random _random = math.Random(2026);
  final List<GasParticle> particles = [];
  final List<SimulationSample> history = [];

  double volumeL = 4.0;
  double gravity = 0.0;

  double _targetVolumeL = 4.0;
  double _temperatureK = 300.0;

  ConstantMode constantMode = ConstantMode.none;
  double _lockedTemperatureK = 300.0;
  double _lockedKineticPressure = 0.0;

  bool diffusionMode = false;
  bool barrierOpen = false;

  /// Pausa/continua a simulação (botão play/pause do palco).
  bool paused = false;

  /// Posição do controle aquecer/arrefecer, de -1 (arrefecer) a +1 (aquecer).
  double heaterLevel = 0.0;

  /// Tempo simulado acumulado (s) e colisões totais com as paredes.
  double simTime = 0.0;
  int totalCollisions = 0;

  double collisionRate = 0.0;

  /// Trabalho realizado pela tampa sobre o gás (J), somado colisão a colisão.
  double workOnGasJ = 0.0;

  /// Pressão medida pelas colisões (unidades da simulação, média móvel).
  double _pressureSim = 0.0;

  double _collisionWindow = 0.0;
  int _collisionsInWindow = 0;
  double _historyClock = 0.0;
  double _lastHistoryPoint = -1.0;

  GasEngine() {
    resetExplore();
  }

  int get lightCount =>
      particles.where((p) => p.species == ParticleSpecies.light).length;

  int get heavyCount =>
      particles.where((p) => p.species == ParticleSpecies.heavy).length;

  int get totalCount => particles.length;

  double get moles => totalCount * molPerParticle;

  /// Temperatura cinética: energia cinética média das partículas.
  double get temperatureK => _temperatureK;

  /// Volume para onde a tampa está indo (ela se move com velocidade finita).
  double get targetVolumeL => _targetVolumeL;

  /// Pressão MEDIDA pelo impulso das partículas nas paredes.
  double get pressurePa {
    if (particles.isEmpty) return 0;
    return _pressureSim * areaPerL * 1000.0 * joulePerSim;
  }

  double get pressureKPa => pressurePa / 1000.0;
  double get pressureMmHg => pressurePa / 133.322;
  double get pressureAtm => pressurePa / 101325.0;

  /// Previsão do gás ideal (PV = nRT) para comparar com a medida.
  double get idealPressurePa {
    if (particles.isEmpty || volumeL <= 0) return 0;
    return moles * gasConstant * _temperatureK / (volumeL / 1000.0);
  }

  double get idealPressureKPa => idealPressurePa / 1000.0;

  /// Energia interna (cinética total) em joules.
  double get internalEnergyJ => _kineticEnergy() * joulePerSim;

  double get pistonY => wallBottom - heightPerL * volumeL;

  double get averageSpeed {
    if (particles.isEmpty) return 0;
    double sum = 0;
    for (final p in particles) {
      sum += p.velocity.distance;
    }
    return sum / particles.length;
  }

  double averageSpeedFor(ParticleSpecies species) {
    final list = particles.where((p) => p.species == species).toList();
    if (list.isEmpty) return 0;
    return list.map((p) => p.velocity.distance).reduce((a, b) => a + b) /
        list.length;
  }

  static double massOf(ParticleSpecies species) =>
      species == ParticleSpecies.light ? lightMass : heavyMass;

  /// Velocidade quadrática média teórica de uma espécie na temperatura atual.
  double rmsSpeedFor(ParticleSpecies species) =>
      math.sqrt(2 * kSim * _temperatureK / massOf(species));

  /// Distribuição de Maxwell-Boltzmann em 2D para o módulo da velocidade:
  /// f(v) = (m·v / kT) · exp(−m·v² / 2kT).
  double speedDensity(double speed, ParticleSpecies species) {
    final kT = kSim * _temperatureK;
    if (kT <= 0) return 0;
    final m = massOf(species);
    return (m * speed / kT) * math.exp(-m * speed * speed / (2 * kT));
  }

  void resetExplore() {
    _resetState(volume: 4.0, mode: ConstantMode.none, diffusion: false);
    addParticles(ParticleSpecies.light, defaultLight, side: -1);
    addParticles(ParticleSpecies.heavy, defaultHeavy, side: -1);
    _finishReset();
  }

  void resetDiffusion() {
    _resetState(volume: 5.0, mode: ConstantMode.volume, diffusion: true);
    addParticles(ParticleSpecies.light, 30, side: 0);
    addParticles(ParticleSpecies.heavy, 30, side: 1);
    _finishReset();
  }

  void _resetState({
    required double volume,
    required ConstantMode mode,
    required bool diffusion,
  }) {
    particles.clear();
    volumeL = volume;
    _targetVolumeL = volume;
    _temperatureK = 300.0;
    _lockedTemperatureK = 300.0;
    gravity = 0;
    constantMode = mode;
    diffusionMode = diffusion;
    barrierOpen = false;
    heaterLevel = 0;
    simTime = 0;
    totalCollisions = 0;
    collisionRate = 0;
    workOnGasJ = 0;
    _collisionWindow = 0;
    _collisionsInWindow = 0;
    _historyClock = 0;
    _lastHistoryPoint = -1;
    history.clear();
  }

  void _finishReset() {
    _scaleTemperatureTo(300.0);
    _pressureSim = _kineticPressure();
    _lockedKineticPressure = _pressureSim;
    _recordHistory(force: true);
  }

  void setConstantMode(ConstantMode mode) {
    constantMode = mode;
    _targetVolumeL = volumeL;
    _lockedTemperatureK = _temperatureK;
    _lockedKineticPressure = _kineticPressure();
  }

  /// O volume só pode ser alterado à mão quando não está travado
  /// (nem diretamente, nem indiretamente por "Pressão ↕V").
  bool get volumeEditable =>
      constantMode != ConstantMode.volume &&
      constantMode != ConstantMode.pressure;

  /// A temperatura só pode ser alterada à mão quando não está travada
  /// (nem diretamente, nem indiretamente por "Pressão ↕T").
  bool get temperatureEditable =>
      constantMode != ConstantMode.temperature &&
      constantMode != ConstantMode.pressureT;

  /// Define para onde a tampa deve ir. Ela se desloca com velocidade finita
  /// e realiza trabalho sobre as partículas que encontra no caminho.
  void setVolume(double value) {
    if (!volumeEditable) return;
    _targetVolumeL = value.clamp(_minVolumeL, 5.0).toDouble();
  }

  /// Ajuste direto da temperatura (termostato): reescala as velocidades.
  void setTemperature(double value) {
    if (!temperatureEditable) return;
    _scaleTemperatureTo(value);
  }

  void heat(double deltaK) => setTemperature(_temperatureK + deltaK);
  void cool(double deltaK) => setTemperature(_temperatureK - deltaK);

  void setGravity(double value) {
    gravity = value.clamp(0.0, 1.0);
  }

  void addParticles(
    ParticleSpecies species,
    int count, {
    int side = -1,
    bool adjustConstants = true,
  }) {
    final top = pistonY;
    final isLight = species == ParticleSpecies.light;
    final radius = isLight ? lightRadius : heavyRadius;
    final mass = massOf(species);
    final sigma = math.sqrt(kSim * _temperatureK / mass);
    final gasArea = areaPerL * volumeL;

    for (int i = 0; i < count; i++) {
      // A câmara não aceita mais partículas do que cabem nela.
      if ((_diskArea() + math.pi * radius * radius) / gasArea > maxPacking) {
        break;
      }

      double minX = wallLeft + radius;
      double maxX = wallRight - radius;

      if (diffusionMode && !barrierOpen) {
        if (side == 0) {
          maxX = 0.5 - 0.012 - radius;
        } else if (side == 1) {
          minX = 0.5 + 0.012 + radius;
        }
      }

      final minY = top + radius;
      final maxY = wallBottom - radius;

      particles.add(
        GasParticle(
          position: Offset(
            minX + _random.nextDouble() * (maxX - minX),
            minY + _random.nextDouble() * math.max(0.0, maxY - minY),
          ),
          // Maxwell-Boltzmann: cada componente da velocidade é gaussiana
          // com variância kT/m.
          velocity: Offset(_gaussian() * sigma, _gaussian() * sigma),
          species: species,
          radius: radius,
          mass: mass,
        ),
      );
    }

    _measureTemperature();
  }

  void removeParticles(ParticleSpecies species, int count) {
    int remaining = count;

    for (int i = particles.length - 1; i >= 0 && remaining > 0; i--) {
      if (particles[i].species == species) {
        particles.removeAt(i);
        remaining--;
      }
    }

    _measureTemperature();
  }

  /// Botão "borracha": esvazia a câmara.
  void clearParticles() {
    particles.clear();
    _pressureSim = 0;
    _lockedKineticPressure = 0;
    collisionRate = 0;
  }

  void toggleBarrier() {
    if (!diffusionMode) return;
    barrierOpen = !barrierOpen;
  }

  /// Avança exatamente um quadro (botão "passo"), mesmo pausado.
  void step([double dt = 1 / 60]) {
    final wasPaused = paused;
    paused = false;
    update(dt);
    paused = wasPaused;
  }

  void update(double dt) {
    if (paused) return;
    if (dt <= 0 || dt > 0.05) dt = 0.016;

    const substeps = 4;
    final h = dt / substeps;
    for (int i = 0; i < substeps; i++) {
      _advance(h);
    }

    _historyClock += dt;
    _recordHistory();
  }

  void _advance(double dt) {
    simTime += dt;

    _applyVolumeLock();
    final lidVelocity = _moveLid(dt);

    final top = pistonY;
    final heating = heaterLevel != 0 && temperatureEditable;

    int collisions = 0;
    double impulse = 0;
    double lidWork = 0;

    for (final p in particles) {
      final r = p.radius;
      final m = p.mass;

      double vx = p.velocity.dx;
      double vy = p.velocity.dy + gravity * _gravityAccel * dt;
      double x = p.position.dx + vx * dt;
      double y = p.position.dy + vy * dt;

      if (x - r <= wallLeft) {
        x = wallLeft + r;
        if (vx < 0) {
          impulse += 2 * m * -vx;
          vx = -vx;
          collisions++;
        }
      } else if (x + r >= wallRight) {
        x = wallRight - r;
        if (vx > 0) {
          impulse += 2 * m * vx;
          vx = -vx;
          collisions++;
        }
      }

      if (y - r <= top) {
        // Tampa: reflexão no referencial da tampa em movimento.
        y = top + r;
        if (vy < lidVelocity) {
          final after = 2 * lidVelocity - vy;
          impulse += m * (after - vy);
          lidWork += 0.5 * m * (after * after - vy * vy);
          vy = after;
          collisions++;
        }
      } else if (y + r >= wallBottom) {
        y = wallBottom - r;
        if (vy > 0) {
          final before = vy;
          vy = -vy;

          if (heating) {
            // Piso quente/frio: muda a energia só de quem toca o fundo.
            double factor = 1.0;
            if (heaterLevel > 0 && _temperatureK < maxTemperatureK) {
              factor = 1.0 + 0.25 * heaterLevel;
            } else if (heaterLevel < 0 && _temperatureK > minTemperatureK) {
              factor = 1.0 + 0.2 * heaterLevel;
            }
            final s = math.sqrt(factor);
            vx *= s;
            vy *= s;
          }

          impulse += m * (before - vy);
          collisions++;
        }
      }

      p.position = Offset(x, y);
      p.velocity = Offset(vx, vy);

      if (diffusionMode && !barrierOpen) {
        _collideWithClosedBarrier(p);
      }
    }

    _resolveParticleCollisions();

    workOnGasJ += lidWork * joulePerSim;

    _measureTemperature();
    _applyThermostat();

    // Pressão = impulso por tempo por comprimento de parede (média móvel).
    final perimeter = 2 * (chamberWidth + heightPerL * volumeL);
    final instant = impulse / (dt * perimeter);
    _pressureSim +=
        (instant - _pressureSim) * (1 - math.exp(-dt / _pressureTau));

    totalCollisions += collisions;
    _collisionsInWindow += collisions;
    _collisionWindow += dt;

    if (_collisionWindow >= 0.45) {
      collisionRate = _collisionsInWindow / _collisionWindow;
      _collisionWindow = 0;
      _collisionsInWindow = 0;
    }
  }

  /// "Pressão ↕V": a tampa procura o volume que mantém a pressão travada.
  void _applyVolumeLock() {
    if (constantMode == ConstantMode.volume) {
      _targetVolumeL = volumeL;
    } else if (constantMode == ConstantMode.pressure &&
        _lockedKineticPressure > 0 &&
        particles.isNotEmpty) {
      final desired = particles.length *
          kSim *
          _temperatureK /
          (_lockedKineticPressure * areaPerL);
      _targetVolumeL = desired.clamp(_minVolumeL, 5.0).toDouble();
    }
  }

  /// Move a tampa em direção ao alvo e devolve a velocidade dela
  /// (unidades normalizadas por segundo, positiva para baixo).
  double _moveLid(double dt) {
    final target = _targetVolumeL.clamp(_minVolumeL, 5.0).toDouble();
    final maxStep = maxLidSpeed * dt;
    final dv = (target - volumeL).clamp(-maxStep, maxStep).toDouble();
    if (dv == 0) return 0;

    volumeL += dv;
    return -heightPerL * dv / dt;
  }

  /// Termostatos dos modos de temperatura constante e de "Pressão ↕T".
  void _applyThermostat() {
    if (particles.isEmpty) return;

    if (constantMode == ConstantMode.temperature) {
      _scaleTemperatureTo(_lockedTemperatureK);
    } else if (constantMode == ConstantMode.pressureT &&
        _lockedKineticPressure > 0) {
      final desired = _lockedKineticPressure *
          areaPerL *
          volumeL /
          (particles.length * kSim);
      _scaleTemperatureTo(desired);
    } else if (_temperatureK > maxTemperatureK) {
      // Válvula de segurança: a câmara não passa do limite do termômetro.
      _scaleTemperatureTo(maxTemperatureK);
    }
  }

  void _collideWithClosedBarrier(GasParticle p) {
    const barrierX = 0.5;
    const halfThickness = 0.012;

    final fromLeft = p.velocity.dx > 0;
    final fromRight = p.velocity.dx < 0;

    if (fromLeft &&
        p.position.dx + p.radius >= barrierX - halfThickness &&
        p.position.dx < barrierX) {
      p.position = Offset(
        barrierX - halfThickness - p.radius,
        p.position.dy,
      );
      p.velocity = Offset(-p.velocity.dx.abs(), p.velocity.dy);
    } else if (fromRight &&
        p.position.dx - p.radius <= barrierX + halfThickness &&
        p.position.dx > barrierX) {
      p.position = Offset(
        barrierX + halfThickness + p.radius,
        p.position.dy,
      );
      p.velocity = Offset(p.velocity.dx.abs(), p.velocity.dy);
    }
  }

  /// Colisões elásticas entre partículas (conservam momento e energia).
  void _resolveParticleCollisions() {
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final a = particles[i];
        final b = particles[j];

        final delta = b.position - a.position;
        final dist2 = delta.dx * delta.dx + delta.dy * delta.dy;
        final minDist = a.radius + b.radius;

        if (dist2 <= 0 || dist2 >= minDist * minDist) continue;

        final dist = math.sqrt(dist2);
        final n = delta / dist;
        final relative = b.velocity - a.velocity;
        final alongNormal = relative.dx * n.dx + relative.dy * n.dy;

        if (alongNormal < 0) {
          final m1 = a.mass;
          final m2 = b.mass;

          final impulse = (2 * alongNormal) / (m1 + m2);

          a.velocity = a.velocity + n * (impulse * m2);
          b.velocity = b.velocity - n * (impulse * m1);
        }

        final overlap = minDist - dist;
        a.position -= n * (overlap / 2);
        b.position += n * (overlap / 2);
      }
    }
  }

  double _kineticEnergy() {
    double sum = 0;
    for (final p in particles) {
      sum += 0.5 * p.mass * p.velocity.distanceSquared;
    }
    return sum;
  }

  void _measureTemperature() {
    if (particles.isEmpty) return;
    _temperatureK = _kineticEnergy() / (particles.length * kSim);
  }

  void _scaleTemperatureTo(double value) {
    final next = value.clamp(minTemperatureK, maxTemperatureK).toDouble();

    if (particles.isNotEmpty) {
      _measureTemperature();
      if (_temperatureK > 0) {
        final factor = math.sqrt(next / _temperatureK);
        for (final p in particles) {
          p.velocity = p.velocity * factor;
        }
      }
    }

    _temperatureK = next;
  }

  /// Pressão cinética do gás ideal (N·k·T / área), nas unidades da simulação.
  double _kineticPressure() {
    if (particles.isEmpty) return 0;
    return particles.length * kSim * _temperatureK / (areaPerL * volumeL);
  }

  double _diskArea() {
    double sum = 0;
    for (final p in particles) {
      sum += math.pi * p.radius * p.radius;
    }
    return sum;
  }

  /// Menor volume em que as partículas ainda cabem.
  double get _minVolumeL => math
      .max(1.0, _diskArea() / (maxPacking * areaPerL))
      .clamp(1.0, 5.0)
      .toDouble();

  double _gaussian() {
    final u1 = math.max(_random.nextDouble(), 1e-12);
    final u2 = _random.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  void _recordHistory({bool force = false}) {
    if (!force && _historyClock - _lastHistoryPoint < 0.15) return;

    history.add(
      SimulationSample(
        time: _historyClock,
        pressureKPa: pressureKPa,
        volumeL: volumeL,
        temperatureK: temperatureK,
      ),
    );

    _lastHistoryPoint = _historyClock;

    while (history.length > 120) {
      history.removeAt(0);
    }
  }
}
