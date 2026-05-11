# POO y capas

## Capas del frontend Flutter

- `lib/screens/`: presenta la interfaz y recoge eventos de usuario.
- `lib/viewmodels/`: coordina estado de pantalla, carga y refresco.
- `lib/services/`: encapsula acceso a API, almacenamiento local y reglas de
  comunicacion.
- `lib/models/`: define entidades de dominio como usuarios, partes, fichajes o
  ausencias.
- `lib/widgets/`: concentra componentes reutilizables para reducir duplicacion.

## Evidencias de POO

- `AuthService`, `TimeTrackingService`, `LeaveService` y `WorkOrderService`
  encapsulan operaciones de negocio y acceso remoto.
- `SessionViewModel`, `LoginViewModel`, `WorkersViewModel`,
  `FleetViewModel` y `WorkOrdersViewModel` usan `ChangeNotifier` para separar
  estado y presentacion.
- `WorkOrder`, `WorkerProfile`, `LeaveRequestModel` y `TimeEntry` representan
  modelos de dominio con propiedades y comportamiento derivado.
- La composicion se aplica en `main.dart`, donde `MultiProvider` inyecta
  servicios y viewmodels a las pantallas que los necesitan.

## Ejemplo de flujo por capas

1. `LoginScreen` recoge email y password.
2. `LoginViewModel` valida el estado de carga y delega en `AuthService`.
3. `AuthService` resuelve autenticacion, persistencia local y sesion.
4. `SessionViewModel` conserva el usuario autenticado para el resto de la app.
5. La UI navega al shell correspondiente segun el rol recibido.

## Defensa para la memoria

La app aplica programacion orientada a objetos mediante clases de dominio,
servicios especializados y objetos de estado desacoplados de la interfaz. La
estructura en capas reduce acoplamiento, facilita pruebas y permite evolucionar
cada modulo sin reescribir el resto del sistema.
