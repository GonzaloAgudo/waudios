import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pantallas/pantalla_inicio.dart';
import 'widgets/formato.dart' as fmt;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(fmt.localeApp, null);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF17150F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const AppWAudios());
}

/// Paleta: neutros cálidos en vez de grises fríos, y un único acento ámbar.
/// El negro puro cansa y aplana; estos tonos tiran ligeramente a marrón, que
/// con el ámbar se lee como algo cálido y no como una app de sistema.
class _Paleta {
  static const fondo = Color(0xFF13110D);
  static const superficie = Color(0xFF1A1813);
  static const superficieAlta = Color(0xFF242018);
  static const superficieMax = Color(0xFF2E2920);
  static const acento = Color(0xFFF2A73B);
  static const acentoSuave = Color(0xFF4A3A1E);
  static const texto = Color(0xFFF2EBE0);
  static const textoTenue = Color(0xFFA89C8A);
  static const borde = Color(0xFF332D23);
}

class AppWAudios extends StatelessWidget {
  const AppWAudios({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WAudios',
      debugShowCheckedModeBanner: false,
      theme: _tema(),
      home: const PantallaInicio(),
    );
  }

  ThemeData _tema() {
    const esquema = ColorScheme(
      brightness: Brightness.dark,
      primary: _Paleta.acento,
      onPrimary: Color(0xFF2A1C06),
      primaryContainer: _Paleta.acentoSuave,
      onPrimaryContainer: _Paleta.acento,
      secondary: _Paleta.acento,
      onSecondary: Color(0xFF2A1C06),
      tertiary: Color(0xFFE2803C),
      onTertiary: Color(0xFF2A1206),
      error: Color(0xFFE5796B),
      onError: Color(0xFF2A0A06),
      surface: _Paleta.superficie,
      onSurface: _Paleta.texto,
      onSurfaceVariant: _Paleta.textoTenue,
      surfaceContainerLow: _Paleta.superficie,
      surfaceContainer: _Paleta.superficieAlta,
      surfaceContainerHigh: _Paleta.superficieAlta,
      surfaceContainerHighest: _Paleta.superficieMax,
      outline: _Paleta.borde,
      outlineVariant: _Paleta.borde,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: _Paleta.fondo,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: _Paleta.texto,
        displayColor: _Paleta.texto,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _Paleta.fondo,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _Paleta.texto,
        centerTitle: false,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _Paleta.superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _Paleta.acentoSuave,
        height: 66,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            color: estados.contains(WidgetState.selected)
                ? _Paleta.acento
                : _Paleta.textoTenue,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => TextStyle(
            fontSize: 12,
            fontWeight: estados.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: estados.contains(WidgetState.selected)
                ? _Paleta.acento
                : _Paleta.textoTenue,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _Paleta.borde,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _Paleta.superficieAlta,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(iconColor: _Paleta.textoTenue),
      sliderTheme: const SliderThemeData(
        activeTrackColor: _Paleta.acento,
        thumbColor: _Paleta.acento,
        inactiveTrackColor: _Paleta.superficieMax,
      ),
    );
  }
}
