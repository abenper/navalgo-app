# Ficheros y exportables

## Informacion gestionada en ficheros

NavalGO no guarda binarios pesados dentro de la base de datos relacional. La
informacion multimedia y documental se trata como fichero externo y en la base
de datos solo se conserva la referencia y sus metadatos tecnicos.

### Tipos de fichero usados

- PDF de presupuestos subidos por el area comercial.
- Imagenes y videos adjuntos a los partes de trabajo.
- Firma del operario y firma del cliente.
- Foto de perfil del usuario.
- Acta PDF de integridad de evidencias generada por el backend.
- Fichero JSON de credenciales Firebase para notificaciones push.
- Script SQL de arranque para reconciliar esquema PostgreSQL.

## Donde aparece en el proyecto

- `BudgetMediaService` sube presupuestos PDF a almacenamiento de objetos.
- `WorkOrderMediaService` procesa imagenes, videos, firmas y fotos de perfil.
- `WorkOrderEvidencePdfService` genera un PDF descargable con la cadena de
  custodia de un parte.
- `FirebasePushGateway` lee credenciales desde JSON embebido o desde ruta de
  fichero.
- `db/postgres-startup-schema.sql` aplica ajustes DDL sobre PostgreSQL.

## Lectura y escritura real

### Escritura

- `BudgetMediaService.uploadBudgetPdf(...)` lee el PDF recibido en
  `MultipartFile`, construye una clave y lo sube al almacenamiento.
- `WorkOrderMediaService` procesa binarios, genera versiones finales y sube los
  bytes a Spaces/S3.
- `WorkOrderEvidencePdfService.buildReport(...)` crea un PDF en memoria y lo
  devuelve como descarga administrativa.

### Lectura

- `FirebasePushGateway` abre el fichero de credenciales con `Files.newInputStream(...)`.
- `WorkOrderMediaService` usa operaciones de `Files` para leer binarios
  temporales durante el procesamiento de video.
- `WorkOrderEvidencePdfService` lee el logo desde recursos para incorporarlo al
  PDF final.

## Por que se usa fichero y no base de datos para binarios

- Los PDF, fotos, firmas y videos ocupan mucho mas que los datos de negocio.
- El almacenamiento de objetos es mas apropiado para ficheros grandes y
  descargables.
- La base de datos conserva solo lo necesario para trazabilidad y relacion con
  el dominio: URL, clave del objeto, hash, tamano, tipo MIME, GPS, fechas y
  usuario que subio el archivo.

## Ventajas del acceso por fichero usado

- Reduce el peso de la base de datos relacional.
- Facilita servir descargas y multimedia desde almacenamiento especializado.
- Permite guardar evidencias y exportables sin penalizar tanto las consultas SQL.
- Mejora la trazabilidad al combinar fichero + metadatos + hash + firma de
  servidor.

## Inconvenientes del acceso por fichero usado

- Obliga a coordinar dos capas de persistencia: BD relacional y almacenamiento
  de objetos.
- Exige controlar huellas, URLs y borrado de objetos para no dejar residuos.
- La consistencia total requiere transacciones logicas entre base de datos y
  almacenamiento externo, aunque no exista una transaccion ACID unica entre
  ambos mundos.
- Anade complejidad de permisos, validacion y limites de tamano.

## Defensa para la memoria

En NavalGO se usa acceso por fichero para los contenidos binarios porque su
naturaleza documental y multimedia encaja mejor en almacenamiento de objetos que
en tablas relacionales. La base de datos conserva referencias y metadatos de
integridad, mientras que el fichero externo conserva el binario final.
