import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Ajustes de la app. Es un único JSON diminuto: no compensa traer una
/// dependencia entera para guardar un puñado de claves.
class Preferencias {
  static Future<File> _fichero() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/ajustes.json');
  }

  static Future<Map<String, dynamic>> _leer() async {
    try {
      final f = await _fichero();
      if (!await f.exists()) return {};
      final datos = jsonDecode(await f.readAsString());
      return datos is Map<String, dynamic> ? datos : {};
    } catch (e) {
      debugPrint('No se pudieron leer los ajustes: $e');
      return {};
    }
  }

  static Future<String?> leerPaleta() async {
    final datos = await _leer();
    final valor = datos['paleta'];
    return valor is String ? valor : null;
  }

  static Future<void> guardarPaleta(String id) async {
    try {
      final datos = await _leer();
      datos['paleta'] = id;
      await (await _fichero()).writeAsString(jsonEncode(datos));
    } catch (e) {
      debugPrint('No se pudieron guardar los ajustes: $e');
    }
  }
}
