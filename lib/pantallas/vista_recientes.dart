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

  final corte =
      (ahora ?? DateTime.now()).subtract(const Duration(days: diasRecientes));
  var cuantos = 0;
  while (cuantos < todas.length && todas[cuantos].fecha.isAfter(corte)) {
    cuantos++;
  }
  if (cuantos < minimoRecientes) {
    cuantos = todas.length < minimoRecientes ? todas.length : minimoRecientes;
  }
  return todas.sublist(0, cuantos);
}

/// Pantalla de entrada: lo de ahora.
///
/// Deliberadamente **no** es la lista completa. Con miles de audios, una lista
/// infinita le da el mismo peso visual a una nota de 2018 que a la de esta
/// mañana, y no es a por la de 2018 a por la que se abre la app. Aquí solo
/// está el último mes; para rebuscar en el archivo está el calendario.
class VistaRecientes extends StatelessWidget {
  final IndiceAudios indice;
  final ServicioReproduccion reproduccion;
  final VoidCallback alIrAlCalendario;

  const VistaRecientes({
    super.key,
    required this.indice,
    required this.reproduccion,
    required this.alIrAlCalendario,
  });

  @override
  Widget build(BuildContext context) {
    final audios = ventanaReciente(indice.todas);
    final ocultos = indice.total - audios.length;

    if (audios.isEmpty) return _Vacio(indice: indice);

    return ListaAudios(
      audios: audios,
      indice: indice,
      reproduccion: reproduccion,
      agruparPorDia: true,
      pie: ocultos > 0
          ? _PieArchivo(ocultos: ocultos, alIrAlCalendario: alIrAlCalendario)
          : null,
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
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Column(
        children: [
          Divider(color: colores.outlineVariant),
          const SizedBox(height: 20),
          Text(
            fmt.cuentaAudios(ocultos),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: alIrAlCalendario,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Buscar por fecha'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colores.primary,
              side: BorderSide(color: colores.outline),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final IndiceAudios indice;

  const _Vacio({required this.indice});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    final sinCarpetas = !indice.hayCarpetas;
    final icono =
        sinCarpetas ? Icons.folder_off_outlined : Icons.graphic_eq_rounded;
    final titulo = sinCarpetas
        ? 'No encuentro la carpeta de WhatsApp'
        : 'Todavía no hay audios';
    final detalle = sinCarpetas
        ? 'Comprueba que WhatsApp está instalado y que has concedido el acceso '
            'a todos los archivos.'
        : 'Cuando recibas notas de voz aparecerán aquí.';

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
