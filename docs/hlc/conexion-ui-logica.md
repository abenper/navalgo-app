# Conexion UI-logica

## Formularios y flujos comprobados

## Login

- `LoginScreen` recoge credenciales y recuerda email si el usuario lo activa.
- La accion principal delega en `LoginViewModel`.
- `LoginViewModel` usa `AuthService` y actualiza `SessionViewModel`.
- La navegacion final depende del rol autenticado, no de logica embebida en
  widgets sueltos.

## Fichaje

- `FichajeScreen` consulta `TimeTrackingService` para cargar registros.
- El alta de fichaje requiere tipo de jornada, hora prevista y ubicacion.
- Las acciones de entrada y salida llaman a `clockIn` y `clockOut`.
- Tras cada operacion la pantalla recarga datos reales para mantener la UI en
  sincronizacion con el backend.

## Partes

- `PartesScreen` carga flota, operarios y partes desde sus viewmodels
  especializados.
- La creacion del parte usa un dialogo para recoger datos y delega la
  persistencia en `WorkOrderService`.
- La firma, los adjuntos y los cambios posteriores se apoyan en servicios
  especificos en lugar de resolverse con estado local disperso.

## Ausencias

- `AusenciasScreen` usa `LeaveService` para listar, crear, editar y cancelar
  solicitudes.
- El modo admin anade carga de trabajadores desde `WorkerService`.
- La seleccion de fechas y motivos se encapsula en dialogos con `Form` y
  validaciones antes de persistir.

## Conclusion

Los formularios principales no se limitan a cambiar widgets locales: estan
conectados con servicios y estado compartido. Esto demuestra una union correcta
entre interfaz, validacion, persistencia y refresco de datos.
