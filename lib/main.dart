import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pantallas/pantalla_inicio.dart';
import 'servicios/preferencias.dart';
import 'tema/paletas.dart';
import 'widgets/formato.dart' as fmt;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(fmt.localeApp, null);
  paletaActual.value = paletaPorId(await Preferencias.leerPaleta());
  runApp(const AppWAudios());
}

class AppWAudios extends StatelessWidget {
  const AppWAudios({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaletaApp>(
      valueListenable: paletaActual,
      builder: (context, paleta, _) {
        // Las barras del sistema tienen que seguir a la paleta; si no, con la
        // clara los iconos se quedan blancos sobre blanco.
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              paleta.esClara ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: paleta.superficie,
          systemNavigationBarIconBrightness:
              paleta.esClara ? Brightness.dark : Brightness.light,
        ));

        return MaterialApp(
          title: 'WAudios',
          debugShowCheckedModeBanner: false,
          theme: temaDe(paleta),
          home: const PantallaInicio(),
        );
      },
    );
  }
}
