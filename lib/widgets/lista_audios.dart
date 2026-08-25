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
/// Además de dibujar, es la que pide las duraciones: solo de los elementos que
/// se están construyendo, agrupadas en lotes. Así medir miles de archivos nunca
/// llega a ocurrir; se miden las decenas que el usuario mira de verdad.
class ListaAudios extends StatefulWidget {
  final List<NotaAudio> audios;
  final IndiceAudios indice;
  final ServicioReproduccion reproduccion;

  /// Cabeceras de fecha entre grupos (se usa en Recientes, no dentro de un día).
  final bool agruparPorDia;

  final Widget? cabecera;
  final ScrollController? controlador;

  const ListaAudios({
    super.key,
    required this.audios,
    required this.indice,
    required this.reproduccion,
    this.agruparPorDia = false,
    this.cabecera,
    this.controlador,
  });

  @override
  State<ListaAudios> createState() => _ListaAudiosState();
}

class _ListaAudiosState extends State<ListaAudios> {
  final Set<NotaAudio> _pendientesDeMedir = {};
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

  /// Acumula lo que se va construyendo y lo manda a medir de golpe.
  void _pedirDuracion(NotaAudio nota) {
    if (nota.duracion != null) return;
    _pendientesDeMedir.add(nota);
    _loteDiferido?.cancel();
    _loteDiferido = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || _pendientesDeMedir.isEmpty) return;
      final lote = _pendientesDeMedir.toList();
      _pendientesDeMedir.clear();
      widget.indice.asegurarDuraciones(lote);
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
              leading: Icon(Icons.info_outline, color: colores.primary),
              title: Text(nota.nombre),
              subtitle: Text(
                '${fmt.etiquetaDia(nota.fecha)} a las ${fmt.hora(nota.fecha)}'
                ' · ${fmt.tamano(nota.tamano)}'
                '${nota.duracion != null && nota.duracion! > Duration.zero ? ' · ${fmt.duracion(nota.duracion)}' : ''}',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartir audio'),
              onTap: () {
                Navigator.pop(contexto);
                _compartir(nota);
              },
            ),
            ListTile(
              leading: Icon(
                widget.indice.estaEscuchado(nota.ruta)
                    ? Icons.mark_email_unread_outlined
                    : Icons.done_all,
              ),
              title: Text(
                widget.indice.estaEscuchado(nota.ruta)
                    ? 'Ya marcado como escuchado'
                    : 'Marcar como escuchado',
              ),
              enabled: !widget.indice.estaEscuchado(nota.ruta),
              onTap: () {
                Navigator.pop(contexto);
                widget.indice.marcarEscuchado(nota.ruta);
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
    // La cola de reproducción continua son solo los audios pendientes: al
    // terminar uno no queremos que arranque algo que ya se había escuchado.
    // El pulsado entra siempre, aunque ya esté escuchado, porque ahí la
    // decisión es explícita del usuario.
    final cola = [
      for (final audio in widget.audios)
        if (audio.ruta == nota.ruta || !widget.indice.estaEscuchado(audio.ruta))
          audio,
    ];
    widget.reproduccion.reproducir(nota, cola);
  }

  @override
  Widget build(BuildContext context) {
    if (!identical(_audiosDeLaCache, widget.audios)) {
      _audiosDeLaCache = widget.audios;
      _elementosCacheados = _construirElementos();
    }
    final elementos = _elementosCacheados!;

    return ListView.builder(
      controller: widget.controlador,
      padding: const EdgeInsets.only(bottom: 24),
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
        _pedirDuracion(nota);

        return TarjetaAudio(
          nota: nota,
          esActual: widget.reproduccion.esActual(nota),
          sonando: widget.reproduccion.sonando,
          escuchado: widget.indice.estaEscuchado(nota.ruta),
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
      return elementos;
    }

    DateTime? diaAnterior;
    for (final nota in widget.audios) {
      final dia = nota.dia;
      if (diaAnterior == null || dia != diaAnterior) {
        elementos.add(dia);
        diaAnterior = dia;
      }
      elementos.add(nota);
    }
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            fmt.etiquetaDia(dia),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colores.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: colores.outlineVariant, height: 1),
          ),
          const SizedBox(width: 10),
          Text(
            '$cuantos',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colores.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
