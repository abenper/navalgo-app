# Matriz de evidencias HLC

## Nombres de variables, metodos y clases

- Evidencia: estructura por capas con nombres explicitos en `services`,
  `viewmodels`, `models` y `screens`.
- Evidencia: unificacion de la pantalla real de ausencias en
  `lib/screens/worker/ausencias_screen.dart`.
- Defensa: los nombres describen responsabilidad funcional y evitan ambiguedad
  entre UI, dominio y acceso a datos.

## Eliminacion de codigo muerto, duplicado y pantallas no integradas

- Evidencia: eliminadas `lib/screens/admin/dashboard_screen.dart` y
  `lib/screens/admin/mapa_screen.dart`.
- Evidencia: retirada la version legacy de ausencias con estado local.
- Defensa: el repositorio final contiene solo pantallas conectadas al flujo real
  o reutilizadas desde shells activos.

## Justificacion de E/S, librerias y servicios externos

- Evidencia: dependencias declaradas en `pubspec.yaml`.
- Evidencia: inicializacion e inyeccion de servicios en `lib/main.dart`.
- Evidencia: uso de HTTP, geolocalizacion, firma, multimedia, notificaciones y
  almacenamiento local.
- Defensa: cada libreria cubre una necesidad tecnica concreta y esta integrada
  desde servicios o viewmodels.

## Uso de POO

- Evidencia: modelos de dominio en `lib/models/`.
- Evidencia: servicios especializados en `lib/services/`.
- Evidencia: viewmodels basados en `ChangeNotifier` en `lib/viewmodels/`.
- Evidencia: composicion mediante `MultiProvider` en `lib/main.dart`.
- Defensa: se separan entidad, estado, acceso a datos y presentacion.

## Conexion entre interfaz y logica

- Evidencia: login conectado a `LoginViewModel` y `AuthService`.
- Evidencia: fichaje conectado a `TimeTrackingService`.
- Evidencia: partes conectado a `FleetViewModel`, `WorkersViewModel`,
  `WorkOrdersViewModel` y `WorkOrderService`.
- Evidencia: ausencias conectado a `LeaveService` y `WorkerService`.
- Defensa: los formularios validan, persisten y refrescan datos reales tras cada
  accion.

## Material recomendable para la entrega

- Captura del arbol `lib/models`, `lib/services`, `lib/viewmodels`,
  `lib/screens`, `lib/widgets`.
- Captura de `main.dart` con `MultiProvider`.
- Captura de login, fichaje, partes y ausencias mostrando que la UI lanza
  operaciones reales.
- Captura o tabla breve indicando las pantallas legacy eliminadas para justificar
  la limpieza del proyecto.
