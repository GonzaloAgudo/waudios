import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../servicios/indice_audios.dart';
import '../servicios/servicio_reproduccion.dart';
import '../widgets/formato.dart' as fmt;
import '../widgets/mini_reproductor.dart';
import 'pantalla_permisos.dart';
import 'vista_calendario.dart';
import 'vista_recientes.dart';

enum _EstadoPermiso { comprobando, concedido, denegado, denegadoParaSiempre }

/// Contenedor de la app: permisos, pestañas y mini reproductor.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio>
    with WidgetsBindingObserver {
  final IndiceAudios _indice = IndiceAudios();
  final ServicioReproduccion _reproduccion = ServicioReproduccion();

  _EstadoPermiso _permiso = _EstadoPermiso.comprobando;
  int _pestana = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _comprobarPermisos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reproduccion.dispose();
    _indice.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Al volver de los ajustes del sistema o de WhatsApp, revisamos si hay
    // permiso nuevo o audios nuevos sin que el usuario tenga que hacer nada.
    if (estado != AppLifecycleState.resumed) return;
    if (_permiso == _EstadoPermiso.concedido) {
      _indice.refrescar();
    } else {
      _comprobarPermisos(pedir: false);
    }
  }

  Future<void> _comprobarPermisos({bool pedir = true}) async {
    // En Android 11+ hace falta MANAGE_EXTERNAL_STORAGE para leer la carpeta
    // de WhatsApp; en versiones anteriores basta con STORAGE.
    var concedido = await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;

    if (!concedido && pedir) {
      final resultado = await Permission.manageExternalStorage.request();
      concedido = resultado.isGranted;
      if (!concedido) {
        concedido = (await Permission.storage.request()).isGranted;
      }
    }

    if (!mounted) return;

    if (concedido) {
      setState(() => _permiso = _EstadoPermiso.concedido);
      await _indice.iniciar();
      return;
    }

    final permanente = await Permission.manageExternalStorage.isPermanentlyDenied;
    if (!mounted) return;
    setState(() => _permiso = permanente
        ? _EstadoPermiso.denegadoParaSiempre
        : _EstadoPermiso.denegado);
  }

  @override
  Widget build(BuildContext context) {
    if (_permiso != _EstadoPermiso.concedido) {
      return PantallaPermisos(
        comprobando: _permiso == _EstadoPermiso.comprobando,
        denegadoParaSiempre: _permiso == _EstadoPermiso.denegadoParaSiempre,
        alPedir: _comprobarPermisos,
      );
    }

    return AnimatedBuilder(
      // Un único punto de reconstrucción: cualquier cambio del índice o del
      // reproductor repinta lo que haga falta y nada más.
      animation: Listenable.merge([_indice, _reproduccion]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            toolbarHeight: 72,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WAudios',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                Text(
                  _indice.cargando
                      ? 'Buscando audios…'
                      : fmt.cuentaAudios(_indice.total),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _indice.escaneando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Buscar audios nuevos',
                        onPressed: _indice.refrescar,
                      ),
              ),
            ],
          ),
          body: _indice.cargando
              ? const _Cargando()
              : SafeArea(
                  top: false,
                  child: IndexedStack(
                    index: _pestana,
                    children: [
                      VistaRecientes(
                        indice: _indice,
                        reproduccion: _reproduccion,
                        alIrAlCalendario: () => setState(() => _pestana = 1),
                      ),
                      VistaCalendario(
                        indice: _indice,
                        reproduccion: _reproduccion,
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiniReproductor(reproduccion: _reproduccion),
              NavigationBar(
                selectedIndex: _pestana,
                onDestinationSelected: (i) => setState(() => _pestana = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.graphic_eq_outlined),
                    selectedIcon: Icon(Icons.graphic_eq),
                    label: 'Recientes',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Calendario',
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

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparando tus audios…'),
        ],
      ),
    );
  }
}
