import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../modelos/nota_audio.dart';
import 'analisis_opus.dart';

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

/// Formato de la caché en disco. Al subirlo, lo que guardó una versión
/// anterior deja de usarse para el análisis y se vuelve a calcular.
const int _versionCache = 3;

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
/// Con ~7000 audios, medido en un Redmi Note 12, el recorrido del disco cuesta
/// 3,7 s de listar carpetas más 2,5 s de `stat`. Hacer eso entero antes de
/// enseñar nada dejaba la app en blanco más de seis segundos. Cuatro decisiones
/// lo evitan:
///
/// 1. Al arrancar se lee un índice cacheado en disco (un único JSON) y la
///    interfaz se pinta de inmediato con él, sin esperar al disco.
/// 2. El recorrido va **en streaming y de lo más reciente a lo más antiguo**:
///    manda lotes según los encuentra, así que los audios de esta semana
///    aparecen a los ~400 ms en vez de al final.
/// 3. Las carpetas semanales cuya fecha de modificación no ha cambiado ni se
///    listan. Eso deja el refresco de arranques posteriores en ~120 ms.
/// 4. La duración y la forma de onda se sacan bajo demanda, solo de los audios
///    que el usuario tiene delante, y se guardan en la caché para no repetirlo.
class IndiceAudios extends ChangeNotifier {
  final Map<String, NotaAudio> _porRuta = {};
  final Map<DateTime, List<NotaAudio>> _porDia = {};
  final Set<String> _analisisEnCurso = {};

  /// Fecha de modificación de cada carpeta semanal la última vez que la
  /// listamos. Permite saltarse enteras las que no han cambiado.
  final Map<String, int> _mtimesCarpetas = {};

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

  /// Arranque: caché primero, disco después.
  Future<void> iniciar() async {
    await _cargarCache();
    // Si la caché ya trae algo, se pinta al instante. Si no, seguimos en
    // "cargando" solo hasta que llegue el primer lote del escaneo.
    _cargando = _porRuta.isEmpty;
    notifyListeners();
    await refrescar();
  }

  /// Recorre el disco en un isolate y va fusionando los lotes según llegan.
  ///
  /// No se espera al final del recorrido para enseñar nada: cada lote que
  /// entra repinta la lista, y como el isolate va de la semana más reciente
  /// hacia atrás, lo primero que aparece es lo último que has recibido.
  Future<void> refrescar() async {
    if (_escaneando) return;
    _escaneando = true;
    notifyListeners();

    final receptor = ReceivePort();
    Isolate? isolate;

    try {
      isolate = await Isolate.spawn(
        escanearStreaming,
        ParamsEscaneo(
          receptor.sendPort,
          _rutasWhatsApp,
          _porRuta.keys.toSet(),
          Map.of(_mtimesCarpetas),
        ),
        onError: receptor.sendPort,
        onExit: receptor.sendPort,
      );

      final vistasTotales = <String>{};
      var huboAlgunLote = false;

      await for (final mensaje in receptor) {
        if (mensaje is! LoteEscaneo) {
          // onExit manda null y onError una lista [error, stack].
          if (mensaje is List) debugPrint('Escaneo interrumpido: $mensaje');
          break;
        }

        huboAlgunLote = true;
        _hayCarpetas = mensaje.habiaCarpetas;
        vistasTotales.addAll(mensaje.vistas);
        _mtimesCarpetas.addAll(mensaje.mtimes);

        if (mensaje.nuevas.isNotEmpty) {
          for (final nota in mensaje.nuevas) {
            _porRuta[nota.ruta] = nota;
          }
          _reconstruirIndices();
        }

        if (mensaje.ultimo) {
          // Solo al terminar sabemos qué ha desaparecido de verdad.
          final borradas = _porRuta.keys
              .where((r) => !vistasTotales.contains(r))
              .toList();
          for (final ruta in borradas) {
            _porRuta.remove(ruta);
          }
          if (borradas.isNotEmpty) _reconstruirIndices();
        }

        _cargando = false;
        notifyListeners();

        if (mensaje.ultimo) break;
      }

      if (huboAlgunLote) _programarGuardado();
    } catch (e) {
      debugPrint('Error escaneando audios: $e');
    } finally {
      receptor.close();
      isolate?.kill(priority: Isolate.immediate);
      _cargando = false;
      _escaneando = false;
      notifyListeners();
    }
  }

  /// Analiza un puñado de audios (los que se están viendo) en un isolate y
  /// guarda su duración y su forma de onda. Ignora los que ya lo están o ya
  /// están en cola.
  Future<void> asegurarAnalisis(Iterable<NotaAudio> notas) async {
    final pendientes = notas
        .where((n) => !n.analizado && !_analisisEnCurso.contains(n.ruta))
        .map((n) => n.ruta)
        .toList();
    if (pendientes.isEmpty) return;

    _analisisEnCurso.addAll(pendientes);
    try {
      // `compute` y no `Isolate.run`: el closure de Isolate.run se lleva
      // consigo el `this` de esta clase, y con él el Timer del guardado
      // diferido, que no se puede enviar a otro isolate.
      final resultados = await compute(_analizarLote, pendientes);

      var cambios = false;
      for (final r in resultados) {
        final actual = _porRuta[r.ruta];
        if (actual == null) continue;
        // Duration.zero marca "ya lo intentamos y no se pudo leer", para no
        // volver a abrir el archivo en cada scroll.
        _porRuta[r.ruta] = actual.conAnalisis(
          r.duracionMs == null
              ? Duration.zero
              : Duration(milliseconds: r.duracionMs!),
          r.onda,
        );
        cambios = true;
      }

      if (cambios) {
        _reconstruirIndices();
        _programarGuardado();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error analizando audios: $e');
    } finally {
      _analisisEnCurso.removeAll(pendientes);
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

      // Las cachés de versiones anteriores traen duración pero no forma de
      // onda. Si nos quedáramos con esa duración, los audios contarían como ya
      // analizados y nunca se les calcularía la onda: de una caché vieja solo
      // aprovechamos lo que da el escaneo (ruta, fecha y tamaño).
      final version = crudo['version'];
      final analisisUtil = version == _versionCache;

      final filas = crudo['audios'];
      if (filas is List) {
        for (final fila in filas) {
          final nota = NotaAudio.desdeJson(fila);
          if (nota == null) continue;
          _porRuta[nota.ruta] = analisisUtil
              ? nota
              : NotaAudio(
                  ruta: nota.ruta,
                  fecha: nota.fecha,
                  tamano: nota.tamano,
                );
        }
      }
      final carpetas = crudo['carpetas'];
      if (carpetas is Map) {
        carpetas.forEach((clave, valor) {
          if (clave is String && valor is int) _mtimesCarpetas[clave] = valor;
        });
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
        'version': _versionCache,
        'audios': _porRuta.values.map((n) => n.aJson()).toList(),
        'carpetas': _mtimesCarpetas,
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

/// Lo que el isolate manda de vuelta cada poco tiempo mientras escanea.
class LoteEscaneo {
  /// Audios descubiertos en este tramo.
  final List<NotaAudio> nuevas;

  /// Rutas confirmadas como presentes en el disco, para detectar borrados.
  final Set<String> vistas;

  /// Fecha de modificación de cada carpeta revisada, para poder saltárnosla
  /// entera la próxima vez si no ha cambiado.
  final Map<String, int> mtimes;

  final bool habiaCarpetas;
  final bool ultimo;

  const LoteEscaneo(
    this.nuevas,
    this.vistas,
    this.mtimes,
    this.habiaCarpetas,
    this.ultimo,
  );
}

/// Lo que necesita el isolate para arrancar.
class ParamsEscaneo {
  final SendPort puerto;
  final List<String> raices;
  final Set<String> conocidas;
  final Map<String, int> mtimes;

  const ParamsEscaneo(this.puerto, this.raices, this.conocidas, this.mtimes);
}

/// Cuántas carpetas recientes se releen siempre, aunque su fecha de
/// modificación diga que no han cambiado. Es el seguro por si algún
/// sistema de archivos no actualiza el mtime del directorio.
const int _carpetasSiempreFrescas = 3;

/// Recorrido del disco, dentro de un isolate y **en streaming**.
///
/// Dos cosas hacen que la app deje de tardar segundos en mostrar algo:
///
/// 1. WhatsApp reparte los audios en carpetas `AAAASS` (año + semana). Se
///    recorren de la más reciente a la más antigua y se van mandando lotes por
///    el camino, así que los audios de esta semana aparecen en cuanto se lee la
///    primera carpeta, no cuando termina todo el recorrido.
/// 2. Si la fecha de modificación de una carpeta no ha cambiado desde el último
///    escaneo, no se lista siquiera: basta con dar por buenos los archivos que
///    ya teníamos. Un `stat` por carpeta en lugar de listar miles de archivos.
void escanearStreaming(ParamsEscaneo p) {
  // Agrupamos lo ya conocido por carpeta para poder saltarnos las intactas.
  final conocidasPorCarpeta = <String, List<String>>{};
  for (final ruta in p.conocidas) {
    final corte = ruta.lastIndexOf('/');
    if (corte <= 0) continue;
    (conocidasPorCarpeta[ruta.substring(0, corte)] ??= []).add(ruta);
  }

  var habiaCarpetas = false;
  final carpetas = <String>[];

  for (final raiz in p.raices) {
    final directorio = Directory(raiz);
    if (!directorio.existsSync()) continue;
    habiaCarpetas = true;
    carpetas.add(raiz); // por si hay archivos sueltos fuera de las semanas
    try {
      for (final entrada in directorio.listSync(followLinks: false)) {
        if (entrada is Directory) carpetas.add(entrada.path);
      }
    } catch (_) {
      // Carpeta ilegible: seguimos con el resto.
    }
  }

  // Los nombres son AAAASS, así que ordenarlos al revés es ordenarlos de más
  // reciente a más antiguo.
  carpetas.sort((a, b) => _nombreDe(b).compareTo(_nombreDe(a)));

  final lote = <NotaAudio>[];
  final vistas = <String>{};
  final mtimes = <String, int>{};
  final desdeElUltimoEnvio = Stopwatch()..start();
  var esElPrimerEnvio = true;

  void enviar({bool ultimo = false}) {
    p.puerto.send(LoteEscaneo(
      List.of(lote),
      Set.of(vistas),
      Map.of(mtimes),
      habiaCarpetas,
      ultimo,
    ));
    lote.clear();
    vistas.clear();
    mtimes.clear();
    desdeElUltimoEnvio.reset();
    esElPrimerEnvio = false;
  }

  for (var i = 0; i < carpetas.length; i++) {
    final carpeta = carpetas[i];

    int? mtime;
    try {
      mtime = Directory(carpeta).statSync().modified.millisecondsSinceEpoch;
    } catch (_) {
      continue;
    }

    final yaConocidas = conocidasPorCarpeta[carpeta];
    final intacta = i >= _carpetasSiempreFrescas &&
        yaConocidas != null &&
        p.mtimes[carpeta] == mtime;

    if (intacta) {
      vistas.addAll(yaConocidas);
      mtimes[carpeta] = mtime;
      continue;
    }

    final List<FileSystemEntity> entradas;
    try {
      entradas = Directory(carpeta).listSync(followLinks: false);
    } catch (_) {
      continue;
    }

    for (final entrada in entradas) {
      if (entrada is! File) continue;
      final ruta = entrada.path;
      if (!_esAudio(ruta)) continue;

      vistas.add(ruta);
      // El stat por archivo solo se paga con lo que no teníamos.
      if (p.conocidas.contains(ruta)) continue;

      try {
        final info = entrada.statSync();
        lote.add(NotaAudio(
          ruta: ruta,
          fecha: _fechaDe(ruta, info.modified),
          tamano: info.size,
        ));
      } catch (_) {
        // Archivo desaparecido o sin permiso: lo saltamos.
      }
    }
    mtimes[carpeta] = mtime;

    // El primer lote sale en cuanto haya algo, para que la pantalla se llene
    // de inmediato; a partir de ahí se agrupa para no saturar de mensajes.
    final toca = (esElPrimerEnvio && lote.isNotEmpty) ||
        lote.length >= 300 ||
        desdeElUltimoEnvio.elapsedMilliseconds >= 300;
    if (toca) enviar();
  }

  enviar(ultimo: true);
}

String _nombreDe(String ruta) => ruta.substring(ruta.lastIndexOf('/') + 1);

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

/// Lo que devuelve el análisis de un archivo. Clase propia y no un registro
/// para que viaje entre isolates sin sorpresas.
class ResultadoAnalisis {
  final String ruta;
  final int? duracionMs;
  final List<int> onda;

  const ResultadoAnalisis(this.ruta, this.duracionMs, this.onda);
}

/// Análisis de un lote de archivos, dentro de un isolate.
List<ResultadoAnalisis> _analizarLote(List<String> rutas) {
  return [
    for (final ruta in rutas)
      () {
        final analisis = analizarOpus(ruta);
        return ResultadoAnalisis(
          ruta,
          analisis?.duracion.inMilliseconds,
          analisis?.onda ?? const <int>[],
        );
      }(),
  ];
}
