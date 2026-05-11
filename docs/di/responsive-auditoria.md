# Auditoria responsive y capturas pendientes

## Objetivo

Verificar que la interfaz se adapta a movil, tablet y escritorio sin perder jerarquia visual ni usabilidad.

## Evidencias de responsive en el codigo

### Shells principales

- `AdminShellScreen`: cambia entre `Drawer` y `NavigationRail` segun ancho.
- `WorkerShellScreen`: cambia entre `NavigationBar` y `NavigationRail`.
- `CommercialShellScreen`: usa `Drawer` en movil estrecho y `NavigationRail` en escritorio.
- `ClientShellScreen`: usa `Drawer` en movil y `NavigationRail` en escritorio.

Archivos:

- [admin_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/admin/admin_shell_screen.dart)
- [worker_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/worker_shell_screen.dart)
- [commercial_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/commercial/commercial_shell_screen.dart)
- [client_shell_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/client/client_shell_screen.dart)

### Pantallas con ajustes explicitos

- Login con `ConstrainedBox` y scroll vertical.
- Fichaje con distribucion compacta o en dos columnas.
- Vacaciones y ausencias con `LayoutBuilder`, `Wrap` y cambios de densidad.
- Flota con tarjetas adaptativas y paneles apilados o paralelos.
- Dashboards con rejillas que cambian numero de columnas.

Archivos recomendados para enseñar:

- [login_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/common/login_screen.dart)
- [fichaje_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/fichaje_screen.dart)
- [vacaciones_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/vacaciones_screen.dart)
- [flota_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/admin/flota_screen.dart)
- [admin_dashboard_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/admin/admin_dashboard_screen.dart)
- [worker_dashboard_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/worker_dashboard_screen.dart)
- [client_dashboard_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/client/client_dashboard_screen.dart)
- [commercial_budgets_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/commercial/commercial_budgets_screen.dart)

## Breakpoints observados

Valores frecuentes en el proyecto:

- `390 px`: header compacto.
- `420-520 px`: modales y pantallas de acceso.
- `560-760 px`: reflujo de bloques y cards.
- `720 px`: cambio a rail en worker.
- `860-960 px`: apilado frente a columnas en paneles y shells.
- `980 px` o superior: dashboards con mas columnas.

## Lista de capturas que debes hacer

### Movil

- Login.
- Worker shell.
- Fichaje.
- Partes.
- Ausencias o vacaciones.
- Cuenta cliente o comercial.

### Tablet

- Admin shell.
- Flota.
- Dashboard admin.
- Dashboard worker.
- Presupuestos.

### Web o escritorio

- Landing comercial.
- Admin shell con rail.
- Worker shell con rail o bottom layout amplio.
- Client shell con rail.
- Parte abierto con evidencias o firma.

## Tabla de control de capturas

| Pantalla | Movil | Tablet | Web | Estado |
| --- | --- | --- | --- | --- |
| Login | Sí | Sí | Sí | Pendiente de capturar |
| Dashboard admin | No | Sí | Sí | Pendiente de capturar |
| Dashboard worker | Sí | Sí | Sí | Pendiente de capturar |
| Fichaje | Sí | Sí | Sí | Pendiente de capturar |
| Partes | Sí | Sí | Sí | Pendiente de capturar |
| Flota | No | Sí | Sí | Pendiente de capturar |
| Presupuestos | Sí | Sí | Sí | Pendiente de capturar |
| Cuenta cliente | Sí | Sí | Sí | Pendiente de capturar |
| Landing marketing | Sí | Sí | Sí | Pendiente de capturar |

## Revision previa a capturar

- Confirmar que no hay textos cortados.
- Confirmar que botones importantes son visibles sin zoom.
- Confirmar que menus, drawers y rails no pisan contenido.
- Confirmar que no quedan acentos rotos.
- Confirmar que no aparece contenido de demo incompleto o pantallas sin terminar.
