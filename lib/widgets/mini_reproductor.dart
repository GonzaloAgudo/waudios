import 'package:flutter/material.dart';

import '../servicios/servicio_reproduccion.dart';
import 'formato.dart' as fmt;
import 'hoja_reproductor.dart';

/// Barra fina anclada abajo con lo que está sonando.
///
/// Sustituye a la hoja modal que tapaba la lista: ahora se puede seguir
/// navegando por el calendario mientras suena un audio, y se despliega al
/// reproductor completo con un toque.
class MiniReproductor extends StatelessWidget {
  final ServicioReproduccion reproduccion;

  const MiniReproductor({super.key, required this.reproduccion});

  @override
  Widget build(BuildContext context) {
    final nota = reproduccion.actual;

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: nota == null
          ? const SizedBox(width: double.infinity)
          : _Barra(reproduccion: reproduccion),
    );
  }
}

class _Barra extends StatelessWidget {
  final ServicioReproduccion reproduccion;

  const _Barra({required this.reproduccion});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final nota = reproduccion.actual!;

    return Material(
      color: colores.surfaceContainerHigh,
      child: InkWell(
        onTap: () => mostrarHojaReproductor(context, reproduccion),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: reproduccion.posicion,
              builder: (context, snapshot) {
                final total = reproduccion.duracionActual;
                final valor = total.inMilliseconds == 0
                    ? 0.0
                    : (snapshot.data ?? Duration.zero).inMilliseconds /
                        total.inMilliseconds;
                return LinearProgressIndicator(
                  value: valor.clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: colores.surfaceContainerHighest,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Row(
                children: [
                  Icon(
                    nota.esNotaDeVoz ? Icons.mic : Icons.audiotrack,
                    size: 20,
                    color: colores.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${fmt.etiquetaDia(nota.fecha)} · ${fmt.hora(nota.fecha)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        StreamBuilder<Duration>(
                          stream: reproduccion.posicion,
                          builder: (context, snapshot) => Text(
                            '${fmt.duracion(snapshot.data ?? Duration.zero)}'
                            ' / ${fmt.duracion(reproduccion.duracionActual)}'
                            '${reproduccion.cola.length > 1 ? '  ·  ${reproduccion.posicionEnCola + 1} de ${reproduccion.cola.length}' : ''}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colores.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      reproduccion.sonando
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    iconSize: 30,
                    tooltip: reproduccion.sonando ? 'Pausar' : 'Reproducir',
                    onPressed: reproduccion.alternar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 26,
                    tooltip: 'Siguiente',
                    onPressed:
                        reproduccion.haySiguiente ? reproduccion.siguiente : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 20,
                    tooltip: 'Cerrar',
                    onPressed: reproduccion.parar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
