import 'package:flutter/material.dart';

import '../modelos/nota_audio.dart';
import '../servicios/indice_audios.dart';
import '../servicios/servicio_reproduccion.dart';
import '../widgets/formato.dart' as fmt;
import '../widgets/lista_audios.dart';

/// Ventana de tiempo que se considera "reciente" en esta pestaña.
const int diasRecientes = 30;

/// Aunque no haya nada reciente, nunca se enseña menos de esto: si llevas dos
/// meses sin recibir audios, la pantalla no debe quedarse vacía.
const int minimoRecientes = 40;

/// Recorta [todas] (que llega del más nuevo al más viejo) a la ventana
/// reciente. Devuelve siempre al menos [minimoRecientes] elementos, o la lista
/// entera si es más corta.
List<NotaAudio> ventanaReciente(List<NotaAudio> todas, {DateTime? ahora}) {
  if (todas.isEmpty) return todas;

  final corte = (ahora ?? DateTime.now())
      .subtract(const Duration(days: diasRecientes));
  var cuantos = 0;
  while (cuantos < todas.length && todas[cuantos].fecha.isAfter(corte)) {
    cuantos++;
  }
  if (cuantos < minimoRecientes) {
    cuantos = todas.length < minimoRecientes ? todas.length : minimoRecientes;
  }
  return todas.sublist(0, cuantos);
}

/// Pantalla de entrada: lo de ahora y lo que queda por escuchar.
///
/// Deliberadamente **no** es la lista completa. Con miles de audios, una lista
/// infinita le da el mismo peso visual a una nota de 2018 que a la de esta
/// mañana, y no es a por la de 2018 a por la que se abre la app. Aquí solo
/// está el último mes; para rebuscar en el archivo está el calendario, que es
/// la herramienta adecuada para eso.
class VistaRecientes extends StatelessWidget {
  final IndiceAudios indice;
  final ServicioReproduccion reproduccion;
  final bool soloSinEscuchar;
  final ValueChanged<bool> alCambiarFiltro;
  final VoidCallback alIrAlCalendario;

  const VistaRecientes({
    super.key,
    required this.indice,
    required this.reproduccion,
    required this.soloSinEscuchar,
    required this.alCambiarFiltro,
    required this.alIrAlCalendario,
  });

  /// Pendientes de más antiguo a más nuevo: el orden en que se escuchan.
  List<NotaAudio> get _pendientes {
    final lista = indice.todas
        .where((a) => !indice.estaEscuchado(a.ruta))
        .toList(growable: false);
    return lista.reversed.toList(growable: false);
  }

  List<NotaAudio> get _recientes => ventanaReciente(indice.todas);

  @override
  Widget build(BuildContext context) {
    // Con el filtro de pendientes no se recorta por fecha: si tienes algo sin
    // escuchar de hace medio año, sigue siendo algo que te queda por escuchar.
    final audios = soloSinEscuchar ? _pendientes : _recientes;
    final ocultos = soloSinEscuchar ? 0 : indice.total - audios.length;

    final cabecera = _Cabecera(
      pendientes: indice.sinEscuchar,
      soloSinEscuchar: soloSinEscuchar,
      alCambiarFiltro: alCambiarFiltro,
      alReproducirPendientes: () => _reproducirPendientes(context),
    );

    if (audios.isEmpty) {
      return Column(
        children: [
          cabecera,
          Expanded(
            child: _Vacio(soloSinEscuchar: soloSinEscuchar, indice: indice),
          ),
        ],
      );
    }

    return ListaAudios(
      audios: audios,
      indice: indice,
      reproduccion: reproduccion,
      agruparPorDia: true,
      cabecera: cabecera,
      pie: ocultos > 0
          ? _PieArchivo(ocultos: ocultos, alIrAlCalendario: alIrAlCalendario)
          : null,
    );
  }

  void _reproducirPendientes(BuildContext context) {
    final cola = _pendientes;
    if (cola.isEmpty) return;
    reproduccion.reproducir(cola.first, cola);
  }
}

/// Lo primero que se ve: qué te queda por escuchar y un botón para ponerte al
/// día de una sentada.
class _Cabecera extends StatelessWidget {
  final int pendientes;
  final bool soloSinEscuchar;
  final ValueChanged<bool> alCambiarFiltro;
  final VoidCallback alReproducirPendientes;

  const _Cabecera({
    required this.pendientes,
    required this.soloSinEscuchar,
    required this.alCambiarFiltro,
    required this.alReproducirPendientes,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendientes > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: colores.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.headphones_rounded,
                    color: colores.onPrimaryContainer),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pendientes == 1
                            ? '1 audio sin escuchar'
                            : '$pendientes audios sin escuchar',
                        style: textos.titleMedium?.copyWith(
                          color: colores.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Del más antiguo al más nuevo',
                        style: textos.bodySmall?.copyWith(
                          color: colores.onPrimaryContainer
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: alReproducirPendientes,
                  style: FilledButton.styleFrom(
                    backgroundColor: colores.primary,
                    foregroundColor: colores.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 26),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(Icons.done_all_rounded,
                    size: 18, color: colores.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Estás al día',
                  style: textos.bodyMedium
                      ?.copyWith(color: colores.onSurfaceVariant),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Último mes'),
                selected: !soloSinEscuchar,
                onSelected: (_) => alCambiarFiltro(false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Sin escuchar ($pendientes)'),
                selected: soloSinEscuchar,
                onSelected: (_) => alCambiarFiltro(true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cierre de la lista: el archivo antiguo existe, pero vive en el calendario.
class _PieArchivo extends StatelessWidget {
  final int ocultos;
  final VoidCallback alIrAlCalendario;

  const _PieArchivo({required this.ocultos, required this.alIrAlCalendario});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Column(
        children: [
          Divider(color: colores.outlineVariant),
          const SizedBox(height: 16),
          Text(
            fmt.cuentaAudios(ocultos),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'más antiguos, guardados en el calendario',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colores.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: alIrAlCalendario,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Buscar por fecha'),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final bool soloSinEscuchar;
  final IndiceAudios indice;

  const _Vacio({required this.soloSinEscuchar, required this.indice});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    late final IconData icono;
    late final String titulo;
    late final String detalle;

    if (soloSinEscuchar) {
      icono = Icons.done_all_rounded;
      titulo = 'Todo escuchado';
      detalle = 'No te queda ninguna nota de voz pendiente.';
    } else if (!indice.hayCarpetas) {
      icono = Icons.folder_off_outlined;
      titulo = 'No encuentro la carpeta de WhatsApp';
      detalle = 'Comprueba que WhatsApp está instalado y que has concedido el '
          'acceso a todos los archivos.';
    } else {
      icono = Icons.graphic_eq_rounded;
      titulo = 'Todavía no hay audios';
      detalle = 'Cuando recibas notas de voz aparecerán aquí.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 52, color: colores.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colores.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
