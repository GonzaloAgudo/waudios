import 'package:flutter/material.dart';

import '../modelos/nota_audio.dart';
import 'formato.dart' as fmt;

/// Fila de la lista de audios.
///
/// Todo lo que pinta sale del modelo ya cargado: nunca toca el disco durante el
/// `build`, que era lo que hacía que desplazar la lista fuera a tirones.
class TarjetaAudio extends StatelessWidget {
  final NotaAudio nota;
  final bool esActual;
  final bool sonando;
  final bool escuchado;
  final VoidCallback alPulsar;
  final VoidCallback alPulsarMas;

  const TarjetaAudio({
    super.key,
    required this.nota,
    required this.esActual,
    required this.sonando,
    required this.escuchado,
    required this.alPulsar,
    required this.alPulsarMas,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    // Duration.zero significa "se intentó medir y no se pudo": mejor no
    // enseñar nada que enseñar 0:00.
    final duracionConocida =
        nota.duracion != null && nota.duracion! > Duration.zero;

    return Material(
      color: esActual ? colores.primaryContainer.withValues(alpha: 0.35) : null,
      child: InkWell(
        onTap: alPulsar,
        onLongPress: alPulsarMas,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _Avatar(
                esNotaDeVoz: nota.esNotaDeVoz,
                esActual: esActual,
                sonando: sonando,
                escuchado: escuchado,
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
                            fontWeight:
                                escuchado ? FontWeight.w500 : FontWeight.bold,
                            color: esActual ? colores.primary : null,
                          ),
                        ),
                        if (duracionConocida) ...[
                          const SizedBox(width: 8),
                          Text(
                            fmt.duracion(nota.duracion),
                            style: textos.bodyMedium?.copyWith(
                              color: colores.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nota.esNotaDeVoz ? 'Nota de voz' : nota.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textos.bodySmall
                          ?.copyWith(color: colores.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                iconSize: 20,
                color: colores.onSurfaceVariant,
                tooltip: 'Opciones',
                onPressed: alPulsarMas,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool esNotaDeVoz;
  final bool esActual;
  final bool sonando;
  final bool escuchado;

  const _Avatar({
    required this.esNotaDeVoz,
    required this.esActual,
    required this.sonando,
    required this.escuchado,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    final IconData icono;
    if (esActual) {
      icono = sonando ? Icons.pause : Icons.play_arrow;
    } else {
      icono = esNotaDeVoz ? Icons.mic : Icons.audiotrack;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: esActual
                ? colores.primary
                : colores.primary.withValues(alpha: 0.16),
          ),
          child: Icon(
            icono,
            size: 21,
            color: esActual ? colores.onPrimary : colores.primary,
          ),
        ),
        // Punto de "sin escuchar": el único adorno que aporta información.
        if (!escuchado && !esActual)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colores.tertiary,
                border: Border.all(color: colores.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
