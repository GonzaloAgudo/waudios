import 'package:flutter/material.dart';

/// Una combinación de colores completa de la app.
///
/// Se definen a mano en vez de con `ColorScheme.fromSeed` porque lo generado a
/// partir de una semilla arrastra neutros grisáceos que aplanan el conjunto;
/// aquí cada fondo está elegido para acompañar a su acento.
class PaletaApp {
  final String id;
  final String nombre;
  final Brightness brillo;

  final Color fondo;
  final Color superficie;
  final Color superficieAlta;
  final Color superficieMax;
  final Color acento;
  final Color sobreAcento;
  final Color acentoSuave;
  final Color texto;
  final Color textoTenue;
  final Color borde;

  const PaletaApp({
    required this.id,
    required this.nombre,
    required this.brillo,
    required this.fondo,
    required this.superficie,
    required this.superficieAlta,
    required this.superficieMax,
    required this.acento,
    required this.sobreAcento,
    required this.acentoSuave,
    required this.texto,
    required this.textoTenue,
    required this.borde,
  });

  bool get esClara => brillo == Brightness.light;

  ColorScheme get esquema => ColorScheme(
        brightness: brillo,
        primary: acento,
        onPrimary: sobreAcento,
        primaryContainer: acentoSuave,
        onPrimaryContainer: acento,
        secondary: acento,
        onSecondary: sobreAcento,
        tertiary: acento,
        onTertiary: sobreAcento,
        error: esClara ? const Color(0xFFB3261E) : const Color(0xFFE5796B),
        onError: esClara ? Colors.white : const Color(0xFF2A0A06),
        surface: superficie,
        onSurface: texto,
        onSurfaceVariant: textoTenue,
        surfaceContainerLow: superficie,
        surfaceContainer: superficieAlta,
        surfaceContainerHigh: superficieAlta,
        surfaceContainerHighest: superficieMax,
        outline: borde,
        outlineVariant: borde,
      );
}

const List<PaletaApp> paletas = [
  PaletaApp(
    id: 'noche',
    nombre: 'Noche',
    brillo: Brightness.dark,
    fondo: Color(0xFF0E1116),
    superficie: Color(0xFF151A21),
    superficieAlta: Color(0xFF1C232C),
    superficieMax: Color(0xFF27303B),
    acento: Color(0xFF5AA2FF),
    sobreAcento: Color(0xFF05203F),
    acentoSuave: Color(0xFF17304F),
    texto: Color(0xFFE8EDF4),
    textoTenue: Color(0xFF93A1B3),
    borde: Color(0xFF272F3A),
  ),
  PaletaApp(
    id: 'bosque',
    nombre: 'Bosque',
    brillo: Brightness.dark,
    fondo: Color(0xFF0C110E),
    superficie: Color(0xFF131A15),
    superficieAlta: Color(0xFF1A231C),
    superficieMax: Color(0xFF253026),
    acento: Color(0xFF5CD69B),
    sobreAcento: Color(0xFF032515),
    acentoSuave: Color(0xFF13332A),
    texto: Color(0xFFE6EFE9),
    textoTenue: Color(0xFF93A89C),
    borde: Color(0xFF243029),
  ),
  PaletaApp(
    id: 'ciruela',
    nombre: 'Ciruela',
    brillo: Brightness.dark,
    fondo: Color(0xFF110F16),
    superficie: Color(0xFF18151F),
    superficieAlta: Color(0xFF211D2A),
    superficieMax: Color(0xFF2D2839),
    acento: Color(0xFFB392F0),
    sobreAcento: Color(0xFF1D0F3C),
    acentoSuave: Color(0xFF2A2045),
    texto: Color(0xFFEDE8F5),
    textoTenue: Color(0xFFA299B3),
    borde: Color(0xFF2E2838),
  ),
  PaletaApp(
    id: 'brasa',
    nombre: 'Brasa',
    brillo: Brightness.dark,
    fondo: Color(0xFF13110D),
    superficie: Color(0xFF1A1813),
    superficieAlta: Color(0xFF242018),
    superficieMax: Color(0xFF2E2920),
    acento: Color(0xFFF2A73B),
    sobreAcento: Color(0xFF2A1C06),
    acentoSuave: Color(0xFF4A3A1E),
    texto: Color(0xFFF2EBE0),
    textoTenue: Color(0xFFA89C8A),
    borde: Color(0xFF332D23),
  ),
  PaletaApp(
    id: 'papel',
    nombre: 'Papel',
    brillo: Brightness.light,
    fondo: Color(0xFFFAF7F2),
    superficie: Color(0xFFFFFFFF),
    superficieAlta: Color(0xFFF3EFE8),
    superficieMax: Color(0xFFE8E2D8),
    acento: Color(0xFF2457C5),
    sobreAcento: Color(0xFFFFFFFF),
    acentoSuave: Color(0xFFDCE6FA),
    texto: Color(0xFF1C1A17),
    textoTenue: Color(0xFF6B6358),
    borde: Color(0xFFE0D9CE),
  ),
];

/// Paleta en uso. Es estado global a propósito: es un único ajuste de toda la
/// app y pasarlo por el árbol de widgets solo añadiría ruido.
final ValueNotifier<PaletaApp> paletaActual = ValueNotifier(paletas.first);

PaletaApp paletaPorId(String? id) => paletas.firstWhere(
      (p) => p.id == id,
      orElse: () => paletas.first,
    );

/// Construye el tema completo a partir de una paleta. Todo lo que no sea color
/// (formas, densidades, tipografía) es común: así cambiar de paleta cambia los
/// colores y nada más.
ThemeData temaDe(PaletaApp p) {
  final esquema = p.esquema;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: p.fondo,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: p.texto,
      displayColor: p.texto,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.fondo,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.texto,
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.acentoSuave,
      height: 66,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected)
              ? p.acento
              : p.textoTenue,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => TextStyle(
          fontSize: 12,
          fontWeight: estados.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: estados.contains(WidgetState.selected)
              ? p.acento
              : p.textoTenue,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.borde, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.superficieAlta,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(iconColor: p.textoTenue),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.acento,
      thumbColor: p.acento,
      inactiveTrackColor: p.superficieMax,
    ),
  );
}
