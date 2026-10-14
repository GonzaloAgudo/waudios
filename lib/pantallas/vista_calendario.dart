import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../modelos/nota_audio.dart';
import '../servicios/indice_audios.dart';
import '../servicios/servicio_reproduccion.dart';
import '../widgets/formato.dart' as fmt;
import '../widgets/lista_audios.dart';

/// Calendario + audios del día elegido.
///
/// La diferencia principal con la versión anterior es que el calendario ahora
/// *informa*: cada día pinta cuántos audios tiene, así que se ve de un vistazo
/// dónde hay algo en vez de ir tanteando día por día.
class VistaCalendario extends StatefulWidget {
  final IndiceAudios indice;
  final ServicioReproduccion reproduccion;

  const VistaCalendario({
    super.key,
    required this.indice,
    required this.reproduccion,
  });

  @override
  State<VistaCalendario> createState() => _VistaCalendarioState();
}

class _VistaCalendarioState extends State<VistaCalendario> {
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _mesEnfocado = DateTime.now();
  CalendarFormat _formato = CalendarFormat.month;

  void _seleccionar(DateTime dia, DateTime mes) {
    if (isSameDay(_diaSeleccionado, dia)) return;
    setState(() {
      _diaSeleccionado = dia;
      _mesEnfocado = mes;
    });
  }

  /// Desplaza al día anterior o siguiente que tenga audios. Evita tener que
  /// buscar a mano cuando hay semanas enteras vacías.
  void _saltarADiaConAudio({required bool haciaAtras}) {
    final dias = widget.indice.diasConAudio.toList()..sort();
    if (dias.isEmpty) return;

    final actual = DateTime(
        _diaSeleccionado.year, _diaSeleccionado.month, _diaSeleccionado.day);

    DateTime? destino;
    if (haciaAtras) {
      for (final d in dias) {
        if (d.isBefore(actual)) destino = d;
      }
    } else {
      for (final d in dias) {
        if (d.isAfter(actual)) {
          destino = d;
          break;
        }
      }
    }

    if (destino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(haciaAtras
              ? 'No hay audios anteriores'
              : 'No hay audios posteriores'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() {
      _diaSeleccionado = destino!;
      _mesEnfocado = destino;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final indice = widget.indice;
    final audios = indice.delDia(_diaSeleccionado);

    // Un día futuro no puede tener audios, pero permitimos ver el mes actual
    // completo para que el calendario no quede cortado a mitad de semana.
    final ultimoDia = DateTime.now().add(const Duration(days: 1));

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          elevation: 0,
          color: colores.surfaceContainerLow,
          child: TableCalendar<NotaAudio>(
            firstDay: DateTime.utc(2009, 1, 1),
            lastDay: ultimoDia,
            focusedDay: _mesEnfocado.isAfter(ultimoDia)
                ? ultimoDia
                : _mesEnfocado,
            locale: fmt.localeApp,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarFormat: _formato,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Mes',
              CalendarFormat.twoWeeks: '2 semanas',
              CalendarFormat.week: 'Semana',
            },
            onFormatChanged: (f) => setState(() => _formato = f),
            selectedDayPredicate: (d) => isSameDay(_diaSeleccionado, d),
            onDaySelected: _seleccionar,
            onPageChanged: (mes) => _mesEnfocado = mes,
            // La clave de la mejora: table_calendar pinta un marcador por cada
            // elemento que devuelva esta función.
            eventLoader: indice.delDia,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colores.primary.withValues(alpha: 0.25),
              ),
              todayTextStyle: TextStyle(color: colores.onSurface),
              selectedDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colores.primary,
              ),
              selectedTextStyle: TextStyle(
                color: colores.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: colores.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              titleTextStyle: Theme.of(context).textTheme.titleMedium ??
                  const TextStyle(),
            ),
            calendarBuilders: CalendarBuilders<NotaAudio>(
              // Cuántos audios tiene cada día, para ver de un vistazo dónde
              // hay algo en vez de ir tanteando día por día.
              markerBuilder: (context, dia, eventos) {
                if (eventos.isEmpty) return null;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: colores.primary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${eventos.length}',
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: colores.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _BarraDelDia(
          dia: _diaSeleccionado,
          cuantos: audios.length,
          alRetroceder: () => _saltarADiaConAudio(haciaAtras: true),
          alAvanzar: () => _saltarADiaConAudio(haciaAtras: false),
        ),
        Expanded(
          child: audios.isEmpty
              ? _DiaVacio(dia: _diaSeleccionado)
              : ListaAudios(
                  audios: audios,
                  indice: indice,
                  reproduccion: widget.reproduccion,
                ),
        ),
      ],
    );
  }
}

class _BarraDelDia extends StatelessWidget {
  final DateTime dia;
  final int cuantos;
  final VoidCallback alRetroceder;
  final VoidCallback alAvanzar;

  const _BarraDelDia({
    required this.dia,
    required this.cuantos,
    required this.alRetroceder,
    required this.alAvanzar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Día anterior con audios',
            onPressed: alRetroceder,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  fmt.etiquetaDia(dia),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  cuantos == 0 ? 'Sin audios' : fmt.cuentaAudios(cuantos),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colores.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Día siguiente con audios',
            onPressed: alAvanzar,
          ),
        ],
      ),
    );
  }
}

class _DiaVacio extends StatelessWidget {
  final DateTime dia;

  const _DiaVacio({required this.dia});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined,
              size: 44, color: colores.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No hay audios el ${fmt.fechaCorta(dia)}',
            style: TextStyle(color: colores.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Usa las flechas para ir al día con audios más cercano',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colores.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
