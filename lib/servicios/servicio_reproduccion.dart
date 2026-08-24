import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../modelos/nota_audio.dart';

/// Reproductor global de la app.
///
/// A diferencia de crear un `AudioPlayer` por cada hoja modal, aquí hay un solo
/// reproductor con una **cola**: al tocar un audio se encola el día entero, así
/// que al terminar uno empieza el siguiente automáticamente y se puede saltar
/// hacia delante y hacia atrás sin volver a la lista. Eso es lo que hace que
/// ponerse al día con veinte notas seguidas no requiera veinte toques.
class ServicioReproduccion extends ChangeNotifier {
  final AudioPlayer _reproductor = AudioPlayer();

  List<NotaAudio> _cola = const [];
  int _indice = -1;
  double _velocidad = 1.0;

  /// Se avisa cuando un audio se termina, para marcarlo como escuchado.
  void Function(NotaAudio nota)? alTerminarAudio;

  ServicioReproduccion() {
    _reproductor.currentIndexStream.listen((i) {
      if (i == null || i < 0 || i >= _cola.length) return;
      if (i != _indice) {
        _indice = i;
        notifyListeners();
      }
    });

    _reproductor.playerStateStream.listen((estado) {
      if (estado.processingState == ProcessingState.completed) {
        final actual = this.actual;
        if (actual != null) alTerminarAudio?.call(actual);
      }
      notifyListeners();
    });
  }

  AudioPlayer get reproductor => _reproductor;

  List<NotaAudio> get cola => _cola;

  NotaAudio? get actual =>
      _indice >= 0 && _indice < _cola.length ? _cola[_indice] : null;

  int get posicionEnCola => _indice;

  double get velocidad => _velocidad;

  bool get sonando => _reproductor.playing;

  bool get haySiguiente => _indice >= 0 && _indice < _cola.length - 1;

  bool get hayAnterior => _indice > 0;

  bool esActual(NotaAudio nota) => actual?.ruta == nota.ruta;

  Stream<Duration> get posicion => _reproductor.positionStream;

  Stream<PlayerState> get estado => _reproductor.playerStateStream;

  Duration get duracionActual => _reproductor.duration ?? Duration.zero;

  /// Cuántos audios como mucho se cargan en el reproductor de una vez.
  ///
  /// En "Recientes" la lista puede tener miles de elementos y pasárselos todos
  /// a `setAudioSource` significa serializar miles de rutas por el canal de
  /// plataforma en cada toque. Con una ventana alrededor del audio elegido la
  /// reproducción encadenada se sigue notando infinita y el arranque es
  /// inmediato; cuando se llega al borde se recarga sola.
  static const int _maxCola = 200;
  static const int _margenAtras = 40;

  /// Pone a sonar [nota] usando [lista] como contexto de reproducción continua.
  /// Si ya era el audio actual, simplemente alterna play/pausa.
  Future<void> reproducir(NotaAudio nota, List<NotaAudio> lista) async {
    if (esActual(nota)) {
      await alternar();
      return;
    }

    try {
      // Si el audio ya está en la cola cargada, saltar es instantáneo.
      final enCola = _cola.indexWhere((n) => n.ruta == nota.ruta);
      if (enCola >= 0) {
        await _reproductor.seek(Duration.zero, index: enCola);
        _indice = enCola;
      } else {
        final (ventana, posicion) = _ventana(lista, nota);
        _cola = ventana;
        _indice = posicion;
        await _reproductor.setAudioSource(
          ConcatenatingAudioSource(
            children: [
              for (final n in ventana) AudioSource.file(n.ruta),
            ],
          ),
          initialIndex: posicion,
          initialPosition: Duration.zero,
        );
      }
      await _reproductor.setSpeed(_velocidad);
      unawaited(_reproductor.play());
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo reproducir ${nota.ruta}: $e');
    }
  }

  /// Trozo de [lista] alrededor de [nota], y la posición de [nota] dentro de él.
  (List<NotaAudio>, int) _ventana(List<NotaAudio> lista, NotaAudio nota) {
    final pos = lista.indexWhere((n) => n.ruta == nota.ruta);
    if (pos < 0) return (List.unmodifiable([nota]), 0);
    if (lista.length <= _maxCola) return (List.unmodifiable(lista), pos);

    var inicio = pos - _margenAtras;
    if (inicio < 0) inicio = 0;
    var fin = inicio + _maxCola;
    if (fin > lista.length) {
      fin = lista.length;
      inicio = fin - _maxCola;
    }
    return (List.unmodifiable(lista.sublist(inicio, fin)), pos - inicio);
  }

  Future<void> alternar() async {
    if (_reproductor.playing) {
      await _reproductor.pause();
    } else {
      if (_reproductor.processingState == ProcessingState.completed) {
        await _reproductor.seek(Duration.zero);
      }
      unawaited(_reproductor.play());
    }
    notifyListeners();
  }

  Future<void> siguiente() async {
    if (!haySiguiente) return;
    await _reproductor.seek(Duration.zero, index: _indice + 1);
    unawaited(_reproductor.play());
  }

  Future<void> anterior() async {
    // Como en cualquier reproductor: si ya has avanzado, el botón rebobina.
    if (_reproductor.position > const Duration(seconds: 3) || !hayAnterior) {
      await _reproductor.seek(Duration.zero);
      return;
    }
    await _reproductor.seek(Duration.zero, index: _indice - 1);
    unawaited(_reproductor.play());
  }

  Future<void> saltar(int segundos) async {
    final destino = _reproductor.position + Duration(seconds: segundos);
    final tope = _reproductor.duration ?? Duration.zero;
    await _reproductor.seek(
      destino < Duration.zero
          ? Duration.zero
          : (destino > tope ? tope : destino),
    );
  }

  Future<void> buscar(Duration posicion) => _reproductor.seek(posicion);

  static const List<double> velocidades = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75];

  Future<void> cambiarVelocidad() async {
    final siguiente =
        velocidades[(velocidades.indexOf(_velocidad) + 1) % velocidades.length];
    _velocidad = siguiente;
    await _reproductor.setSpeed(siguiente);
    notifyListeners();
  }

  Future<void> parar() async {
    await _reproductor.stop();
    _cola = const [];
    _indice = -1;
    notifyListeners();
  }

  @override
  void dispose() {
    _reproductor.dispose();
    super.dispose();
  }
}
