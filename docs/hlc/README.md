# HLC

Esta carpeta reune las evidencias de HLC para NavalGO. El objetivo es demostrar
que la app aplica una estructura mantenible, nombres coherentes, separacion de
responsabilidades, uso justificado de librerias y una conexion correcta entre
interfaz y logica.

## Documentos

- `docs/hlc/matriz-evidencias.md`
- `docs/hlc/limpieza-y-mantenibilidad.md`
- `docs/hlc/poo-y-capas.md`
- `docs/hlc/entradas-salidas-y-servicios.md`
- `docs/hlc/conexion-ui-logica.md`

## Resumen rapido

- Se ha eliminado codigo legado no integrado en la navegacion actual.
- Se ha unificado la pantalla real de ausencias bajo una ruta coherente:
  `lib/screens/worker/ausencias_screen.dart`.
- La app mantiene una separacion clara entre `screens`, `viewmodels`,
  `services`, `models`, `widgets` y utilidades compartidas.
- Los formularios clave delegan la persistencia y la logica de negocio a
  servicios y viewmodels, evitando mezclar reglas de negocio con la UI.
