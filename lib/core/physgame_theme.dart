import 'package:flutter/material.dart';

class PhysGameColors {
  static const purple = Color(0xFF5E4AE3);
  static const purple2 = Color(0xFF7567F0);
  static const purpleSoft = Color(0xFFF2EFFF);
  static const orange = Color(0xFFF97316);
  static const amber = Color(0xFFFBBF24);
  static const navy = Color(0xFF101828);
  static const slate = Color(0xFF475467);
  static const border = Color(0xFFE7E7EF);
  static const canvas = Color(0xFFF7F7FB);
  static const success = Color(0xFF12B76A);
  static const danger = Color(0xFFF04438);

  static const lightParticle = Color(0xFF6D5EF6);
  static const heavyParticle = Color(0xFFF97316);

  // ── Palco estilo PhET ────────────────────────────────────────────────
  /// Fundo do palco (o "preto" do PhET, na paleta navy do PhysGame).
  static const stage = Color(0xFF101828);

  /// Interior do gás (topo → base).
  static const gasTop = Color(0xFF0B1020);
  static const gasBottom = Color(0xFF1A1545);

  /// Painéis laterais escuros.
  static const panel = Color(0xFF1D2939);
  static const panelBorder = Color(0xFF344054);

  /// Metais (tampa, tubos, bomba, balde).
  static const metalLight = Color(0xFFF2F4F7);
  static const metalMid = Color(0xFFD0D5DD);
  static const metalDark = Color(0xFF98A2B3);
  static const metalEdge = Color(0xFF667085);

  /// Vidro/mercúrio do termômetro e ponteiro do manômetro.
  static const mercury = Color(0xFFF04438);

  /// Controle de aquecer / arrefecer.
  static const heatColor = Color(0xFFF97316);
  static const coolColor = Color(0xFF2E90FA);
  static const knob = Color(0xFF67D4EE);
  static const knobEdge = Color(0xFF0E7490);
}

class PhysGameTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: PhysGameColors.purple,
      primary: PhysGameColors.purple,
      secondary: PhysGameColors.orange,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: PhysGameColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: PhysGameColors.navy,
        elevation: 0,
        centerTitle: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PhysGameColors.purple,
        inactiveTrackColor: PhysGameColors.purple.withOpacity(.14),
        thumbColor: PhysGameColors.purple,
        overlayColor: PhysGameColors.purple.withOpacity(.10),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PhysGameColors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PhysGameColors.purple,
          side: const BorderSide(color: PhysGameColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
