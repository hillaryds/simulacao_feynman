import 'package:flutter_test/flutter_test.dart';
import '../lib/simulation/boyle_engine.dart';

void main() {
  test('Estado inicial corresponde à pressão atmosférica', () {
    final e = BoyleEngine();
    expect(e.initialVolumeMl, 10);
    expect(e.temperatureC, 35);
    expect(e.altitudeM, 225);
    expect(e.gaugePressurePa.abs(), lessThan(1e-6));
    expect(e.absolutePressurePa, closeTo(e.atmosphericPressurePa, 1e-6));
    expect(e.moles, closeTo(0.000385, 0.000002));
  });

  test('Boyle: comprimir de 10 para 6 mL eleva a pressão por 10/6', () {
    final e = BoyleEngine();
    final initialPressure = e.absolutePressurePa;
    final initialPV = e.pvJ;
    e.setTargetVolume(6.0);
    e.start();
    for (var i = 0; i < 200; i++) {
      e.update(0.04);
    }
    expect(e.volumeMl, closeTo(6.0, 1e-8));
    expect(e.absolutePressurePa / initialPressure, closeTo(10 / 6, 1e-10));
    expect(e.pvJ, closeTo(initialPV, 1e-10));
    expect(e.gaugePressurePa, greaterThan(0));
  });

  test('Registro ignora leituras repetidas e reinício limpa a tabela', () {
    final e = BoyleEngine();
    expect(e.readings.length, 1);
    expect(e.registerReading(), isFalse);
    e.setTargetVolume(8);
    e.start();
    for (var i = 0; i < 150; i++) {
      e.update(0.05);
    }
    expect(e.registerReading(), isTrue);
    expect(e.readings.length, 2);
    e.resetExperiment();
    expect(e.readings.length, 1);
    expect(e.running, isFalse);
  });

  test('Barômetro: ao nível do mar retorna 101325 Pa', () {
    final e = BoyleEngine();
    e.setAltitude(0);
    expect(e.atmosphericPressurePa, closeTo(101325, 1e-6));
  });
}
