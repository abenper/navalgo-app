# Consultas, accesos y exportacion

## Acceso segun especificaciones

La seguridad combina autenticacion JWT, refresh token en cookie, filtros de
seguridad y control de acceso por rol con `@PreAuthorize`.

### Publicos

- `POST /api/auth/*`
- `GET /api/health`
- `GET /actuator/health`
- Swagger solo si `app.security.swagger.public=true`

### ADMIN

- Gestion completa de trabajadores, flota, partes, material, push debug y
  exportacion de evidencias.
- Acceso a `GET /api/work-orders/{id}/evidence-report`
- Acceso a `GET /api/push-debug/status` y `GET /api/push-debug/tokens`

### COMERCIAL

- Gestion de clientes, embarcaciones y presupuestos
- Consulta de flota
- Uso de la app Flutter con sus modulos asignados

### WORKER

- Consulta de sus partes
- Fichajes y solicitudes de ajuste
- Ausencias
- Subida de evidencia y firma

### CLIENT

- Consulta de presupuestos visibles y vinculacion final con embarcacion

## Consultas sobre datos

### Ejemplos representativos

- `GET /api/fleet/vessels?ownerId=`: filtra embarcaciones por propietario
- `GET /api/work-orders?workerId=`: filtra partes por trabajador
- `GET /api/time-entries/today-summary`: resumen diario de fichajes
- `GET /api/leave-requests?workerId=`: ausencias por trabajador
- `GET /api/notifications/unread-count`: conteo de notificaciones no leidas
- `GET /api/push-debug/tokens`: diagnostico administrativo de tokens push

## Manipulacion de datos

### Altas y actualizaciones

- Alta y edicion de propietarios y embarcaciones
- Alta, cambio de estado y actualizacion de partes
- Alta y cambio de estado de presupuestos
- Fichaje de entrada y salida
- Alta, edicion y revision de ausencias
- Alta y revision de solicitudes de ajuste horario

### Operaciones con reglas de negocio

- Archivado de propietarios y embarcaciones si existe historial asociado
- Cierre automatico de jornadas abiertas
- Sellado de evidencias al firmar un parte
- Reemision de presupuestos rechazados
- Notificaciones a admins y trabajadores segun eventos

## Exportacion de datos

### Exportables reales del sistema

- `GET /api/work-orders/{id}/evidence-report`
  genera un PDF administrativo con metadatos, hash y firmas de evidencia.
- `POST /api/budgets/uploads`
  permite subir y asociar PDF de presupuesto.
- `POST /api/work-orders/uploads`
  y rutas de firma/adjunto para multimedia y prueba operativa.

## Valor de gestion empresarial

El sistema no solo guarda datos: permite consultarlos por contexto de negocio,
manipularlos con reglas operativas y exportarlos en formatos utiles para
seguimiento, auditoria y administracion.
