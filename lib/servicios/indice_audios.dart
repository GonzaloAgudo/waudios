import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../modelos/nota_audio.dart';
import 'duracion_opus.dart';

/// Carpetas donde WhatsApp (y WhatsApp Business) guardan audios, tanto en la
/// ubicación moderna (`Android/media`) como en la antigua (raíz de la memoria).
const List<String> _rutasWhatsApp = [
  '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes',
  '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
  '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Voice Notes',
  '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Audio',
  '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes',
  '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
];

const Set<String> _extensionesAudio = {
  '.opus',
  '.mp3',
  '.m4a',
  '.aac',
  '.ogg',
  '.wav',
  '.amr',
  '.mpeg',
};

/// Índice de todos los audios del dispositivo.
///
/// Estrategia para que abrir la app sea instantáneo aunque haya miles de
/// audios:
///
/// 1. Al arrancar se lee un índice cacheado en disco (un único JSON) y la
///    interfaz se pinta de inmediato con él.
/// 2. En paralelo, y **siempre dentro de un isolate**, se recorre el disco.
///    El recorrido es incremental: de los archivos que ya estaban en la caché
///    solo se comprueba que sigan existiendo, y únicamente se hace `stat()` de
///    los nuevos.
/// 3. Las duraciones se calculan bajo demanda, solo para los audios que el
///    usuario tiene delante, y se guardan en la caché para no repetirlo.
class IndiceAudios extends ChangeNotifier {
  final Map<String, NotaAudio> _porRuta = {};
  final Map<DateTime, List<NotaAudio>> _porDia = {};
  final Set<String> _escuchados = {};
  final Set<String> _duracionesEnCurso = {};

  List<NotaAudio> _todas = const [];
  bool _cargando = true;
  bool _escaneando = false;
  bool _hayCarpetas = true;
  Timer? _guardadoDiferido;

  /// Cierto solo hasta que se pinta el primer índice (cacheado o recién hecho).
  bool get cargando => _cargando;

  /// Cierto mientras hay un recorrido de disco en marcha. La interfaz sigue
  /// siendo usable: es un indicador discreto, no una pantalla de espera.
  bool get escaneando => _escaneando;

  /// Falso si no existe ninguna carpeta de WhatsApp (app no instalada, o sin
  /// permiso real de lectura).
  bool get hayCarpetas => _hayCarpetas;

  /// Todos los audios, del más reciente al más antiguo.
  List<NotaAudio> get todas => _todas;

  int get total => _todas.length;

  /// Días que tienen al menos un audio, para marcarlos en el calendario.
  Iterable<DateTime> get diasConAudio => _porDia.keys;

  List<NotaAudio> delDia(DateTime dia) =>
      _porDia[DateTime(dia.year, dia.month, dia.day)] ?? const [];

  int cuentaDelDia(DateTime dia) => delDia(dia).length;

  bool estaEscuchado(String ruta) => _escuchados.contains(ruta);

  int get sinEscuchar => _todas.length - _escuchados.length;

  void marcarEscuchado(String ruta) {
    if (_escuchados.add(ruta)) {
      _programarGuardado();
      notifyListeners();
    }
  }

  void marcarTodoEscuchado() {
    _escuchados.addAll(_todas.map((a) => a.ruta));
    _programarGuardado();
    notifyListeners();
  }

  /// Arranque: caché primero, disco después.
  Future<void> iniciar() async {
    await _cargarCache();
    _cargando = false;
    notifyListeners();
    await refrescar();
  }

  /// Recorre el disco en un isolate y fusiona las novedades.
  Future<void> refrescar() async {
    if (_escaneando) return;
    _escaneando = true;
    notifyListeners();

    try {
      final conocidas = _porRuta.keys.toSet();
      final resultado =
          await Isolate.run(() => _escanearDisco(_rutasWhatsApp, conocidas));

      _hayCarpetas = resultado.habiaCarpetas;

      var cambios = resultado.nuevas.isNotEmpty;
      for (final nota in resultado.nuevas) {
        _porRuta[nota.ruta] = nota;
      }

      // Archivos que estaban en la caché y ya no están en el disco.
      final borradas =
          _porRuta.keys.where((r) => !resultado.vistas.contains(r)).toList();
      if (borradas.isNotEmpty) {
        cambios = true;
        for (final ruta in borradas) {
          _porRuta.remove(ruta);
          _escuchados.remove(ruta);
        }
      }

      if (cambios) {
        _reconstruirIndices();
        _programarGuardado();
      }
    } catch (e, s) {
      debugPrint('Error escaneando audios: $e\n$s');
    } finally {
      _escaneando = false;
      notifyListeners();
    }
  }

  /// Calcula la duración de un puñado de audios (los que se están viendo) en un
  /// isolate y la guarda. Ignora los que ya la tienen o ya están en cola.
  Future<void> asegurarDuraciones(Iterable<NotaAudio> notas) async {
    final pendientes = notas
        .where((n) => n.duracion == null && !_duracionesEnCurso.contains(n.ruta))
        .map((n) => n.ruta)
        .toList();
    if (pendientes.isEmpty) return;

    _duracionesEnCurso.addAll(pendientes);
    try {
      final medidas = await Isolate.run(() => _medirDuraciones(pendientes));

      var cambios = false;
      medidas.forEach((ruta, ms) {
        final actual = _porRuta[ruta];
        if (actual == null) return;
        // Duration.zero marca "ya lo intentamos y no se pudo leer", para no
        // volver a abrir el archivo en cada scroll.
        _porRuta[ruta] = actual.conDuracion(
          ms == null ? Duration.zero : Duration(milliseconds: ms),
        );
        cambios = true;
      });

      if (cambios) {
        _reconstruirIndices();
        _programarGuardado();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error midiendo duraciones: $e');
    } finally {
      _duracionesEnCurso.removeAll(pendientes);
    }
  }

  void _reconstruirIndices() {
    _porDia.clear();
    for (final nota in _porRuta.values) {
      (_porDia[nota.dia] ??= []).add(nota);
    }
    // Dentro de cada día, del más antiguo al más nuevo (orden de conversación).
    for (final lista in _porDia.values) {
      lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    }
    _todas = _porRuta.values.toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  // ----------------------------------------------------------------- caché

  Future<File> _ficheroCache() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/indice_audios.json');
  }

  Future<void> _cargarCache() async {
    try {
      final fichero = await _ficheroCache();
      if (!await fichero.exists()) return;

      final crudo = jsonDecode(await fichero.readAsString());
      if (crudo is! Map) return;

      final filas = crudo['audios'];
      if (filas is List) {
        for (final fila in filas) {
          final nota = NotaAudio.desdeJson(fila);
          if (nota != null) _porRuta[nota.ruta] = nota;
        }
      }
      final oidos = crudo['escuchados'];
      if (oidos is List) {
        _escuchados.addAll(oidos.whereType<String>());
      }
      _reconstruirIndices();
    } catch (e) {
      debugPrint('No se pudo leer la caché del índice: $e');
    }
  }

  /// Guardar es barato pero no gratis: lo agrupamos para no reescribir el JSON
  /// entero cada vez que llega una duración suelta.
  void _programarGuardado() {
    _guardadoDiferido?.cancel();
    _guardadoDiferido = Timer(const Duration(seconds: 2), _guardarCache);
  }

  Future<void> _guardarCache() async {
    try {
      final fichero = await _ficheroCache();
      final datos = {
        'version': 1,
        'audios': _porRuta.values.map((n) => n.aJson()).toList(),
        'escuchados': _escuchados.toList(),
      };
      await fichero.writeAsString(jsonEncode(datos));
    } catch (e) {
      debugPrint('No se pudo guardar la caché del índice: $e');
    }
  }

  @override
  void dispose() {
    _guardadoDiferido?.cancel();
    unawaited(_guardarCache());
    super.dispose();
  }
}

/// Lo que devuelve el isolate de escaneo.
class ResultadoEscaneo {
  final List<NotaAudio> nuevas;

  /// Todas las rutas de audio presentes ahora mismo en el disco. Sirve para
  /// detectar borrados sin comprobar archivo por archivo.
  final Set<String> vistas;

  final bool habiaCarpetas;

  const ResultadoEscaneo(this.nuevas, this.vistas, this.habiaCarpetas);
}

/// Recorrido del disco. Se ejecuta **siempre** dentro de un isolate, por eso
/// usa las variantes síncronas: fuera de un isolate bloquearían la interfaz,
/// pero dentro son mucho más rápidas que sus equivalentes asíncronas, que
/// obligan a pasar por el bucle de eventos una vez por archivo.
ResultadoEscaneo _escanearDisco(List<String> rutas, Set<String> conocidas) {
  final nuevas = <NotaAudio>[];
  final vistas = <String>{};
  var habiaCarpetas = false;

  for (final raiz in rutas) {
    final directorio = Directory(raiz);
    if (!directorio.existsSync()) continue;
    habiaCarpetas = true;

    final List<FileSystemEntity> entradas;
    try {
      entradas = directorio.listSync(recursive: true, followLinks: false);
    } catch (_) {
      continue;
    }

    for (final entrada in entradas) {
      if (entrada is! File) continue;
      final ruta = entrada.path;
      if (!_esAudio(ruta)) continue;

      vistas.add(ruta);
      // Lo verdaderamente caro es el stat(): solo lo hacemos de lo nuevo.
      if (conocidas.contains(ruta)) continue;

      try {
        final info = entrada.statSync();
        nuevas.add(NotaAudio(
          ruta: ruta,
          fecha: _fechaDe(ruta, info.modified),
          tamano: info.size,
        ));
      } catch (_) {
        // Archivo desaparecido o sin permiso: lo saltamos.
      }
    }
  }

  return ResultadoEscaneo(nuevas, vistas, habiaCarpetas);
}

/// WhatsApp codifica el día en el nombre (`PTT-20240115-WA0003.opus`). Cuando
/// existe, ese día manda sobre la fecha de modificación: si se ha restaurado
/// una copia de seguridad o se ha copiado la carpeta, todos los archivos pasan
/// a tener la fecha de la restauración y el calendario saldría vacío salvo por
/// un único día enorme. Del `stat` conservamos la hora.
DateTime _fechaDe(String ruta, DateTime modificado) {
  final nombre = ruta.substring(ruta.lastIndexOf('/') + 1);
  final coincidencia = _patronFecha.firstMatch(nombre);
  if (coincidencia == null) return modificado;

  final anio = int.parse(coincidencia.group(1)!);
  final mes = int.parse(coincidencia.group(2)!);
  final dia = int.parse(coincidencia.group(3)!);
  if (anio < 2009 || anio > modificado.year || mes < 1 || mes > 12 ||
      dia < 1 || dia > 31) {
    return modificado;
  }

  if (anio == modificado.year &&
      mes == modificado.month &&
      dia == modificado.day) {
    return modificado;
  }
  return DateTime(
      anio, mes, dia, modificado.hour, modificado.minute, modificado.second);
}

final RegExp _patronFecha = RegExp(r'(\d{4})(\d{2})(\d{2})');

bool _esAudio(String ruta) {
  final punto = ruta.lastIndexOf('.');
  if (punto < 0) return false;
  return _extensionesAudio.contains(ruta.substring(punto).toLowerCase());
}

/// Duraciones de un lote de archivos, dentro de un isolate.
Map<String, int?> _medirDuraciones(List<String> rutas) {
  final resultado = <String, int?>{};
  for (final ruta in rutas) {
    resultado[ruta] = leerDuracionOgg(ruta)?.inMilliseconds;
  }
  return resultado;
}
