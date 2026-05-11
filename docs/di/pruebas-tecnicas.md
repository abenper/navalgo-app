# Pruebas de integracion, rendimiento y seguridad

## 1. Integracion

### Evidencia automatizada actual

- `flutter analyze`: sin errores.
- `flutter test`: en verde.

### Flujos cubiertos

- Login:
  - [auth_service_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/services/auth_service_test.dart)
- Fichaje:
  - [time_tracking_service_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/services/time_tracking_service_test.dart)
- Creacion de parte:
  - [work_order_service_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/services/work_order_service_test.dart)
- Firma multipart:
  - [work_order_media_service_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/services/work_order_media_service_test.dart)
- Arranque de interfaz:
  - [widget_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/widget_test.dart)

### Como defenderlo

La app tiene pruebas funcionales sobre servicios criticos y validacion del arranque de interfaz. No son pruebas E2E completas, pero si demuestran integracion entre pantallas, estado y API cliente.

## 2. Rendimiento

### Medidas aplicadas en codigo

- `IndexedStack` con carga diferida de secciones en los distintos `ShellScreen`.
- `LayoutBuilder` y `Wrap` para evitar overflows por anchura fija.
- `ConstrainedBox` y `SingleChildScrollView` en formularios y pantallas de acceso.
- Inicializacion de Firebase no bloqueante en web en [main.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/main.dart).

### Evidencia concreta

- [main.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/main.dart)
- [admin_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/admin/admin_shell_screen.dart)
- [worker_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/worker_shell_screen.dart)
- [commercial_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/commercial/commercial_shell_screen.dart)
- [client_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/client/client_shell_screen.dart)

### Comprobaciones recomendadas para la memoria

- Tiempo de apertura inicial aceptable.
- Cambio entre pestañas sin lag visible.
- Formularios largos sin saltos ni desbordes.
- Carga de landing y dashboard sin errores visuales.

## 3. Seguridad

### Evidencia tecnica

- JWT y refresh controlado.
- Cierre de sesion cuando el token expira.
- Cambio de password obligatorio cuando procede.
- Validacion de uploads y cabeceras.
- Backend con CORS y cabeceras de seguridad.

### Archivos de apoyo

- [api_client.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/network/api_client.dart)
- [auth_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/auth_service.dart)
- [session_view_model.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/viewmodels/session_view_model.dart)
- [SecurityConfig.java](/c:/Users/Aaron/Documents/navalgo-app/navalgo/backend/src/main/java/com/navalgo/backend/security/SecurityConfig.java)
- [UploadValidationService.java](/c:/Users/Aaron/Documents/navalgo-app/navalgo/backend/src/main/java/com/navalgo/backend/media/UploadValidationService.java)

### Como defenderlo

Aunque DI se centra en interfaz, la app cuida seguridad visible para el usuario: gestion de sesion, expiracion controlada, privacidad accesible y proteccion razonable en operaciones sensibles como login, firma y adjuntos.

## 4. Resultado resumido

- Integracion: cubierta a nivel Flutter y servicios.
- Rendimiento: base razonable y arquitectura preparada para evitar bloqueos tontos.
- Seguridad: bien argumentada y apoyada por backend y cliente.

## 5. Honradez para la defensa

Lo correcto es decir que:

- la app ya tiene pruebas automatizadas utiles;
- la validacion E2E completa con backend real todavia puede ampliarse;
- las comprobaciones de rendimiento son basicas, pero la arquitectura ya aplica buenas practicas visibles.
