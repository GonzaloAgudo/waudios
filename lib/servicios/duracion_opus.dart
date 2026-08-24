import 'dart:io';
import 'dart:typed_data';

/// Lee la duración de un audio Ogg/Opus (el formato de las notas de voz de
/// WhatsApp) directamente del contenedor, sin abrir un reproductor.
///
/// Un Ogg guarda en cada página una "granule position": el número de muestras
/// decodificadas hasta ese punto. La última página contiene por tanto el total.
/// Para Opus el reloj es siempre de 48 kHz, así que basta con leer los últimos
/// kilobytes del fichero y dividir. Es del orden de mil veces más barato que
/// instanciar un `AudioPlayer` por archivo, y se puede hacer en un isolate.
///
/// Devuelve `null` si el archivo no es Ogg o está corrupto.
Duration? leerDuracionOgg(String ruta) {
  RandomAccessFile? f;
  try {
    f = File(ruta).openSync();
    final largo = f.lengthSync();
    if (largo < 60) return null;

    // La primera página lleva la cabecera "OpusHead", cuyo campo `pre-skip`
    // (bytes 10-11) son muestras de calentamiento del códec que no suenan.
    final cabecera = f.readSync(1024);
    if (!_empiezaPor(cabecera, _magicoOggS)) return null;

    var preSkip = 0;
    final posHead = _primerIndice(cabecera, _magicoOpusHead);
    if (posHead >= 0 && posHead + 12 <= cabecera.length) {
      preSkip = cabecera[posHead + 10] | (cabecera[posHead + 11] << 8);
    }

    // Buscamos hacia atrás la última página del fichero. 64 KB sobran: una
    // página de Ogg ocupa como mucho unos 64 KB.
    const ventana = 65536;
    final desde = largo > ventana ? largo - ventana : 0;
    f.setPositionSync(desde);
    final cola = f.readSync(largo - desde);

    final posPagina = _ultimoIndicePagina(cola);
    if (posPagina < 0) return null;

    final granulo = ByteData.sublistView(cola, posPagina + 6, posPagina + 14)
        .getUint64(0, Endian.little);
    // -1 en complemento a dos: página sin muestras completadas.
    if (granulo < 0 || granulo == 0xFFFFFFFFFFFFFFFF) return null;

    final muestras = granulo - preSkip;
    if (muestras <= 0) return null;

    return Duration(milliseconds: (muestras * 1000) ~/ 48000);
  } catch (_) {
    return null;
  } finally {
    try {
      f?.closeSync();
    } catch (_) {}
  }
}

const List<int> _magicoOggS = [0x4F, 0x67, 0x67, 0x53]; // "OggS"
const List<int> _magicoOpusHead = [
  0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64 // "OpusHead"
];

bool _empiezaPor(List<int> datos, List<int> patron) {
  if (datos.length < patron.length) return false;
  for (var i = 0; i < patron.length; i++) {
    if (datos[i] != patron[i]) return false;
  }
  return true;
}

int _primerIndice(List<int> datos, List<int> patron) {
  final tope = datos.length - patron.length;
  for (var i = 0; i <= tope; i++) {
    var coincide = true;
    for (var j = 0; j < patron.length; j++) {
      if (datos[i + j] != patron[j]) {
        coincide = false;
        break;
      }
    }
    if (coincide) return i;
  }
  return -1;
}

/// Última cabecera de página válida dentro del bloque. La firma "OggS" puede
/// aparecer por casualidad dentro del audio comprimido, así que exigimos
/// además que el byte de versión sea 0 y que quepa la cabecera entera.
int _ultimoIndicePagina(List<int> datos) {
  for (var i = datos.length - 27; i >= 0; i--) {
    if (datos[i] != 0x4F ||
        datos[i + 1] != 0x67 ||
        datos[i + 2] != 0x67 ||
        datos[i + 3] != 0x53) {
      continue;
    }
    if (datos[i + 4] != 0x00) continue; // versión del formato
    return i;
  }
  return -1;
}
