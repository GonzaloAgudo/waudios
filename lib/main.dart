import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WAudios',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const PantallaCalendario(),
    );
  }
}

class PantallaCalendario extends StatefulWidget {
  const PantallaCalendario({super.key});

  @override
  State<PantallaCalendario> createState() => _PantallaCalendarioState();
}

class _PantallaCalendarioState extends State<PantallaCalendario> {
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _mesEnfocado = DateTime.now();

  Map<DateTime, List<FileSystemEntity>> _audiosCacheados = {};
  List<FileSystemEntity> _audiosDelDia = [];

  bool _estaEscaneandoFondo = true; // Controla la pantalla de carga
  bool _permisosConcedidos = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _solicitarPermisos();
    });
  }

  Future<void> _solicitarPermisos() async {
    var status = await Permission.manageExternalStorage.status;
    var statusStorage = await Permission.storage.status;

    if (!status.isGranted && !statusStorage.isGranted) {
      await Permission.manageExternalStorage.request();
      await Permission.storage.request();
    }

    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted) {
      if (mounted) {
        setState(() => _permisosConcedidos = true);
        _escanearDiscoCompleto(); // Lanzamos la búsqueda de todos los audios primero
      }
    } else {
      // Si deniega los permisos, quitamos la pantalla de carga para que no se quede infinita
      if (mounted) {
        setState(() => _estaEscaneandoFondo = false);
      }
    }
  }

  DateTime _soloDia(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  // NUEVA FUNCIÓN: Escanea todo primero y luego actualiza la interfaz
  Future<void> _escanearDiscoCompleto() async {
    if (!mounted) return;

    // Mostramos la rueda de carga si se llama manualmente desde el botón
    setState(() {
      _estaEscaneandoFondo = true;
    });

    List<String> rutasWhatsApp = [
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio'
    ];

    Map<DateTime, List<FileSystemEntity>> cacheTemporal = {};

    for (String ruta in rutasWhatsApp) {
      final directorio = Directory(ruta);
      if (await directorio.exists()) {
        await for (var entidad in directorio.list(recursive: true, followLinks: false)) {
          if (entidad is File && entidad.path.endsWith('.opus')) {
            final stat = await entidad.stat();
            final fechaNormalizada = _soloDia(stat.modified);

            if (!cacheTemporal.containsKey(fechaNormalizada)) {
              cacheTemporal[fechaNormalizada] = [];
            }
            cacheTemporal[fechaNormalizada]!.add(entidad);
          }
        }
      }
    }

    // Ordenamos todas las listas de cada día
    for (var lista in cacheTemporal.values) {
      lista.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    }

    // Una vez ha terminado todo el proceso, actualizamos la UI de golpe
    if (mounted) {
      setState(() {
        _audiosCacheados = cacheTemporal;
        _estaEscaneandoFondo = false; // Ocultamos la pantalla de carga
        _actualizarListaMostrada(_diaSeleccionado);
      });
    }
  }

  void _actualizarListaMostrada(DateTime fecha) {
    final fechaNormalizada = _soloDia(fecha);
    List<FileSystemEntity> audios = _audiosCacheados[fechaNormalizada] ?? [];

    setState(() {
      _audiosDelDia = List.from(audios);
    });
  }

  void _abrirReproductor(FileSystemEntity audio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReproductorAudioModal(audio: audio),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audios de Whatsapp', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // BOTÓN DE REFRESCAR AÑADIDO
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar audios',
            // Deshabilitamos el botón mientras está cargando para que no lo pulse mil veces
            onPressed: _estaEscaneandoFondo ? null : _escanearDiscoCompleto,
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2010, 1, 1),
            lastDay: DateTime.now(),
            focusedDay: _mesEnfocado,
            locale: 'es_ES',
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(_diaSeleccionado, day),
            onDaySelected: (diaSeleccionado, mesEnfocado) {
              if (!isSameDay(_diaSeleccionado, diaSeleccionado)) {
                setState(() {
                  _diaSeleccionado = diaSeleccionado;
                  _mesEnfocado = mesEnfocado;
                });
                _actualizarListaMostrada(diaSeleccionado);
              }
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),

          const Divider(height: 1, thickness: 1),

          Expanded(
            // Condicional: Si está cargando, mostramos la rueda central. Si no, mostramos la lista.
            child: _estaEscaneandoFondo
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 16),
                  Text('Cargando audios, por favor espera...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : _audiosDelDia.isEmpty
                ? Center(
              child: Text(
                'No hay audios el ${_diaSeleccionado.day}/${_diaSeleccionado.month}/${_diaSeleccionado.year}',
                style: TextStyle(color: Colors.grey[400]),
              ),
            )
                : ListView.builder(
              itemCount: _audiosDelDia.length,
              itemBuilder: (context, index) {
                final audio = _audiosDelDia[index];
                final fecha = audio.statSync().modified;
                final horaStr = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.mic, color: Colors.white),
                  ),
                  title: Text('Audio a las $horaStr'),
                  subtitle: Text(audio.path.split('/').last, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.play_arrow, color: Colors.teal),
                  onTap: () => _abrirReproductor(audio),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET DEL REPRODUCTOR (Mismo que tenías)
// ==========================================
class ReproductorAudioModal extends StatefulWidget {
  final FileSystemEntity audio;
  const ReproductorAudioModal({super.key, required this.audio});

  @override
  State<ReproductorAudioModal> createState() => _ReproductorAudioModalState();
}

class _ReproductorAudioModalState extends State<ReproductorAudioModal> {
  final AudioPlayer _player = AudioPlayer();
  final List<double> _velocidades = [1.0, 1.25, 1.5, 2.0];
  int _indiceVelocidad = 0;

  @override
  void initState() {
    super.initState();
    _iniciarAudio();
  }

  Future<void> _iniciarAudio() async {
    try {
      await _player.setFilePath(widget.audio.path);
      _player.play();
    } catch (e) {
      debugPrint("Error cargando audio: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _cambiarVelocidad() {
    setState(() {
      _indiceVelocidad = (_indiceVelocidad + 1) % _velocidades.length;
      _player.setSpeed(_velocidades[_indiceVelocidad]);
    });
  }

  void _saltarSegundos(int segundos) {
    final posicionActual = _player.position;
    final duracionTotal = _player.duration ?? Duration.zero;

    var nuevaPosicion = posicionActual + Duration(seconds: segundos);
    if (nuevaPosicion < Duration.zero) nuevaPosicion = Duration.zero;
    if (nuevaPosicion > duracionTotal) nuevaPosicion = duracionTotal;

    _player.seek(nuevaPosicion);
  }

  String _formatoTiempo(Duration? duration) {
    if (duration == null) return "0:00";
    String minutos = duration.inMinutes.remainder(60).toString();
    String segundos = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutos:$segundos";
  }

  @override
  Widget build(BuildContext context) {
    final fecha = widget.audio.statSync().modified;
    final hora = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 5,
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),

          Text('Nota de Voz - $hora', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final posicion = snapshot.data ?? Duration.zero;
                final duracionTotal = _player.duration ?? Duration.zero;

                return Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        activeColor: Colors.tealAccent,
                        inactiveColor: Colors.teal.withOpacity(0.2),
                        min: 0.0,
                        max: duracionTotal.inMilliseconds.toDouble(),
                        value: posicion.inMilliseconds.toDouble().clamp(0.0, duracionTotal.inMilliseconds.toDouble()),
                        onChanged: (value) => _player.seek(Duration(milliseconds: value.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatoTiempo(posicion), style: TextStyle(color: Colors.grey[400])),
                          Text(_formatoTiempo(duracionTotal), style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  ],
                );
              }
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: _cambiarVelocidad,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('${_velocidades[_indiceVelocidad]}x', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              ),

              IconButton(
                icon: const Icon(Icons.replay_10, size: 36),
                color: Colors.white,
                onPressed: () => _saltarSegundos(-10),
              ),

              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final estado = snapshot.data;
                  final reproduciendo = estado?.playing ?? false;
                  final terminado = estado?.processingState == ProcessingState.completed;

                  return IconButton(
                    icon: Icon(
                      reproduciendo && !terminado ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      size: 64,
                      color: Colors.tealAccent,
                    ),
                    onPressed: () {
                      if (terminado) {
                        _player.seek(Duration.zero);
                        _player.play();
                      } else if (reproduciendo) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
                  );
                },
              ),

              IconButton(
                icon: const Icon(Icons.forward_10, size: 36),
                color: Colors.white,
                onPressed: () => _saltarSegundos(10),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }
}