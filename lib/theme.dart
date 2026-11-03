import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF10141A);
  static const surface = Color(0xFF171C24);
  static const surface2 = Color(0xFF1F2630);
  static const border = Color(0xFF334050);
  static const line = Color(0xFF262E3A);
  static const text = Color(0xFFE8EDF2);
  static const muted = Color(0xFF9FB3C8);
  static const accent = Color(0xFFF28C28);
  static const court = Color(0xFF1A3B33);
  static const courtTile = Color(0xFF22332E);
  static const timeout = Color(0xFFE9C46A);
  static const sub = Color(0xFF7FB2FF);
  static const libero = Color(0xFFB39DDB);
  static const win = Color(0xFF1E4D3E);
  static const loss = Color(0xFF4A2620);
}

const gradeColors = <String, Color>{
  '#': Color(0xFF2F8F6B),
  '+': Color(0xFF24614D),
  '!': Color(0xFF3A4757),
  '-': Color(0xFF7A5A2A),
  '/': Color(0xFF8E4A1E),
  '=': Color(0xFFB23A2E),
};

const gradeLabels = <String, String>{
  '#': 'Punto / Perfetto',
  '+': 'Positivo',
  '!': 'Rigiocabile',
  '-': 'Negativo',
  '/': 'Scarso / Murato',
  '=': 'Errore',
};

const jerseyPalette = <int>[
  0xFF1F6FD1,
  0xFF0D2C6B,
  0xFFC62828,
  0xFF2E7D32,
  0xFF111111,
  0xFFFFFFFF,
  0xFF6A1B9A,
  0xFFF9A825,
  0xFF00ACC1,
  0xFFE9C46A,
  0xFFF06292,
  0xFFFF7043,
];

bool isLight(Color c) => c.computeLuminance() > 0.45;

TextStyle cond(double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? C.text,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.0,
    );

const labelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: C.muted,
  letterSpacing: 1,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: C.accent,
    onPrimary: C.bg,
    surface: C.surface,
    onSurface: C.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.surface,
      foregroundColor: C.text,
      elevation: 0,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: C.surface2,
      border: OutlineInputBorder(),
    ),
  );
}
