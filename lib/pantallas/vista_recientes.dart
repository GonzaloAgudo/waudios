import 'package:flutter/material.dart';

import '../modelos/nota_audio.dart';
import '../servicios/indice_audios.dart';
import '../servicios/servicio_reproduccion.dart';
import '../widgets/lista_audios.dart';

/// Lista continua de todos los audios, del más nuevo al más viejo.
///
/// Es el caso de uso más frecuente y el que la versión anterior no cubría: casi
/// siempre el audio que buscas es de hoy o de ayer, y llegar a él no debería
/// exigir pasar por un calendario.
class VistaRecientes extends StatelessWidget {
  final IndiceAudios indice;
  final ServicioReproduccion reproduccion;
  final bool soloSinEscuchar;
  final ValueChanged<bool> alCambiarFiltro;

  const VistaRecientes({
    super.key,
    required this.indice,
    required this.reproduccion,
    required this.soloSinEscuchar,
    required this.alCambiarFiltro,
  });

  @override
  Widget build(BuildContext context) {
    final List<NotaAudio> audios = soloSinEscuchar
        ? indice.todas.where((a) => !indice.estaEscuchado(a.ruta)).toList()
        : indice.todas;

    final filtros = _Filtros(
      soloSinEscuchar: soloSinEscuchar,
      sinEscuchar: indice.sinEscuchar,
      total: indice.total,
      alCambiarFiltro: alCambiarFiltro,
    );

    if (audios.isEmpty) {
      return Column(
        children: [
          filtros,
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
      cabecera: filtros,
    );
  }
}

class _Filtros extends StatelessWidget {
  final bool soloSinEscuchar;
  final int sinEscuchar;
  final int total;
  final ValueChanged<bool> alCambiarFiltro;

  const _Filtros({
    required this.soloSinEscuchar,
    required this.sinEscuchar,
    required this.total,
    required this.alCambiarFiltro,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('Todos ($total)'),
            selected: !soloSinEscuchar,
            onSelected: (_) => alCambiarFiltro(false),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('Sin escuchar ($sinEscuchar)'),
            selected: soloSinEscuchar,
            onSelected: (_) => alCambiarFiltro(true),
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
