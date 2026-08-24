import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pantalla que se muestra mientras no hay permiso de lectura.
///
/// Antes, si el usuario denegaba el permiso, la app se quedaba con una lista
/// vacía y sin explicación. Aquí se dice qué hace falta, por qué, y se ofrece
/// un atajo a los ajustes cuando Android ya no vuelve a preguntar.
class PantallaPermisos extends StatelessWidget {
  final bool denegadoParaSiempre;
  final bool comprobando;
  final VoidCallback alPedir;

  const PantallaPermisos({
    super.key,
    required this.denegadoParaSiempre,
    required this.comprobando,
    required this.alPedir,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colores.primary.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.folder_open_rounded,
                    size: 56, color: colores.primary),
              ),
              const SizedBox(height: 28),
              Text(
                'Acceso a tus audios',
                style: textos.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'WAudios necesita leer la carpeta de WhatsApp para poder '
                'ordenar tus notas de voz por fecha. Los audios no salen del '
                'móvil: todo se hace en local.',
                style: textos.bodyMedium
                    ?.copyWith(color: colores.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (comprobando)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: denegadoParaSiempre ? openAppSettings : alPedir,
                  icon: Icon(denegadoParaSiempre
                      ? Icons.settings
                      : Icons.lock_open_rounded),
                  label: Text(denegadoParaSiempre
                      ? 'Abrir ajustes'
                      : 'Conceder permiso'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                  ),
                ),
              if (denegadoParaSiempre) ...[
                const SizedBox(height: 16),
                Text(
                  'Activa "Acceso a todos los archivos" en los permisos de la '
                  'aplicación y vuelve aquí.',
                  style: textos.bodySmall
                      ?.copyWith(color: colores.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: alPedir,
                  child: const Text('Ya lo he activado'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
