# CRUD y consultas

## CRUD completo sobre base de datos

### Propietarios

- Crear: `POST /api/fleet/owners`
- Leer: `GET /api/fleet/owners`
- Actualizar: `PUT /api/fleet/owners/{id}`
- Borrar o archivar: `DELETE /api/fleet/owners/{id}`

### Embarcaciones

- Crear: `POST /api/fleet/vessels`
- Leer: `GET /api/fleet/vessels`
- Actualizar: `PUT /api/fleet/vessels/{id}`
- Borrar o archivar: `DELETE /api/fleet/vessels/{id}`

### Partes de trabajo

- Crear: `POST /api/work-orders`
- Leer: `GET /api/work-orders` y `GET /api/work-orders/{id}`
- Actualizar: `PATCH /api/work-orders/{id}` y `PATCH /api/work-orders/{id}/status`
- Borrar: `DELETE /api/work-orders/{id}`

### Presupuestos

- Crear: `POST /api/budgets`
- Leer: `GET /api/budgets`
- Actualizar: `PUT /api/budgets/{id}`, `PATCH /api/budgets/{id}/status`,
  `PATCH /api/budgets/{id}/vessel`
- Borrar: `DELETE /api/budgets/{id}`

### Ausencias

- Crear: `POST /api/leave-requests`
- Leer: `GET /api/leave-requests`
- Actualizar: `PUT /api/leave-requests/{id}` y cambios de estado
- Borrar logico/funcional: cancelacion de solicitudes

### Fichajes

- Crear: entrada y salida de jornada
- Leer: listados y resumenes por trabajador y por dia
- Actualizar: correcciones y solicitudes de ajuste
- Borrar funcional: eliminacion de solicitudes de ajuste

## Consultas distintas, no solo altas y listados

El proyecto usa consultas derivadas de JPA y consultas personalizadas para
resolver casos reales de negocio:

- Partes por trabajador: `findByAssignedWorkersIdOrderByCreatedAtDesc(...)`
- Partes por embarcacion: `findByVesselIdOrderByCreatedAtAsc/Desc(...)`
- Partes pendientes fuera de plazo: `findByCloseDueDateBeforeAndStatusNotInOrderByCloseDueDateAsc(...)`
- Embarcaciones activas por propietario: `findByOwnerIdAndArchivedFalseOrderByNameAsc(...)`
- Ausencias no canceladas por trabajador: `findByWorkerIdAndStatusNotOrderByStartDateDesc(...)`
- Deteccion de solapes de ausencias: `existsByWorkerIdAndStatusAndStartDateLessThanEqualAndEndDateGreaterThanEqual(...)`
- Fichajes abiertos: `findByClockOutIsNullOrderByClockInAsc()`
- Fichajes vencidos por hora prevista: `findByClockOutIsNullAndPlannedClockOutLessThanEqualOrderByPlannedClockOutAsc(...)`
- Presupuestos por cliente y por origen: `findByOwnerIdOrderByCreatedAtDesc(...)`,
  `findByOriginBudgetIdOrderByCreatedAtAsc(...)`
- Conteo de notificaciones no leidas: `countByWorkerIdAndIsReadFalse(...)`

## Valor academico

Estas consultas demuestran:

- filtrado por claves ajenas;
- ordenacion cronologica;
- comprobaciones de existencia;
- conteos agregados;
- consulta de pendientes y vencimientos;
- relaciones historicas entre entidades.

## Defensa para la memoria

La aplicacion no se apoya en una sola tabla ni en operaciones triviales. El
acceso a datos resuelve escenarios reales: historial de partes por embarcacion,
ausencias solapadas, fichajes abiertos, presupuestos reemitidos y contadores de
notificaciones, entre otros.
