import 'package:intl/intl.dart';

const String localeApp = 'es_ES';

final DateFormat _horaCorta = DateFormat('HH:mm', localeApp);
final DateFormat _diaLargo = DateFormat("EEEE, d 'de' MMMM", localeApp);
final DateFormat _diaLargoConAnio = DateFormat("EEEE, d 'de' MMMM 'de' y", localeApp);
final DateFormat _diaCorto = DateFormat('d MMM y', localeApp);

String hora(DateTime fecha) => _horaCorta.format(fecha);

String fechaCorta(DateTime fecha) => _diaCorto.format(fecha);

/// Duración en `m:ss`, o `h:mm:ss` si pasa de la hora.
String duracion(Duration? d) {
  if (d == null) return '--:--';
  final horas = d.inHours;
  final minutos = d.inMinutes.remainder(60).toString().padLeft(horas > 0 ? 2 : 1, '0');
  final segundos = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return horas > 0 ? '$horas:$minutos:$segundos' : '$minutos:$segundos';
}

/// Encabezado de un día: "Hoy", "Ayer" o la fecha escrita, con mayúscula.
String etiquetaDia(DateTime dia, {DateTime? ahora}) {
  final hoy = _soloDia(ahora ?? DateTime.now());
  final objetivo = _soloDia(dia);
  final diferencia = hoy.difference(objetivo).inDays;

  if (diferencia == 0) return 'Hoy';
  if (diferencia == 1) return 'Ayer';

  final texto = objetivo.year == hoy.year
      ? _diaLargo.format(objetivo)
      : _diaLargoConAnio.format(objetivo);
  return texto[0].toUpperCase() + texto.substring(1);
}

String tamano(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// "3 audios" / "1 audio".
String cuentaAudios(int n) => n == 1 ? '1 audio' : '$n audios';

DateTime _soloDia(DateTime f) => DateTime(f.year, f.month, f.day);
