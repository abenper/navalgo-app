# Matriz final de evidencias PMDM

Este documento traduce los criterios de la rubrica PMDM a evidencias concretas del proyecto NavalGO. La idea es que puedas copiarlo a la memoria o usarlo como guion de defensa.

## Resumen rapido

Estado actual estimado para PMDM:

- Codigo estructurado, legible y mantenible: cubierto.
- Documentacion de instalacion y uso: cubierto.
- Pruebas funcionales: cubierto en automatizacion Flutter y pendiente de reforzar con capturas o video.
- Defensa del proyecto: pendiente de exposicion oral, no depende del repo.
- Buenas practicas de arquitectura movil: cubierto.
- Ventanas, menus, alertas y controles con usabilidad adecuada: cubierto.
- Navegacion por la app: cubierto.
- Uso de librerias para integracion: cubierto.

## 1. Codigo bien estructurado, legible y facil de mantener

### Evidencia exacta

- Arquitectura principal en [main.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/main.dart).
- Estado desacoplado en [viewmodels/](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/viewmodels).
- Servicios cliente en [services/](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services).
- Modelos de dominio en [models/](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/models).
- Shells por rol en:
  - [admin_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/admin/admin_shell_screen.dart)
  - [worker_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/worker_shell_screen.dart)
  - [commercial_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/commercial/commercial_shell_screen.dart)
  - [client_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/client/client_shell_screen.dart)

### Como defenderlo

El proyecto aplica separacion de responsabilidades entre interfaz, estado, servicios y modelos. Las pantallas no acceden directamente a red salvo a traves de servicios, y la sesion se coordina desde `SessionViewModel`.

### Verificacion

- `flutter analyze`
- [Arquitectura Flutter por capas](./arquitectura-flutter.md)

## 2. Documentacion de la aplicacion y contenido para su difusion

### Evidencia exacta

- Manual de instalacion en [manual-instalacion.md](./manual-instalacion.md).
- Manual de usuario en [manual-usuario.md](./manual-usuario.md).
- Documentacion de arquitectura en [arquitectura-flutter.md](./arquitectura-flutter.md).
- Documentacion de navegacion en [navegacion.md](./navegacion.md).
- Web comercial del producto en:
  - [marketing_site/index.html](/c:/Users/Aaron/Documents/navalgo-app/navalgo/marketing_site/index.html)
  - [marketing_site/styles.css](/c:/Users/Aaron/Documents/navalgo-app/navalgo/marketing_site/styles.css)

### Como defenderlo

La entrega no se limita al codigo: incluye documentacion tecnica, guia de instalacion, guia de uso y una web comercial que sirve como soporte de difusion del producto.

### Falta para cerrar al maximo

- Anadir 6 a 9 capturas reales dentro de [pruebas-funcionales.md](./pruebas-funcionales.md).
- Si puedes, enlazar un video corto de demo en la memoria.

## 3. Distintos tipos de pruebas incluyendo usabilidad

### Evidencia exacta

- Test de arranque de la app en [widget_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/widget_test.dart).
- Test de login en [auth_service_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/services/auth_service_test.dart).
- Test de fichaje en [time_tracking_service_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/services/time_tracking_service_test.dart).
- Test de creacion de parte en [work_order_service_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/services/work_order_service_test.dart).
- Test de firma en [work_order_media_service_test.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/test/services/work_order_media_service_test.dart).
- Guia de pruebas manuales en [pruebas-funcionales.md](./pruebas-funcionales.md).

### Como defenderlo

Se han combinado pruebas estaticas, pruebas automatizadas de servicios y pruebas funcionales guiadas sobre flujos criticos: login, fichaje, parte y firma.

### Verificacion

- `flutter test`
- `flutter analyze`

### Falta para cerrar al maximo

- Documentar una mini prueba de usabilidad con 3 personas.
- Adjuntar tabla breve con observaciones y mejora aplicada.

## 4. Buenas practicas en el diseno de la aplicacion

### Evidencia exacta

- Inyeccion de dependencias y estado en [main.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/main.dart:77).
- Gestion de sesion y refresh en [session_view_model.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/viewmodels/session_view_model.dart).
- Cliente HTTP centralizado en [api_client.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/network/api_client.dart).
- Gestion de token expirada y redireccion a login en [main.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/main.dart:59).
- Servicios especializados:
  - [auth_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/auth_service.dart)
  - [time_tracking_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/time_tracking_service.dart)
  - [work_order_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/work_order_service.dart)
  - [work_order_media_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/work_order_media_service.dart)

### Como defenderlo

La app sigue una arquitectura por capas, separa autenticacion, servicios y modelos, conserva el estado de sesion y trata los errores de red de forma uniforme. En Flutter sustituye el enfoque Android clasico por una organizacion equivalente adaptada al framework.

### Documento de apoyo

- [Arquitectura Flutter por capas](./arquitectura-flutter.md)

## 5. Uso de ventanas, menus, alertas y controles con usabilidad adecuada

### Evidencia exacta

- Pantalla de login en [login_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/common/login_screen.dart).
- Fichaje con seleccion guiada de tipo de jornada, hora prevista y geolocalizacion en [fichaje_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/fichaje_screen.dart).
- Dialogos de perfil y cambio de password en [profile_dialogs.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/widgets/profile_dialogs.dart).
- Componentes reutilizables de formulario y panel en [navalgo_ui.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/widgets/navalgo_ui.dart).
- Vistas por rol con menus persistentes en los diferentes `ShellScreen`.

### Como defenderlo

La interfaz esta organizada por tareas frecuentes, con formularios validados, modales para acciones secundarias, menus persistentes y retroalimentacion visual mediante toasts, chips de estado y paneles.

### Evidencia manual recomendada

- Captura de login.
- Captura de fichaje abierto.
- Captura de modal de solicitud de ajuste.
- Captura de detalle o firma de parte.

## 6. Navegacion por la app, boton atras y paso de parametros

### Evidencia exacta

- Grafo global documentado en [navegacion.md](./navegacion.md).
- Redireccion por rol desde [login_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/common/login_screen.dart:204).
- Navegacion inicial por URL y parametros en [main.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/main.dart:233).
- Entrada parametrizada a cliente en [_resolveClientInitialIndex()](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/common/login_screen.dart:390).
- Apertura de pantallas secundarias mediante `Navigator.push`, `pushReplacement` y `pushAndRemoveUntil`.
- Devolucion de datos desde formularios y dialogos con `Navigator.pop(result)`.

### Como defenderlo

La app tiene navegacion principal por shells y navegacion secundaria por rutas y dialogos. El boton atras devuelve al contexto previo y el paso de parametros se usa en registro, verificacion, reseteo y entrada a secciones concretas.

### Verificacion manual recomendada

1. Entrar como admin y abrir un formulario de flota o equipo.
2. Volver con el boton atras.
3. Entrar como cliente con acceso a presupuestos.
4. Confirmar apertura de la seccion correcta.

## 7. Uso de librerias para multimedia, servicios web y otras integraciones

### Evidencia exacta

- Dependencias declaradas en [pubspec.yaml](/c:/Users/Aaron/Documents/navalgo-app/navalgo/pubspec.yaml).
- Justificacion de librerias en [librerias.md](./librerias.md).
- Geolocalizacion en [fichaje_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/fichaje_screen.dart).
- Firma digital y adjuntos en [work_order_media_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/work_order_media_service.dart).
- API REST en [auth_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/auth_service.dart), [time_tracking_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/time_tracking_service.dart) y [work_order_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/work_order_service.dart).
- Firebase y push en:
  - [main.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/main.dart)
  - [push_notification_service.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/services/push_notification_service.dart)

### Como defenderlo

Se integran librerias de red, notificaciones, firma, geolocalizacion, seleccion de archivos, visualizacion multimedia y tipografia. Cada una responde a un requisito funcional real del producto.

## 8. Plantilla breve para copiar a la memoria

Puedes reutilizar este texto:

> NavalGO cumple los criterios principales de PMDM mediante una arquitectura Flutter por capas, navegacion separada por rol, integracion con servicios web REST, firma digital, geolocalizacion puntual y notificaciones. La evidencia se apoya en documentacion de instalacion y uso, un grafo de navegacion explicito, pruebas automatizadas de flujos criticos y una interfaz adaptable a web y movil.

## 9. Ultimos materiales que debes adjuntar

Para rematar el 4 sobre 4 en la entrega:

- Captura 1: login.
- Captura 2: panel admin.
- Captura 3: fichaje.
- Captura 4: listado o detalle de partes.
- Captura 5: firma del parte.
- Captura 6: flota o presupuestos.
- Captura 7: prueba de persistencia en Swagger o base de datos.
- Video corto de 3 a 5 minutos, si el profesor lo valora positivamente.
- Mini tabla de usabilidad con 3 usuarios de prueba.
