# Arquitectura Flutter por capas

## Objetivo

NavalGO sigue una arquitectura por capas para separar interfaz, estado, acceso a datos y modelos de dominio. Esto facilita mantenimiento, escalado y pruebas.

## 1. Capa de presentacion

Ubicacion principal:

- `lib/screens/`
- `lib/widgets/`
- `lib/theme/`

Responsabilidades:

- Mostrar pantallas.
- Organizar formularios y paneles.
- Adaptar la interfaz a movil y escritorio.
- Delegar la logica de sesion y datos a viewmodels o servicios.

Ejemplos:

- `lib/screens/common/login_screen.dart`
- `lib/screens/admin/admin_shell_screen.dart`
- `lib/screens/worker/fichaje_screen.dart`

## 2. Capa de estado y coordinacion

Ubicacion principal:

- `lib/viewmodels/`

Responsabilidades:

- Mantener sesion y usuario actual.
- Orquestar login, refresco de token y notificaciones.
- Exponer estado reactivo a la interfaz mediante `provider`.

Ejemplos:

- `SessionViewModel`: restaura sesion, expira sesion y refresca token.
- `LoginViewModel`: gestiona autenticacion.
- `NotificationsViewModel`: consulta, refresca y marca notificaciones.

## 3. Capa de servicios cliente

Ubicacion principal:

- `lib/services/`
- `lib/services/network/`

Responsabilidades:

- Consumir la API REST.
- Serializar y deserializar JSON.
- Encapsular endpoints de login, partes, fichajes, flota y ausencias.

Ejemplos:

- `AuthService`
- `TimeTrackingService`
- `WorkOrderService`
- `WorkOrderMediaService`
- `WorkerService`

## 4. Capa de modelos

Ubicacion principal:

- `lib/models/`

Responsabilidades:

- Definir estructuras de dominio usadas por UI y servicios.
- Convertir respuestas JSON en objetos tipados.

Ejemplos:

- `User`
- `TimeEntry`
- `WorkOrder`
- `WorkerProfile`
- `Budget`

## 5. Bootstrap de la aplicacion

El archivo `lib/main.dart`:

- inicializa Firebase de forma segura;
- restaura la sesion;
- configura handlers de sesion expirada y refresh de token;
- inyecta servicios y viewmodels con `MultiProvider`;
- decide la pantalla inicial segun URL de entrada o sesion.

## 6. Aplicacion de la arquitectura en navegacion

- El `LoginScreen` autentica y redirige por rol.
- Cada rol entra en un `ShellScreen` propio.
- Cada shell conserva estado de pestanas con `IndexedStack`.
- Las pantallas de detalle se abren con `MaterialPageRoute` o dialogos.

## 7. Ciclo de vida y sesion

- La sesion se recupera desde `SharedPreferences`.
- Si el token ha caducado y existe refresh valido, se intenta renovar.
- Si el token expira, `ApiClient` dispara cierre de sesion controlado.
- La interfaz vuelve a login sin dejar pantallas rotas.

## 8. Beneficios para la rubrica PMDM

- Codigo legible y mantenible.
- Separacion de capas clara.
- Navegacion modular por rol.
- Integracion limpia con servicios remotos, multimedia y notificaciones.
