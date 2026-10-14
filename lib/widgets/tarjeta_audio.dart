import 'package:flutter/material.dart';

import '../modelos/nota_audio.dart';
import '../servicios/servicio_reproduccion.dart';
import 'formato.dart' as fmt;
import 'onda_audio.dart';

/// Fila de la lista de audios.
///
/// La onda es la que manda visualmente: es lo que distingue de un vistazo un
/// audio corto de una parrafada, y en el que está sonando hace de barra de
/// progreso. Todo lo que pinta sale del modelo ya cargado; nunca toca el disco
/// durante el `build`.
class TarjetaAudio extends StatelessWidget {
  final NotaAudio nota;
  final bool esActual;
  final bool sonando;
  final ServicioReproduccion reproduccion;
  final VoidCallback alPulsar;
  final VoidCallback alPulsarMas;

  const TarjetaAudio({
    super.key,
    required this.nota,
    required this.esActual,
    required this.sonando,
    required this.reproduccion,
    required this.alPulsar,
    required this.alPulsarMas,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    final duracionConocida =
        nota.duracion != null && nota.duracion! > Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: esActual ? colores.surfaceContainerHigh : colores.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: alPulsar,
          onLongPress: alPulsarMas,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _BotonPlay(
                  esActual: esActual,
                  sonando: sonando,
                  esNotaDeVoz: nota.esNotaDeVoz,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fmt.hora(nota.fecha),
                            style: textos.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: esActual
                                  ? colores.primary
                                  : colores.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Spacer(),
                          if (duracionConocida)
                            Text(
                              fmt.duracion(nota.duracion),
                              style: textos.bodySmall?.copyWith(
                                color: colores.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _Onda(
                        nota: nota,
                        esActual: esActual,
                        reproduccion: reproduccion,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  color: colores.onSurfaceVariant,
                  tooltip: 'Opciones',
                  onPressed: alPulsarMas,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La onda solo se suscribe a la posición cuando es el audio que suena; el
/// resto de filas son estáticas y no gastan nada.
class _Onda extends StatelessWidget {
  final NotaAudio nota;
  final bool esActual;
  final ServicioReproduccion reproduccion;

  const _Onda({
    required this.nota,
    required this.esActual,
    required this.reproduccion,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final apagada = colores.onSurfaceVariant.withValues(alpha: 0.45);

    if (!esActual) {
      return OndaAudio(
        onda: nota.onda,
        color: apagada,
        colorReproducido: apagada,
      );
    }

    return StreamBuilder<Duration>(
      stream: reproduccion.posicion,
      builder: (context, snapshot) {
        final total = reproduccion.duracionActual;
        final progreso = total.inMilliseconds == 0
            ? 0.0
            : (snapshot.data ?? Duration.zero).inMilliseconds /
                total.inMilliseconds;
        return OndaAudio(
          onda: nota.onda,
          color: colores.onSurfaceVariant.withValues(alpha: 0.35),
          colorReproducido: colores.primary,
          progreso: progreso,
        );
      },
    );
  }
}

class _BotonPlay extends StatelessWidget {
  final bool esActual;
  final bool sonando;
  final bool esNotaDeVoz;

  const _BotonPlay({
    required this.esActual,
    required this.sonando,
    required this.esNotaDeVoz,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final encendido = esActual && sonando;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: esActual
            ? colores.primary
            : colores.onSurface.withValues(alpha: 0.07),
      ),
      child: Icon(
        encendido ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 24,
        color: esActual ? colores.onPrimary : colores.onSurfaceVariant,
      ),
    );
  }
}
