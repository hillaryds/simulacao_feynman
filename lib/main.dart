import 'package:flutter/material.dart';
import 'core/physgame_theme.dart';
import 'screens/gas_lab_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Na web, abrir com "?tema=claro" já inicia no tema branco.
  if (Uri.base.queryParameters['tema'] == 'claro') {
    PhysGameColors.lightMode.value = true;
  }

  runApp(const PhysGameGasLabApp());
}

class PhysGameGasLabApp extends StatelessWidget {
  const PhysGameGasLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Reconstrói o app quando o usuário troca entre tema escuro e claro.
    return ValueListenableBuilder<bool>(
      valueListenable: PhysGameColors.lightMode,
      builder: (context, lightMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PhysGame Lab',
          theme: PhysGameTheme.of(PhysGameColors.palette),
          home: const GasLabScreen(),
        );
      },
    );
  }
}
