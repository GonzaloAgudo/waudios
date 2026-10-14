import 'package:flutter/material.dart';

import '../servicios/preferencias.dart';
import '../tema/paletas.dart';

Future<void> mostrarSelectorPaleta(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SelectorPaleta(),
  );
}

/// Elección de colores. El cambio se aplica al instante y se recuerda, para
/// poder compararlas sobre la propia lista en vez de sobre una muestra.
class _SelectorPaleta extends StatelessWidget {
  const _SelectorPaleta();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<PaletaApp>(
        valueListenable: paletaActual,
        builder: (context, actual, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Colores',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final paleta in paletas)
              _Fila(
                paleta: paleta,
                seleccionada: paleta.id == actual.id,
                alElegir: () {
                  paletaActual.value = paleta;
                  Preferencias.guardarPaleta(paleta.id);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final PaletaApp paleta;
  final bool seleccionada;
  final VoidCallback alElegir;

  const _Fila({
    required this.paleta,
    required this.seleccionada,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return ListTile(
      onTap: alElegir,
      leading: Container(
        width: 52,
        height: 38,
        decoration: BoxDecoration(
          color: paleta.fondo,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: paleta.borde),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Muestra(color: paleta.acento, alto: 18),
            const SizedBox(width: 4),
            _Muestra(color: paleta.superficieMax, alto: 13),
            const SizedBox(width: 4),
            _Muestra(color: paleta.texto, alto: 9),
          ],
        ),
      ),
      title: Text(
        paleta.nombre,
        style: TextStyle(
          fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(paleta.esClara ? 'Clara' : 'Oscura'),
      trailing: seleccionada
          ? Icon(Icons.check_circle_rounded, color: colores.primary)
          : null,
    );
  }
}

class _Muestra extends StatelessWidget {
  final Color color;
  final double alto;

  const _Muestra({required this.color, required this.alto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: alto,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
