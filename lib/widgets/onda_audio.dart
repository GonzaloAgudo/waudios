import 'package:flutter/material.dart';

/// Forma de onda de un audio, con la parte ya reproducida resaltada.
///
/// Los valores vienen del análisis del archivo (0 a 100). Mientras no están
/// calculados se dibuja una línea de barras bajas, para que la fila ocupe lo
/// mismo antes y después y la lista no dé saltos al rellenarse.
class OndaAudio extends StatelessWidget {
  final List<int> onda;

  /// Parte ya reproducida, de 0 a 1.
  final double progreso;

  final Color color;
  final Color colorReproducido;
  final double alto;

  const OndaAudio({
    super.key,
    required this.onda,
    required this.color,
    required this.colorReproducido,
    this.progreso = 0,
    this.alto = 30,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      width: double.infinity,
      child: CustomPaint(
        painter: _PintorOnda(
          onda: onda,
          progreso: progreso.clamp(0.0, 1.0),
          color: color,
          colorReproducido: colorReproducido,
        ),
      ),
    );
  }
}

class _PintorOnda extends CustomPainter {
  final List<int> onda;
  final double progreso;
  final Color color;
  final Color colorReproducido;

  _PintorOnda({
    required this.onda,
    required this.progreso,
    required this.color,
    required this.colorReproducido,
  });

  @override
  void paint(Canvas lienzo, Size tamano) {
    if (tamano.width <= 0) return;

    final barras = onda.isEmpty ? 44 : onda.length;
    final paso = tamano.width / barras;
    final grosor = (paso * 0.55).clamp(1.5, 4.0);
    final medio = tamano.height / 2;
    final corte = tamano.width * progreso;

    final pincel = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = grosor;

    for (var i = 0; i < barras; i++) {
      final x = paso * i + paso / 2;

      // Sin datos aún: barras bajas y tenues, a modo de marcador de sitio.
      final valor = onda.isEmpty ? 8 : onda[i];
      final altura = (tamano.height * (valor / 100)).clamp(2.0, tamano.height);

      final tono = x <= corte ? colorReproducido : color;
      pincel.color = onda.isEmpty ? tono.withValues(alpha: 0.35) : tono;
      lienzo.drawLine(
        Offset(x, medio - altura / 2),
        Offset(x, medio + altura / 2),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorOnda anterior) =>
      anterior.progreso != progreso ||
      anterior.color != color ||
      anterior.colorReproducido != colorReproducido ||
      !identical(anterior.onda, onda);
}
