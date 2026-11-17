import 'package:flutter/material.dart';

/// Conjunto de cores que muda entre o tema escuro e o tema claro.
class PhysGamePalette {
  final Brightness brightness;

  /// Fundo da página.
  final Color bg;

  /// Cartões e painéis.
  final Color surface;

  /// Blocos internos dos cartões (leituras, campos, botões neutros).
  final Color surfaceHi;

  /// Bordas e linhas divisórias.
  final Color line;

  /// Texto principal e secundário.
  final Color text;
  final Color muted;

  /// Roxo para títulos pequenos e valores em destaque.
  final Color accentText;

  /// Laranja para a curva das partículas pesadas.
  final Color heavyAccent;

  /// Textos de aviso: certo, atenção, errado e XP.
  final Color okText;
  final Color warnText;
  final Color badText;
  final Color xpText;

  /// Fundo do palco e interior do gás (topo → base).
  final Color stage;
  final Color gasTop;
  final Color gasBottom;

  /// Paredes da câmara, contorno do cilindro vazio e vidro do termômetro.
  final Color wall;
  final Color ghost;
  final Color glass;

  const PhysGamePalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.line,
    required this.text,
    required this.muted,
    required this.accentText,
    required this.heavyAccent,
    required this.okText,
    required this.warnText,
    required this.badText,
    required this.xpText,
    required this.stage,
    required this.gasTop,
    required this.gasBottom,
    required this.wall,
    required this.ghost,
    required this.glass,
  });

  static const dark = PhysGamePalette(
    brightness: Brightness.dark,
    bg: Color(0xFF080D1A),
    surface: Color(0xFF111A2C),
    surfaceHi: Color(0xFF1A2540),
    line: Color(0xFF263350),
    text: Color(0xFFE8ECF4),
    muted: Color(0xFF94A1B8),
    accentText: Color(0xFFB4ABFF),
    heavyAccent: Color(0xFFFDBA74),
    okText: Color(0xFF6CE9A6),
    warnText: Color(0xFFFDBA74),
    badText: Color(0xFFFDA29B),
    xpText: Color(0xFFFCD34D),
    stage: Color(0xFF101828),
    gasTop: Color(0xFF0B1020),
    gasBottom: Color(0xFF1A1545),
    wall: Color(0xFFFFFFFF),
    ghost: Color(0x38FFFFFF),
    glass: Color(0xFFD0D5DD),
  );

  static const light = PhysGamePalette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F4F9),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFEEF1F8),
    line: Color(0xFFD9DEEA),
    text: Color(0xFF101828),
    muted: Color(0xFF5B6780),
    accentText: Color(0xFF4F3CD6),
    heavyAccent: Color(0xFFC2410C),
    okText: Color(0xFF067647),
    warnText: Color(0xFFB54708),
    badText: Color(0xFFB42318),
    xpText: Color(0xFFB54708),
    stage: Color(0xFFFFFFFF),
    gasTop: Color(0xFFF4F3FF),
    gasBottom: Color(0xFFDEDAFF),
    wall: Color(0xFF1D2939),
    ghost: Color(0x401D2939),
    glass: Color(0xFF667085),
  );
}

class PhysGameColors {
  // ── Tema atual ───────────────────────────────────────────────────────
  /// true = tema claro (branco); false = tema escuro.
  static final ValueNotifier<bool> lightMode = ValueNotifier<bool>(false);

  static PhysGamePalette get palette =>
      lightMode.value ? PhysGamePalette.light : PhysGamePalette.dark;

  static Color get bg => palette.bg;
  static Color get surface => palette.surface;
  static Color get surfaceHi => palette.surfaceHi;
  static Color get line => palette.line;
  static Color get text => palette.text;
  static Color get muted => palette.muted;
  static Color get accentText => palette.accentText;
  static Color get heavyAccent => palette.heavyAccent;
  static Color get okText => palette.okText;
  static Color get warnText => palette.warnText;
  static Color get badText => palette.badText;
  static Color get xpText => palette.xpText;
  static Color get stage => palette.stage;
  static Color get gasTop => palette.gasTop;
  static Color get gasBottom => palette.gasBottom;
  static Color get wall => palette.wall;
  static Color get ghost => palette.ghost;
  static Color get glass => palette.glass;

  // ── Cores fixas (iguais nos dois temas) ──────────────────────────────
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

  /// Painéis escuros do protótipo original.
  static const panel = Color(0xFF1D2939);
  static const panelBorder = Color(0xFF344054);

  /// Metais (tampa, tubos, bomba, balde).
  static const metalLight = Color(0xFFF2F4F7);
  static const metalMid = Color(0xFFD0D5DD);
  static const metalDark = Color(0xFF98A2B3);
  static const metalEdge = Color(0xFF667085);

  /// Mercúrio do termômetro e ponteiro do manômetro.
  static const mercury = Color(0xFFF04438);

  /// Controle de aquecer / arrefecer.
  static const heatColor = Color(0xFFF97316);
  static const coolColor = Color(0xFF2E90FA);
  static const knob = Color(0xFF67D4EE);
  static const knobEdge = Color(0xFF0E7490);
}

class PhysGameTheme {
  static ThemeData get dark => of(PhysGamePalette.dark);
  static ThemeData get light => of(PhysGamePalette.light);

  /// Tema do Material montado a partir de uma paleta.
  static ThemeData of(PhysGamePalette p) {
    final isLight = p.brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: PhysGameColors.purple,
      primary: isLight ? PhysGameColors.purple : PhysGameColors.purple2,
      secondary: PhysGameColors.orange,
      surface: p.surface,
      onSurface: p.text,
      brightness: p.brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      dividerColor: p.line,
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceHi,
        textStyle: TextStyle(color: p.text),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceHi,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.line),
        ),
        textStyle: TextStyle(color: p.text, fontSize: 12),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PhysGameColors.purple2,
        inactiveTrackColor: p.line,
        thumbColor: isLight ? PhysGameColors.purple : Colors.white,
        overlayColor: PhysGameColors.purple2.withValues(alpha: .2),
        trackHeight: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PhysGameColors.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.surfaceHi,
          disabledForegroundColor: p.muted,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
