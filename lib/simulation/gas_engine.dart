import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gas_particle.dart';

enum ConstantMode { none, volume, temperature, pressure }

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

class GasEngine {
  static const double gasConstant = 8.314462618;
  static const double molPerParticle = 0.0025;

  final math.Random _random = math.Random(2026);
  final List<GasParticle> particles = [];
  final List<SimulationSample> history = [];

  double volumeL = 4.0;
  double temperatureK = 300.0;
  double gravity = 0.0;

  ConstantMode constantMode = ConstantMode.none;
  double _lockedPressureKPa = 0.0;

  bool diffusionMode = false;
  bool barrierOpen = false;

  double collisionRate = 0.0;
  double workOnGasJ = 0.0;

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

  double get pressurePa {
    if (particles.isEmpty || volumeL <= 0) return 0;
    return moles * gasConstant * temperatureK / (volumeL / 1000.0);
  }

  double get pressureKPa => pressurePa / 1000.0;
  double get pressureMmHg => pressurePa / 133.322;

  double get pistonY {
    final normalized = ((volumeL - 1.0) / 4.0).clamp(0.0, 1.0);
    return 0.69 - normalized * 0.56;
  }

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

  void resetExplore() {
    particles.clear();
    volumeL = 4.0;
    temperatureK = 300.0;
    gravity = 0;
    constantMode = ConstantMode.none;
    diffusionMode = false;
    barrierOpen = false;
    collisionRate = 0;
    workOnGasJ = 0;
    _collisionWindow = 0;
    _collisionsInWindow = 0;
    _historyClock = 0;
    _lastHistoryPoint = -1;
    history.clear();
    addParticles(ParticleSpecies.light, 20, side: -1, adjustConstants: false);
    addParticles(ParticleSpecies.heavy, 12, side: -1, adjustConstants: false);
    _recordHistory(force: true);
  }

  void resetDiffusion() {
    particles.clear();
    volumeL = 5.0;
    temperatureK = 300.0;
    gravity = 0;
    constantMode = ConstantMode.volume;
    diffusionMode = true;
    barrierOpen = false;
    collisionRate = 0;
    workOnGasJ = 0;
    _collisionWindow = 0;
    _collisionsInWindow = 0;
    _historyClock = 0;
    _lastHistoryPoint = -1;
    history.clear();
    addParticles(ParticleSpecies.light, 18, side: 0, adjustConstants: false);
    addParticles(ParticleSpecies.heavy, 18, side: 1, adjustConstants: false);
    _recordHistory(force: true);
  }

  void setConstantMode(ConstantMode mode) {
    constantMode = mode;
    if (mode == ConstantMode.pressure) {
      _lockedPressureKPa = pressureKPa;
    }
  }

  void setVolume(double value) {
    if (constantMode == ConstantMode.volume) return;

    final oldVolume = volumeL;
    final oldPressure = pressurePa;

    volumeL = value.clamp(1.0, 5.0);

    final dV = (volumeL - oldVolume) / 1000.0;
    final newPressure = pressurePa;
    final averagePressure = (oldPressure + newPressure) / 2.0;

    // W_on = -∫P dV. Compressão => dV < 0 => trabalho sobre o gás > 0.
    workOnGasJ += -averagePressure * dV;

    _keepParticlesBelowPiston();
  }

  void setTemperature(double value) {
    if (constantMode == ConstantMode.temperature) return;

    final oldT = temperatureK;
    final nextT = value.clamp(180.0, 650.0);

    if (oldT > 0) {
      final factor = math.sqrt(nextT / oldT);
      for (final p in particles) {
        p.velocity = p.velocity * factor;
      }
    }

    temperatureK = nextT;
    _applyPressureLockIfNeeded();
  }

  void heat(double deltaK) => setTemperature(temperatureK + deltaK);
  void cool(double deltaK) => setTemperature(temperatureK - deltaK);

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

    for (int i = 0; i < count; i++) {
      final isLight = species == ParticleSpecies.light;
      final radius = isLight ? 0.013 : 0.017;
      final mass = isLight ? 1.0 : 4.0;

      double minX = 0.07;
      double maxX = 0.93;

      if (diffusionMode && !barrierOpen) {
        if (side == 0) {
          maxX = 0.46;
        } else if (side == 1) {
          minX = 0.54;
        }
      }

      final x = minX + _random.nextDouble() * (maxX - minX);
      final y = top + 0.07 + _random.nextDouble() * math.max(0.06, 0.90 - top);

      final angle = _random.nextDouble() * math.pi * 2;
      final thermal = math.sqrt(temperatureK / (300.0 * mass));
      final baseSpeed = (0.18 + _random.nextDouble() * 0.10) * thermal;

      particles.add(
        GasParticle(
          position: Offset(
            x.clamp(0.05 + radius, 0.95 - radius),
            y.clamp(top + radius, 0.97 - radius),
          ),
          velocity: Offset(
            math.cos(angle) * baseSpeed,
            math.sin(angle) * baseSpeed,
          ),
          species: species,
          radius: radius,
          mass: mass,
        ),
      );
    }

    if (adjustConstants) {
      _applyPressureLockIfNeeded();
    }
  }

  void removeParticles(ParticleSpecies species, int count) {
    int remaining = count;

    for (int i = particles.length - 1; i >= 0 && remaining > 0; i--) {
      if (particles[i].species == species) {
        particles.removeAt(i);
        remaining--;
      }
    }

    _applyPressureLockIfNeeded();
  }

  void toggleBarrier() {
    if (!diffusionMode) return;
    barrierOpen = !barrierOpen;
  }

  void update(double dt) {
    if (dt <= 0 || dt > 0.05) dt = 0.016;

    final top = pistonY;
    const left = 0.03;
    const right = 0.97;
    const bottom = 0.97;

    int collisions = 0;

    for (final p in particles) {
      p.velocity = Offset(
        p.velocity.dx,
        p.velocity.dy + gravity * 0.11 * dt,
      );

      p.position += p.velocity * dt;

      if (p.position.dx - p.radius <= left) {
        p.position = Offset(left + p.radius, p.position.dy);
        p.velocity = Offset(p.velocity.dx.abs(), p.velocity.dy);
        collisions++;
      } else if (p.position.dx + p.radius >= right) {
        p.position = Offset(right - p.radius, p.position.dy);
        p.velocity = Offset(-p.velocity.dx.abs(), p.velocity.dy);
        collisions++;
      }

      if (p.position.dy - p.radius <= top) {
        p.position = Offset(p.position.dx, top + p.radius);
        p.velocity = Offset(p.velocity.dx, p.velocity.dy.abs());
        collisions++;
      } else if (p.position.dy + p.radius >= bottom) {
        p.position = Offset(p.position.dx, bottom - p.radius);
        p.velocity = Offset(p.velocity.dx, -p.velocity.dy.abs());
        collisions++;
      }

      if (diffusionMode && !barrierOpen) {
        _collideWithClosedBarrier(p);
      }
    }

    _resolveParticleCollisions();

    _collisionsInWindow += collisions;
    _collisionWindow += dt;

    if (_collisionWindow >= 0.45) {
      collisionRate = _collisionsInWindow / _collisionWindow;
      _collisionWindow = 0;
      _collisionsInWindow = 0;
    }

    _historyClock += dt;
    _recordHistory();
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

  void _keepParticlesBelowPiston() {
    final top = pistonY;

    for (final p in particles) {
      final minY = top + p.radius;
      if (p.position.dy < minY) {
        p.position = Offset(p.position.dx, minY);
        p.velocity = Offset(p.velocity.dx, p.velocity.dy.abs());
      }
    }
  }

  void _applyPressureLockIfNeeded() {
    if (constantMode != ConstantMode.pressure || _lockedPressureKPa <= 0) {
      return;
    }

    if (particles.isEmpty) return;

    final desiredVolumeM3 =
        moles * gasConstant * temperatureK / (_lockedPressureKPa * 1000.0);

    volumeL = (desiredVolumeM3 * 1000.0).clamp(1.0, 5.0);
    _keepParticlesBelowPiston();
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
