import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:waudios/modelos/nota_audio.dart';
import 'package:waudios/pantallas/vista_recientes.dart';
import 'package:waudios/servicios/duracion_opus.dart';
import 'package:waudios/servicios/servicio_reproduccion.dart';
import 'package:waudios/widgets/formato.dart' as fmt;

void main() {
  setUpAll(() async {
    await initializeDateFormatting(fmt.localeApp, null);
  });

  group('NotaAudio', () {
    final nota = NotaAudio(
      ruta: '/storage/emulated/0/WhatsApp/PTT-20240115-WA0003.opus',
      fecha: DateTime(2024, 1, 15, 19, 42, 7),
      tamano: 12345,
      duracion: const Duration(seconds: 83),
    );

    test('deriva nombre, día y tipo desde la ruta', () {
      expect(nota.nombre, 'PTT-20240115-WA0003.opus');
      expect(nota.dia, DateTime(2024, 1, 15));
      expect(nota.esNotaDeVoz, isTrue);
    });

    test('distingue un audio enviado como archivo de una nota de voz', () {
      final audio = NotaAudio(
        ruta: '/x/AUD-20240115-WA0001.mp3',
        fecha: DateTime(2024, 1, 15),
        tamano: 1,
      );
      expect(audio.esNotaDeVoz, isFalse);
    });

    test('sobrevive a una ida y vuelta por JSON', () {
      final copia = NotaAudio.desdeJson(nota.aJson())!;
      expect(copia.ruta, nota.ruta);
      expect(copia.fecha, nota.fecha);
      expect(copia.tamano, nota.tamano);
      expect(copia.duracion, nota.duracion);
    });

    test('ignora filas de caché corruptas en vez de reventar', () {
      expect(NotaAudio.desdeJson(null), isNull);
      expect(NotaAudio.desdeJson(['solo', 'la', 'ruta']), isNull);
      expect(NotaAudio.desdeJson(['/x.opus', 'no-es-int', 1, null]), isNull);
    });

    test('conDuracion no toca el resto de campos', () {
      final medida = nota.conDuracion(const Duration(seconds: 5));
      expect(medida.duracion, const Duration(seconds: 5));
      expect(medida.ruta, nota.ruta);
      expect(medida.fecha, nota.fecha);
    });
  });

  group('formato', () {
    test('duración en m:ss y h:mm:ss', () {
      expect(fmt.duracion(const Duration(seconds: 7)), '0:07');
      expect(fmt.duracion(const Duration(minutes: 1, seconds: 23)), '1:23');
      expect(fmt.duracion(const Duration(minutes: 75, seconds: 4)), '1:15:04');
      expect(fmt.duracion(null), '--:--');
    });

    test('etiqueta relativa para hoy y ayer', () {
      final ahora = DateTime(2024, 3, 10, 12);
      expect(fmt.etiquetaDia(DateTime(2024, 3, 10, 8), ahora: ahora), 'Hoy');
      expect(fmt.etiquetaDia(DateTime(2024, 3, 9, 23), ahora: ahora), 'Ayer');
      expect(
        fmt.etiquetaDia(DateTime(2024, 3, 1), ahora: ahora),
        startsWith('V'), // "Viernes, 1 de marzo", con inicial en mayúscula
      );
    });

    test('cuenta de audios en singular y plural', () {
      expect(fmt.cuentaAudios(1), '1 audio');
      expect(fmt.cuentaAudios(4), '4 audios');
    });
  });

  group('ventanaReciente', () {
    final ahora = DateTime(2024, 6, 30, 12);

    List<NotaAudio> hechaDe(List<int> diasDeAntiguedad) => [
          for (final d in diasDeAntiguedad)
            NotaAudio(
              ruta: '/x/a$d.opus',
              fecha: ahora.subtract(Duration(days: d)),
              tamano: 1,
            ),
        ];

    test('se queda con lo del último mes cuando hay de sobra', () {
      // 100 audios repartidos por los últimos 25 días (uno cada 6 h) y 50 muy
      // antiguos detrás, en el orden en que los da el índice: del más nuevo al
      // más viejo.
      final todas = [
        for (var i = 0; i < 100; i++)
          NotaAudio(
            ruta: '/x/r$i.opus',
            fecha: ahora.subtract(Duration(hours: i * 6)),
            tamano: 1,
          ),
        ...hechaDe([for (var d = 0; d < 50; d++) 40 + d]),
      ];

      final ventana = ventanaReciente(todas, ahora: ahora);

      expect(ventana.length, 100);
      expect(
        ventana.last.fecha.isAfter(ahora.subtract(const Duration(days: 30))),
        isTrue,
      );
    });

    test('nunca deja la pantalla casi vacía si no hay nada reciente', () {
      // Todos de hace más de un año: ninguno entra por fecha.
      final todas = hechaDe([for (var i = 0; i < 100; i++) 400 + i]);
      final ventana = ventanaReciente(todas, ahora: ahora);
      expect(ventana.length, minimoRecientes);
    });

    test('con pocos audios los devuelve todos', () {
      final todas = hechaDe([500, 600, 700]);
      expect(ventanaReciente(todas, ahora: ahora).length, 3);
    });

    test('con la lista vacía no revienta', () {
      expect(ventanaReciente(const [], ahora: ahora), isEmpty);
    });
  });

  group('construirCola', () {
    NotaAudio audio(String nombre, DateTime cuando) =>
        NotaAudio(ruta: '/x/$nombre.opus', fecha: cuando, tamano: 1);

    final a2001 = audio('a', DateTime(2024, 5, 2, 20, 1));
    final a2005 = audio('b', DateTime(2024, 5, 2, 20, 5));
    final a2010 = audio('c', DateTime(2024, 5, 2, 20, 10));

    // Como se ven en "Recientes": del más nuevo al más viejo.
    final comoSeVen = [a2010, a2005, a2001];

    test('encadena hacia delante en el tiempo, no hacia atrás', () {
      final cola = construirCola(comoSeVen, a2001, (_) => false);
      expect(cola.map((n) => n.fecha.minute), [1, 5, 10]);
    });

    test('deja fuera lo ya escuchado', () {
      final cola = construirCola(comoSeVen, a2001, (r) => r == a2005.ruta);
      expect(cola.map((n) => n.fecha.minute), [1, 10]);
    });

    test('el audio pulsado entra aunque ya esté escuchado', () {
      final cola = construirCola(comoSeVen, a2005, (_) => true);
      expect(cola, [a2005]);
    });

    test('con todo escuchado y sin pulsar nada ajeno, la cola es solo ese', () {
      final cola = construirCola(comoSeVen, a2010, (_) => true);
      expect(cola.single.ruta, a2010.ruta);
    });
  });

  group('leerDuracionOgg', () {
    late Directory temporal;

    setUp(() => temporal = Directory.systemTemp.createTempSync('waudios'));
    tearDown(() => temporal.deleteSync(recursive: true));

    File escribir(String nombre, List<int> bytes) {
      final f = File('${temporal.path}/$nombre');
      f.writeAsBytesSync(bytes);
      return f;
    }

    test('calcula la duración desde la última granule position', () {
      // 48000 muestras/s: 96000 muestras = 2 s, menos 312 de pre-skip.
      final ogg = _oggSintetico(granuloFinal: 96000, preSkip: 312);
      final ruta = escribir('nota.opus', ogg).path;

      final duracion = leerDuracionOgg(ruta);
      expect(duracion, isNotNull);
      expect(duracion!.inMilliseconds, ((96000 - 312) * 1000) ~/ 48000);
    });

    test('descuenta el pre-skip declarado en OpusHead', () {
      final sinPreSkip = leerDuracionOgg(
          escribir('a.opus', _oggSintetico(granuloFinal: 48000, preSkip: 0))
              .path)!;
      final conPreSkip = leerDuracionOgg(
          escribir('b.opus', _oggSintetico(granuloFinal: 48000, preSkip: 4800))
              .path)!;
      expect(sinPreSkip.inMilliseconds, 1000);
      expect(conPreSkip.inMilliseconds, 900);
    });

    test('devuelve null en archivos que no son Ogg', () {
      expect(leerDuracionOgg(escribir('x.mp3', List.filled(500, 0x41)).path),
          isNull);
    });

    test('devuelve null en archivos truncados o inexistentes', () {
      expect(leerDuracionOgg(escribir('corto.opus', [0x4F, 0x67]).path), isNull);
      expect(leerDuracionOgg('${temporal.path}/no-existe.opus'), isNull);
    });

    test('no se confunde con una firma OggS dentro del audio', () {
      // Metemos "OggS" con un byte de versión inválido en medio del payload:
      // el parser debe seguir usando la última cabecera de página real.
      final ogg = _oggSintetico(
        granuloFinal: 48000,
        preSkip: 0,
        rellenoFinal: [0x4F, 0x67, 0x67, 0x53, 0x07, 0x00, 0x00, 0x00],
      );
      expect(leerDuracionOgg(escribir('c.opus', ogg).path)?.inMilliseconds,
          1000);
    });
  });
}

/// Construye un Ogg mínimo pero estructuralmente válido: una primera página con
/// la cabecera `OpusHead` y una última página con la granule position dada.
/// El CRC va a cero a propósito: el lector no lo verifica.
List<int> _oggSintetico({
  required int granuloFinal,
  required int preSkip,
  List<int> rellenoFinal = const [],
}) {
  final opusHead = <int>[
    ...'OpusHead'.codeUnits,
    1, // versión
    1, // canales
    preSkip & 0xFF, (preSkip >> 8) & 0xFF,
    0x80, 0xBB, 0x00, 0x00, // 48000 Hz
    0, 0, // ganancia
    0, // mapping family
  ];

  return [
    ..._pagina(granulo: 0, secuencia: 0, payload: opusHead),
    ..._pagina(
      granulo: granuloFinal,
      secuencia: 1,
      payload: [...List.filled(40, 0xAA), ...rellenoFinal],
    ),
  ];
}

List<int> _pagina({
  required int granulo,
  required int secuencia,
  required List<int> payload,
}) {
  final granuloBytes = Uint8List(8);
  ByteData.sublistView(granuloBytes).setUint64(0, granulo, Endian.little);

  // El payload se trocea en segmentos de 255 bytes como manda el formato.
  final segmentos = <int>[];
  var restante = payload.length;
  while (restante >= 255) {
    segmentos.add(255);
    restante -= 255;
  }
  segmentos.add(restante);

  return [
    ...'OggS'.codeUnits,
    0, // versión
    secuencia == 0 ? 0x02 : 0x04, // primera página / última página
    ...granuloBytes,
    0x01, 0x00, 0x00, 0x00, // serial
    secuencia & 0xFF, 0, 0, 0,
    0, 0, 0, 0, // CRC
    segmentos.length,
    ...segmentos,
    ...payload,
  ];
}
