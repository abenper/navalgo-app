# Matriz de evidencias ADA

## Documentar que informacion gestionas en ficheros y por que

- Evidencia: `docs/ada/ficheros-y-exportables.md`
- Evidencia: servicios `BudgetMediaService`, `WorkOrderMediaService`,
  `WorkOrderEvidencePdfService`, `FirebasePushGateway`
- Defensa: los binarios viven fuera de la BD y la BD conserva referencias y
  metadatos de integridad.

## Demostrar lectura y escritura real de ficheros o exportables

- Evidencia: subida de PDF de presupuestos en `/api/budgets/uploads`
- Evidencia: subida de adjuntos y firmas en `/api/work-orders/...`
- Evidencia: descarga de PDF en `/api/work-orders/{id}/evidence-report`
- Evidencia: lectura de credenciales Firebase desde fichero JSON o ruta local

## Explicar ventajas e inconvenientes del acceso por fichero usado

- Evidencia: seccion dedicada en `docs/ada/ficheros-y-exportables.md`
- Defensa: almacenamiento de objetos para binarios grandes y BD para metadatos,
  con el coste de coordinar dos persistencias distintas.

## Mostrar CRUD completo sobre base de datos

- Evidencia: `docs/ada/crud-y-consultas.md`
- Evidencia: controladores de `fleet`, `work-orders`, `budgets`,
  `leave-requests` y `time-tracking`
- Defensa: hay altas, lecturas, actualizaciones y borrado fisico o archivado
  segun el historial del registro.

## Mostrar consultas distintas, no solo altas y listados

- Evidencia: repositorios con `findBy...`, `existsBy...`, `countBy...` y
  `@Query`
- Defensa: se resuelven casos de negocio como vencimientos, solapes,
  notificaciones pendientes e historicos por embarcacion o trabajador.

## Documentar el modelo relacional y justificarlo

- Evidencia: `docs/ada/modelo-relacional.md`
- Evidencia: entidades JPA y `db/postgres-startup-schema.sql`
- Defensa: el modelo se apoya en relaciones uno-a-muchos, muchos-a-muchos y
  entidades de historial.

## Explicar el ORM y donde aprovechas JPA, relaciones y transacciones

- Evidencia: `docs/ada/orm-jpa-y-transacciones.md`
- Evidencia: `spring-boot-starter-data-jpa` en `backend/pom.xml`
- Defensa: JPA cubre el mapeo de entidades, relaciones, repositorios y
  operaciones transaccionales de negocio.

## Material recomendable para la entrega

- Captura de `backend/pom.xml` con JPA, PostgreSQL y PDFBox.
- Captura de `application.yml` y `application-postgres.yml`.
- Captura del diagrama relacional de `docs/ada/modelo-relacional.md`.
- Captura de endpoints de CRUD y de la descarga del PDF de evidencias.
