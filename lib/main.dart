import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pantallas/pantalla_inicio.dart';
import 'widgets/formato.dart' as fmt;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(fmt.localeApp, null);
  runApp(const AppWAudios());
}

class AppWAudios extends StatelessWidget {
  const AppWAudios({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WAudios',
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      // Antes el tema era oscuro fijo; ahora sigue al sistema.
      themeMode: ThemeMode.system,
      home: const PantallaInicio(),
    );
  }

  ThemeData _tema(Brightness brillo) {
    final esquema = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: brillo,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: esquema.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: esquema.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
    );
  }
}
