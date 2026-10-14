import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../modelos/nota_audio.dart';
import '../servicios/indice_audios.dart';
import '../servicios/servicio_reproduccion.dart';
import 'formato.dart' as fmt;
import 'tarjeta_audio.dart';

/// Lista de audios reutilizable (la usan tanto Recientes como Calendario).
///
/// Además de dibujar, es la que pide el análisis de los archivos: solo de los
/// elementos que se están construyendo y en lotes. Así analizar miles de
/// audios nunca llega a ocurrir; se analizan las decenas que se miran.
class ListaAudios extends StatefulWidget {
  final List<NotaAudio> audios;
  final IndiceAudios indice;
  final ServicioReproduccion reproduccion;

  /// Cabeceras de fecha entre grupos (se usa en Recientes, no dentro de un día).
  final bool agruparPorDia;

  final Widget? cabecera;

  /// Se dibuja tras el último audio (por ejemplo, el enlace al archivo).
  final Widget? pie;

  const ListaAudios({
    super.key,
    required this.audios,
    required this.indice,
    required this.reproduccion,
    this.agruparPorDia = false,
    this.cabecera,
    this.pie,
  });

  @override
  State<ListaAudios> createState() => _ListaAudiosState();
}

class _ListaAudiosState extends State<ListaAudios> {
  final Set<NotaAudio> _pendientesDeAnalizar = {};
  Timer? _loteDiferido;

  /// La lista aplanada se recalcula solo cuando cambian de verdad los audios.
  /// Sin esto se reconstruiría entera con cada play/pausa, que con miles de
  /// elementos es trabajo tirado a la basura en mitad de una animación.
  List<Object>? _elementosCacheados;
  List<NotaAudio>? _audiosDeLaCache;

  @override
  void dispose() {
    _loteDiferido?.cancel();
    super.dispose();
  }

  /// Acumula lo que se va construyendo y lo manda a analizar de golpe.
  void _pedirAnalisis(NotaAudio nota) {
    if (nota.analizado) return;
    _pendientesDeAnalizar.add(nota);
    _loteDiferido?.cancel();
    _loteDiferido = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || _pendientesDeAnalizar.isEmpty) return;
      final lote = _pendientesDeAnalizar.toList();
      _pendientesDeAnalizar.clear();
      widget.indice.asegurarAnalisis(lote);
    });
  }

  Future<void> _opciones(NotaAudio nota) async {
    final colores = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                nota.esNotaDeVoz ? Icons.mic_none_rounded : Icons.audiotrack,
                color: colores.primary,
              ),
              title: Text(nota.nombre),
              subtitle: Text(
                '${fmt.etiquetaDia(nota.fecha)} a las ${fmt.hora(nota.fecha)}'
                ' · ${fmt.tamano(nota.tamano)}'
                '${nota.duracion != null && nota.duracion! > Duration.zero ? ' · ${fmt.duracion(nota.duracion)}' : ''}',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartir audio'),
              onTap: () {
                Navigator.pop(contexto);
                _compartir(nota);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _compartir(NotaAudio nota) async {
    try {
      await Share.shareXFiles(
        [XFile(nota.ruta)],
        subject: 'Nota de voz ${fmt.fechaCorta(nota.fecha)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir: $e')),
      );
    }
  }

  void _reproducir(NotaAudio nota) {
    widget.reproduccion.reproducir(nota, construirCola(widget.audios));
  }

  @override
  Widget build(BuildContext context) {
    if (!identical(_audiosDeLaCache, widget.audios)) {
      _audiosDeLaCache = widget.audios;
      _elementosCacheados = _construirElementos();
    }
    final elementos = _elementosCacheados!;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: elementos.length,
      itemBuilder: (context, i) {
        final elemento = elementos[i];

        if (elemento is Widget) return elemento;

        if (elemento is DateTime) {
          return _CabeceraDia(
            dia: elemento,
            cuantos: widget.indice.cuentaDelDia(elemento),
          );
        }

        final nota = elemento as NotaAudio;
        _pedirAnalisis(nota);

        return TarjetaAudio(
          nota: nota,
          esActual: widget.reproduccion.esActual(nota),
          sonando: widget.reproduccion.sonando,
          reproduccion: widget.reproduccion,
          alPulsar: () => _reproducir(nota),
          alPulsarMas: () => _opciones(nota),
        );
      },
    );
  }

  /// Mezcla cabeceras y audios en una única lista plana para que `ListView`
  /// siga construyendo solo lo visible.
  List<Object> _construirElementos() {
    final elementos = <Object>[];
    if (widget.cabecera != null) elementos.add(widget.cabecera!);

    if (!widget.agruparPorDia) {
      elementos.addAll(widget.audios);
    } else {
      DateTime? diaAnterior;
      for (final nota in widget.audios) {
        final dia = nota.dia;
        if (diaAnterior == null || dia != diaAnterior) {
          elementos.add(dia);
          diaAnterior = dia;
        }
        elementos.add(nota);
      }
    }

    if (widget.pie != null) elementos.add(widget.pie!);
    return elementos;
  }
}

class _CabeceraDia extends StatelessWidget {
  final DateTime dia;
  final int cuantos;

  const _CabeceraDia({required this.dia, required this.cuantos});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            fmt.etiquetaDia(dia).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colores.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
          ),
          const SizedBox(width: 12),
          Text(
            '$cuantos',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colores.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}
