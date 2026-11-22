import 'dart:math' as math;

/// Estado macroscópico de um gás ideal em um processo isotérmico.
///
/// Todas as pressões internas são ABSOLUTAS. O manômetro lê a diferença
/// entre a pressão absoluta do gás e a pressão atmosférica externa.
/// O volume apresentado ao estudante está em mL; o SI usa m³.
class BoyleSample {
  final double timeS;
  final double volumeMl;
  final double absolutePressurePa;
  final double gaugePressurePa;
  final double pvJ;

  const BoyleSample({
    required this.timeS,
    required this.volumeMl,
    required this.absolutePressurePa,
    required this.gaugePressurePa,
    required this.pvJ,
  });
}

class BoyleEngine {
  static const double gasConstant = 8.314462618;
  static const double standardPressurePa = 101325.0;
  static const double gravity = 9.80665;
  static const double airMolarMass = 0.0289644; // kg/mol
  static const double minimumFraction = 0.60;
  static const double pistonSpeedMlS = 1.8;

  double initialVolumeMl = 10.0;
  double temperatureC = 35.0;
  double altitudeM = 225.0;

  double volumeMl = 10.0;
  double targetVolumeMl = 10.0;
  double timeS = 0.0;
  bool running = false;

  final List<BoyleSample> readings = [];

  BoyleEngine() {
    resetExperiment();
  }

  double get temperatureK => temperatureC + 273.15;
  double get minVolumeMl => initialVolumeMl * minimumFraction;
  double get compression => (initialVolumeMl - volumeMl) / initialVolumeMl;

  /// Modelo barométrico isotérmico, utilizando a temperatura ambiente do
  /// experimento; é uma estimativa, não uma leitura de barômetro real.
  double get atmosphericPressurePa => standardPressurePa *
      math.exp(-airMolarMass * gravity * altitudeM /
          (gasConstant * temperatureK));

  /// Quantidade de matéria escolhida para P_inicial = P_atmosférica.
  double get moles => atmosphericPressurePa * (initialVolumeMl * 1e-6) /
      (gasConstant * temperatureK);

  double get absolutePressurePa =>
      moles * gasConstant * temperatureK / (volumeMl * 1e-6);

  double get gaugePressurePa => absolutePressurePa - atmosphericPressurePa;
  double get absolutePressureKPa => absolutePressurePa / 1000.0;
  double get gaugePressureKPa => gaugePressurePa / 1000.0;
  double get pvJ => absolutePressurePa * volumeMl * 1e-6;
  double get initialPVJ => atmosphericPressurePa * initialVolumeMl * 1e-6;

  double get relativePVErrorPercent =>
      initialPVJ == 0 ? 0 : 100 * (pvJ / initialPVJ - 1).abs();

  double pressureAtVolumePa(double ml) =>
      atmosphericPressurePa * initialVolumeMl / ml;

  void setInitialVolume(double ml) {
    initialVolumeMl = ml.clamp(8.0, 12.0).toDouble();
    resetExperiment();
  }

  void setTemperature(double celsius) {
    temperatureC = celsius.clamp(0.0, 80.0).toDouble();
    resetExperiment();
  }

  void setAltitude(double meters) {
    altitudeM = meters.clamp(0.0, 3000.0).toDouble();
    resetExperiment();
  }

  void resetDefaults() {
    initialVolumeMl = 10.0;
    temperatureC = 35.0;
    altitudeM = 225.0;
    resetExperiment();
  }

  void resetExperiment() {
    volumeMl = initialVolumeMl;
    targetVolumeMl = initialVolumeMl;
    timeS = 0;
    running = false;
    readings.clear();
    registerReading(); // A condição inicial é a primeira referência.
  }

  void start() => running = true;
  void pause() => running = false;

  void setTargetVolume(double ml) {
    targetVolumeMl = ml.clamp(minVolumeMl, initialVolumeMl).toDouble();
  }

  void changeTargetVolume(double deltaMl) =>
      setTargetVolume(targetVolumeMl + deltaMl);

  void update(double dt) {
    if (!running || !dt.isFinite || dt <= 0) return;
    final step = dt.clamp(0.0, 0.05).toDouble();
    timeS += step;
    final delta = (targetVolumeMl - volumeMl)
        .clamp(-pistonSpeedMlS * step, pistonSpeedMlS * step)
        .toDouble();
    volumeMl += delta;
    if ((targetVolumeMl - volumeMl).abs() < 1e-8) {
      volumeMl = targetVolumeMl;
    }
  }

  bool registerReading() {
    // Evita várias leituras idênticas causadas por múltiplos cliques.
    if (readings.any((r) => (r.volumeMl - volumeMl).abs() < 0.04)) {
      return false;
    }
    readings.add(BoyleSample(
      timeS: timeS,
      volumeMl: volumeMl,
      absolutePressurePa: absolutePressurePa,
      gaugePressurePa: gaugePressurePa,
      pvJ: pvJ,
    ));
    readings.sort((a, b) => b.volumeMl.compareTo(a.volumeMl));
    return true;
  }
}
