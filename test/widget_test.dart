import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:physgame_gas_lab/main.dart';
import 'package:physgame_gas_lab/simulation/gas_engine.dart';
import 'package:physgame_gas_lab/simulation/gas_particle.dart';
import 'package:physgame_gas_lab/widgets/lab/lab_painters.dart';
import 'package:physgame_gas_lab/widgets/lab/lab_stage.dart';

void run(GasEngine engine, double seconds) {
  final steps = (seconds * 60).round();
  for (int i = 0; i < steps; i++) {
    engine.update(1 / 60);
  }
}

double averagePressure(GasEngine engine, double seconds) {
  final steps = (seconds * 60).round();
  double sum = 0;
  for (int i = 0; i < steps; i++) {
    engine.update(1 / 60);
    sum += engine.pressureKPa;
  }
  return sum / steps;
}

void main() {
  test('estado inicial: 300 K, 4 L e pressão do gás ideal', () {
    final engine = GasEngine();

    expect(engine.totalCount, GasEngine.defaultCount);
    expect(engine.temperatureK, closeTo(300, 1e-6));
    expect(engine.volumeL, 4.0);
    expect(engine.idealPressureKPa, closeTo(49.9, 0.1));
    expect(engine.pressureKPa, closeTo(engine.idealPressureKPa, 0.1));
  });

  test('paredes paradas conservam a energia', () {
    final engine = GasEngine();
    run(engine, 20);

    expect(engine.temperatureK, closeTo(300, 1e-3));
    expect(engine.workOnGasJ, 0);
  });

  test('pressão medida pelas colisões fica perto do gás ideal', () {
    final engine = GasEngine();
    run(engine, 5);
    final measured = averagePressure(engine, 60);
    final ideal = engine.idealPressureKPa;

    // Partículas com tamanho finito dão pressão um pouco acima da ideal.
    expect(measured, greaterThan(ideal * 0.95));
    expect(measured, lessThan(ideal * 1.30));
  });

  test('compressão sem troca de calor aquece o gás', () {
    final engine = GasEngine();
    engine.setVolume(2.0);
    run(engine, 4);

    expect(engine.volumeL, closeTo(2.0, 1e-6));
    expect(engine.temperatureK, greaterThan(450));
    expect(engine.workOnGasJ, greaterThan(0));

    // Primeira lei: todo o trabalho virou energia interna.
    final initialEnergy =
        engine.moles * GasEngine.gasConstant * 300.0;
    expect(
      engine.internalEnergyJ - initialEnergy,
      closeTo(engine.workOnGasJ, 1e-3),
    );
  });

  test('expansão sem troca de calor esfria o gás', () {
    final engine = GasEngine();
    engine.setVolume(5.0);
    run(engine, 4);

    expect(engine.temperatureK, lessThan(295));
    expect(engine.workOnGasJ, lessThan(0));
  });

  test('temperatura constante: comprimir dobra a pressão (Boyle)', () {
    final engine = GasEngine();
    engine.setConstantMode(ConstantMode.temperature);
    engine.setVolume(2.0);
    run(engine, 6);

    expect(engine.temperatureK, closeTo(300, 1e-6));
    final measured = averagePressure(engine, 60);
    expect(measured, greaterThan(49.9 * 1.8));
    expect(measured, lessThan(49.9 * 2.9));
  });

  test('pressão constante: aquecer expande o gás (Charles)', () {
    final engine = GasEngine();
    engine.setVolume(3.0);
    engine.setConstantMode(ConstantMode.temperature);
    run(engine, 3);
    engine.setConstantMode(ConstantMode.pressure);
    engine.setTemperature(400);
    run(engine, 15);

    expect(engine.volumeL, greaterThan(3.3));
  });

  test('aquecedor no piso aumenta a temperatura', () {
    final engine = GasEngine();
    engine.setConstantMode(ConstantMode.volume);
    engine.heaterLevel = 1;
    run(engine, 3);

    expect(engine.temperatureK, greaterThan(330));
  });

  test('partículas leves são mais rápidas que as pesadas', () {
    final engine = GasEngine();
    run(engine, 20);

    expect(
      engine.averageSpeedFor(ParticleSpecies.light),
      greaterThan(engine.averageSpeedFor(ParticleSpecies.heavy) * 1.5),
    );
  });

  // Qualquer estouro de layout (overflow) faz o teste falhar.
  for (final size in const [
    Size(1920, 991),
    Size(1440, 900),
    Size(1366, 768),
    Size(1000, 700),
    Size(390, 800),
    Size(360, 640),
  ]) {
    testWidgets(
        'todas as abas cabem em ${size.width.round()}x${size.height.round()}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const PhysGameGasLabApp());
      await tester.pump(const Duration(milliseconds: 50));

      for (final tab in ['Energia', 'Difusão', 'Missão', 'Exploração']) {
        await tester.tap(find.text(tab));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.tap(find.text('Missão'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Começar'));
      await tester.tap(find.text('Começar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ETAPA 1 DE 4'), findsOneWidget);
    });
  }

  testWidgets('passar o mouse na tampa mostra o pop-up de dica',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhysGameGasLabApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Tampa móvel'), findsNothing);

    // Converte um ponto do palco (760 x 600) para a tela.
    final stage = tester.getRect(find.byType(LabStage));
    final scale = stage.width / StageGeometry.width;
    Offset onStage(Offset p) => stage.topLeft + p * scale;

    final engine = GasEngine();
    final lid = StageGeometry.lidHit(engine).center;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    await mouse.moveTo(onStage(lid));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Tampa móvel'), findsOneWidget);
    expect(
      find.textContaining('cria uma variação de pressão'),
      findsOneWidget,
    );

    await mouse.moveTo(onStage(StageGeometry.gaugeCenter));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Manômetro'), findsOneWidget);
    expect(find.text('Tampa móvel'), findsNothing);

    // Um ponto vazio do palco não mostra dica.
    await mouse.moveTo(onStage(const Offset(700, 30)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Manômetro'), findsNothing);
  });

  testWidgets('o app abre com as quatro abas', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhysGameGasLabApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Exploração'), findsOneWidget);
    expect(find.text('Energia'), findsOneWidget);
    expect(find.text('Difusão'), findsOneWidget);
    expect(find.text('Missão'), findsOneWidget);
  });
}
