import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Número de barras de la forma de onda. Suficiente para que se reconozca el
/// ritmo de la voz sin engordar la caché.
const int barrasOnda = 44;

/// Lo que se puede saber de un audio leyendo el archivo, sin decodificarlo.
class AnalisisOpus {
  final Duration duracion;

  /// Amplitud relativa a lo largo del audio, de 0 a 100.
  final List<int> onda;

  const AnalisisOpus(this.duracion, this.onda);
}

/// Analiza un Ogg/Opus (el formato de las notas de voz de WhatsApp) leyendo
/// solo la estructura del contenedor.
///
/// Un Ogg se divide en páginas. Cada una declara su "granule position" (las
/// muestras decodificadas hasta ese punto) y, en su tabla de segmentos, cuántos
/// bytes ocupa. De ahí salen las dos cosas que enseña la app:
///
/// - La **duración**, de la granule position de la última página. Para Opus el
///   reloj es siempre de 48 kHz.
/// - La **forma de onda**, del tamaño de cada paquete Opus. Medido sobre notas
///   reales de WhatsApp, el habla ocupa entre 210 y 310 bytes por paquete: un
///   margen demasiado estrecho para leerlo como volumen. Lo que sí marca con
///   claridad son los **silencios**, que el códec reduce a unos pocos bytes
///   (un 5% de los paquetes, agrupados en 6-11 rachas por audio). Así que la
///   onda enseña el ritmo del mensaje —dónde se para quien habla— y no su
///   amplitud. Es un dato real del archivo, pero no es un envolvente de
///   volumen: para eso haría falta descodificar el audio.
///
/// Todo esto cuesta una lectura del archivo (una nota de voz ocupa unos pocos
/// cientos de KB) y ningún decodificador, así que se puede hacer en un isolate
/// para los audios que están a la vista.
AnalisisOpus? analizarOpus(String ruta) {
  try {
    final bytes = File(ruta).readAsBytesSync();
    if (bytes.length < 60 || !_esOggS(bytes, 0)) return null;

    var preSkip = 0;
    var vistaCabecera = false;
    var ultimoGranulo = 0;
    final paquetes = <int>[];

    var pos = 0;
    while (pos + 27 <= bytes.length) {
      if (!_esOggS(bytes, pos) || bytes[pos + 4] != 0) break;

      final segmentos = bytes[pos + 26];
      final finTabla = pos + 27 + segmentos;
      if (finTabla > bytes.length) break;

      // La tabla de segmentos trocea la página en paquetes: un paquete acaba
      // en el primer valor menor que 255.
      var datos = 0;
      var enCurso = 0;
      final depagina = <int>[];
      for (var i = pos + 27; i < finTabla; i++) {
        final lacing = bytes[i];
        datos += lacing;
        enCurso += lacing;
        if (lacing < 255) {
          depagina.add(enCurso);
          enCurso = 0;
        }
      }
      if (finTabla + datos > bytes.length) break;

      final granulo = ByteData.sublistView(bytes, pos + 6, pos + 14)
          .getUint64(0, Endian.little);

      if (!vistaCabecera) {
        // La primera página lleva OpusHead; su pre-skip son muestras de
        // calentamiento del códec que no llegan a sonar.
        if (finTabla + 12 <= bytes.length) {
          preSkip = bytes[finTabla + 10] | (bytes[finTabla + 11] << 8);
        }
        vistaCabecera = true;
      } else if (granulo > 0) {
        // Las páginas de cabecera (OpusTags) van con granulo 0; las que no
        // completan ningún paquete, con -1. Ni unas ni otras aportan audio.
        ultimoGranulo = granulo;
        paquetes.addAll(depagina);
      }

      pos = finTabla + datos;
    }

    if (paquetes.isEmpty) return null;

    final muestrasTotales = ultimoGranulo - preSkip;
    if (muestrasTotales <= 0) return null;

    return AnalisisOpus(
      Duration(milliseconds: (muestrasTotales * 1000) ~/ 48000),
      _onda(paquetes),
    );
  } catch (_) {
    return null;
  }
}

/// Reparte los paquetes entre las barras y estira el resultado al rango que
/// realmente ocupa.
///
/// Sin estirar no se vería nada: el habla se mueve en una franja estrecha y
/// todas las barras saldrían igual de altas. Normalizando entre el mínimo y el
/// máximo del propio audio, las pausas bajan y el habla sube. Se deja un suelo
/// para que un silencio siga dibujando algo y la onda no aparezca cortada.
List<int> _onda(List<int> paquetes) {
  final n = paquetes.length;
  final medias = <double>[];

  for (var i = 0; i < barrasOnda; i++) {
    var desde = (i * n / barrasOnda).floor();
    var hasta = ((i + 1) * n / barrasOnda).ceil();
    if (hasta <= desde) hasta = desde + 1;
    if (hasta > n) hasta = n;
    if (desde >= n) desde = n - 1;

    var suma = 0;
    for (var p = desde; p < hasta; p++) {
      suma += paquetes[p];
    }
    medias.add(suma / (hasta - desde));
  }

  final minimo = medias.reduce(math.min);
  final maximo = medias.reduce(math.max);
  if (maximo <= minimo) return List<int>.filled(barrasOnda, 60);

  const suelo = 12;
  return [
    for (final media in medias)
      (suelo + (media - minimo) / (maximo - minimo) * (100 - suelo))
          .round()
          .clamp(0, 100),
  ];
}

bool _esOggS(List<int> bytes, int pos) =>
    pos + 4 <= bytes.length &&
    bytes[pos] == 0x4F &&
    bytes[pos + 1] == 0x67 &&
    bytes[pos + 2] == 0x67 &&
    bytes[pos + 3] == 0x53;
