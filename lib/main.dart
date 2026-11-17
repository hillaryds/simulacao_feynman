import 'package:flutter/material.dart';
import 'core/physgame_theme.dart';
import 'screens/gas_lab_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhysGameGasLabApp());
}

class PhysGameGasLabApp extends StatelessWidget {
  const PhysGameGasLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PhysGame Lab',
      theme: PhysGameTheme.dark,
      home: const GasLabScreen(),
    );
  }
}
