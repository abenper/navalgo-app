# Autoria y trazabilidad

## Mecanismos de autoria

### Evidencia de adjuntos en partes

Cada `WorkOrderAttachment` conserva:

- usuario que subio el archivo;
- nombre original;
- fecha de captura;
- fecha de subida al servidor;
- IP de subida;
- `User-Agent`;
- coordenadas GPS;
- tamano;
- tipo MIME;
- clave del objeto y URL publica.

### Historial de presupuestos

`BudgetEvent` conserva:

- tipo de evento;
- nombre del actor;
- rol del actor;
- nota operativa;
- fecha de creacion del evento.

### Notificaciones

`NotificationEntity` conserva:

- trabajador destinatario;
- titulo;
- mensaje;
- tipo;
- ruta de accion;
- estado de lectura;
- fecha de creacion.

## Mecanismos de trazabilidad tecnica

### Request ID

- `RequestIdFilter` genera o sanea `X-Request-ID`
- El identificador se expone en respuesta y se inserta en MDC
- `GlobalExceptionHandler` lo devuelve en errores API estructurados

### Integridad de evidencias

`WorkOrderEvidenceService` aplica:

- hash SHA-256 del manifiesto;
- firma HMAC del manifiesto;
- firma HMAC por adjunto;
- orden estable del payload sellado.

### PDF de cadena de custodia

`WorkOrderEvidencePdfService` exporta:

- datos del parte;
- datos del adjunto;
- hash del fichero;
- firma HMAC del adjunto;
- GPS, IP, agente de usuario y usuario que subio el archivo.

### Trazabilidad operativa programada

`TimeTrackingReminderService` registra y automatiza:

- recordatorios por falta de fichaje;
- recordatorios de jornada abierta;
- cierres automaticos por hora prevista;
- cierres forzados fin de dia con aviso a administracion.

## Valor para SGE

Estos mecanismos permiten responder preguntas de gestion y auditoria:

- quien hizo la accion;
- cuando se realizo;
- sobre que entidad se hizo;
- que evidencia tecnica quedo asociada;
- como se puede rastrear una incidencia entre frontend, API y backend.
