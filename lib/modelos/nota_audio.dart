/// Una nota de voz o archivo de audio encontrado en las carpetas de WhatsApp.
///
/// Todos los datos caros de obtener (fecha, tamaño, duración) se calculan una
/// sola vez durante el escaneo y se guardan aquí, para que la interfaz nunca
/// tenga que tocar el disco mientras dibuja una lista.
class NotaAudio {
  /// Ruta absoluta del archivo.
  final String ruta;

  /// Momento en que se recibió el audio.
  final DateTime fecha;

  /// Tamaño en bytes.
  final int tamano;

  /// Duración real del audio. `null` mientras no se haya calculado todavía.
  final Duration? duracion;

  const NotaAudio({
    required this.ruta,
    required this.fecha,
    required this.tamano,
    this.duracion,
  });

  String get nombre => ruta.substring(ruta.lastIndexOf('/') + 1);

  /// Fecha normalizada a medianoche: la clave con la que agrupamos por día.
  DateTime get dia => DateTime(fecha.year, fecha.month, fecha.day);

  /// WhatsApp nombra las notas de voz como `PTT-20240115-WA0003.opus` y los
  /// audios enviados como archivo `AUD-...`.
  bool get esNotaDeVoz => nombre.startsWith('PTT');

  NotaAudio conDuracion(Duration? nueva) => NotaAudio(
        ruta: ruta,
        fecha: fecha,
        tamano: tamano,
        duracion: nueva,
      );

  /// Serialización compacta en lista: con miles de audios pesa e interpreta
  /// bastante menos que un mapa con claves repetidas.
  List<Object?> aJson() => [
        ruta,
        fecha.millisecondsSinceEpoch,
        tamano,
        duracion?.inMilliseconds,
      ];

  static NotaAudio? desdeJson(Object? fila) {
    if (fila is! List || fila.length < 4) return null;
    final ruta = fila[0];
    final ms = fila[1];
    final tamano = fila[2];
    final duracionMs = fila[3];
    if (ruta is! String || ms is! int || tamano is! int) return null;
    return NotaAudio(
      ruta: ruta,
      fecha: DateTime.fromMillisecondsSinceEpoch(ms),
      tamano: tamano,
      duracion: duracionMs is int ? Duration(milliseconds: duracionMs) : null,
    );
  }

  @override
  bool operator ==(Object other) => other is NotaAudio && other.ruta == ruta;

  @override
  int get hashCode => ruta.hashCode;
}
