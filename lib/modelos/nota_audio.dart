import 'dart:convert';
import 'dart:typed_data';

/// Una nota de voz o archivo de audio encontrado en las carpetas de WhatsApp.
///
/// Todos los datos caros de obtener (fecha, tamaño, duración, onda) se calculan
/// una sola vez y se guardan aquí, para que la interfaz nunca tenga que tocar
/// el disco mientras dibuja una lista.
class NotaAudio {
  /// Ruta absoluta del archivo.
  final String ruta;

  /// Momento en que se recibió el audio.
  final DateTime fecha;

  /// Tamaño en bytes.
  final int tamano;

  /// Duración real del audio. `null` mientras no se haya calculado todavía.
  final Duration? duracion;

  /// Amplitud a lo largo del audio, de 0 a 100. Vacía si aún no se ha
  /// analizado el archivo.
  final List<int> onda;

  const NotaAudio({
    required this.ruta,
    required this.fecha,
    required this.tamano,
    this.duracion,
    this.onda = const [],
  });

  String get nombre => ruta.substring(ruta.lastIndexOf('/') + 1);

  /// Fecha normalizada a medianoche: la clave con la que agrupamos por día.
  DateTime get dia => DateTime(fecha.year, fecha.month, fecha.day);

  /// WhatsApp nombra las notas de voz como `PTT-20240115-WA0003.opus` y los
  /// audios enviados como archivo `AUD-...`.
  bool get esNotaDeVoz => nombre.startsWith('PTT');

  /// Cierto cuando ya se intentó analizar el archivo con el analizador actual.
  ///
  /// No basta con tener duración: una caché escrita por una versión anterior
  /// puede traer duración y no onda, y dar eso por analizado dejaría la onda
  /// vacía para siempre. Un análisis bueno siempre deja onda; uno fallido deja
  /// `Duration.zero`, que es la marca de "ya lo intentamos y no se pudo".
  bool get analizado =>
      duracion != null && (onda.isNotEmpty || duracion == Duration.zero);

  NotaAudio conAnalisis(Duration? nuevaDuracion, List<int> nuevaOnda) =>
      NotaAudio(
        ruta: ruta,
        fecha: fecha,
        tamano: tamano,
        duracion: nuevaDuracion,
        onda: nuevaOnda,
      );

  /// Serialización compacta en lista: con miles de audios pesa e interpreta
  /// bastante menos que un mapa con claves repetidas. La onda va en base64
  /// porque como lista de números ocuparía unas cinco veces más.
  List<Object?> aJson() => [
        ruta,
        fecha.millisecondsSinceEpoch,
        tamano,
        duracion?.inMilliseconds,
        onda.isEmpty ? null : base64Encode(Uint8List.fromList(onda)),
      ];

  static NotaAudio? desdeJson(Object? fila) {
    if (fila is! List || fila.length < 4) return null;
    final ruta = fila[0];
    final ms = fila[1];
    final tamano = fila[2];
    final duracionMs = fila[3];
    if (ruta is! String || ms is! int || tamano is! int) return null;

    var onda = const <int>[];
    if (fila.length > 4 && fila[4] is String) {
      try {
        onda = base64Decode(fila[4] as String);
      } catch (_) {
        onda = const [];
      }
    }

    return NotaAudio(
      ruta: ruta,
      fecha: DateTime.fromMillisecondsSinceEpoch(ms),
      tamano: tamano,
      duracion: duracionMs is int ? Duration(milliseconds: duracionMs) : null,
      onda: onda,
    );
  }

  @override
  bool operator ==(Object other) => other is NotaAudio && other.ruta == ruta;

  @override
  int get hashCode => ruta.hashCode;
}
