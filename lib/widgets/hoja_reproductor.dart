import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../servicios/servicio_reproduccion.dart';
import 'formato.dart' as fmt;

Future<void> mostrarHojaReproductor(
  BuildContext context,
  ServicioReproduccion reproduccion,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => HojaReproductor(reproduccion: reproduccion),
  );
}

/// Reproductor completo. Se apoya en el servicio global, así que al cerrarlo el
/// audio sigue sonando en la mini barra en lugar de cortarse.
class HojaReproductor extends StatelessWidget {
  final ServicioReproduccion reproduccion;

  const HojaReproductor({super.key, required this.reproduccion});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reproduccion,
      builder: (context, _) {
        final nota = reproduccion.actual;
        if (nota == null) return const SizedBox(height: 120);

        final colores = Theme.of(context).colorScheme;
        final textos = Theme.of(context).textTheme;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colores.primary.withValues(alpha: 0.16),
                ),
                child: Icon(
                  nota.esNotaDeVoz ? Icons.mic : Icons.audiotrack,
                  size: 32,
                  color: colores.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                nota.esNotaDeVoz ? 'Nota de voz' : nota.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textos.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${fmt.etiquetaDia(nota.fecha)} · ${fmt.hora(nota.fecha)}'
                '${reproduccion.cola.length > 1 ? '  ·  ${reproduccion.posicionEnCola + 1} de ${reproduccion.cola.length}' : ''}',
                style: textos.bodyMedium?.copyWith(
                  color: colores.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _Barra(reproduccion: reproduccion),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BotonVelocidad(reproduccion: reproduccion),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded),
                    iconSize: 32,
                    tooltip: 'Anterior',
                    onPressed: reproduccion.anterior,
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded),
                    iconSize: 30,
                    tooltip: 'Atrás 10 s',
                    onPressed: () => reproduccion.saltar(-10),
                  ),
                  _BotonPrincipal(reproduccion: reproduccion),
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded),
                    iconSize: 30,
                    tooltip: 'Adelante 10 s',
                    onPressed: () => reproduccion.saltar(10),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 32,
                    tooltip: 'Siguiente',
                    onPressed: reproduccion.haySiguiente
                        ? reproduccion.siguiente
                        : null,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Compartir',
                    onPressed: () => Share.shareXFiles([XFile(nota.ruta)]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Barra extends StatefulWidget {
  final ServicioReproduccion reproduccion;

  const _Barra({required this.reproduccion});

  @override
  State<_Barra> createState() => _BarraState();
}

class _BarraState extends State<_Barra> {
  /// Mientras se arrastra mandamos nosotros, no el stream de posición.
  double? _arrastrando;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return StreamBuilder<Duration>(
      stream: widget.reproduccion.posicion,
      builder: (context, snapshot) {
        final total = widget.reproduccion.duracionActual;
        final maximo = total.inMilliseconds.toDouble();
        final posicion = _arrastrando ??
            (snapshot.data ?? Duration.zero).inMilliseconds.toDouble();

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                // Con un audio aún sin cargar el máximo es 0; usamos 1 para
                // que el Slider no divida entre cero.
                min: 0,
                max: maximo <= 0 ? 1 : maximo,
                value: maximo <= 0 ? 0 : posicion.clamp(0, maximo),
                onChanged: maximo <= 0
                    ? null
                    : (v) => setState(() => _arrastrando = v),
                onChangeEnd: (v) {
                  widget.reproduccion
                      .buscar(Duration(milliseconds: v.toInt()));
                  setState(() => _arrastrando = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fmt.duracion(Duration(milliseconds: posicion.toInt())),
                    style: TextStyle(color: colores.onSurfaceVariant),
                  ),
                  Text(
                    fmt.duracion(total),
                    style: TextStyle(color: colores.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BotonPrincipal extends StatelessWidget {
  final ServicioReproduccion reproduccion;

  const _BotonPrincipal({required this.reproduccion});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final sonando = reproduccion.sonando;

    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: colores.primary),
      child: IconButton(
        icon: Icon(
          sonando ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: colores.onPrimary,
        ),
        iconSize: 40,
        padding: const EdgeInsets.all(10),
        tooltip: sonando ? 'Pausar' : 'Reproducir',
        onPressed: reproduccion.alternar,
      ),
    );
  }
}

class _BotonVelocidad extends StatelessWidget {
  final ServicioReproduccion reproduccion;

  const _BotonVelocidad({required this.reproduccion});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final velocidad = reproduccion.velocidad;

    return TextButton(
      onPressed: reproduccion.cambiarVelocidad,
      style: TextButton.styleFrom(
        backgroundColor: velocidad == 1.0
            ? colores.surfaceContainerHighest
            : colores.primary.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(52, 40),
      ),
      child: Text(
        '${velocidad}x'.replaceAll('.0x', 'x'),
        style: TextStyle(
          color: velocidad == 1.0 ? colores.onSurfaceVariant : colores.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
