# ADA

Esta carpeta reune las evidencias de Acceso a Datos de NavalGO. El proyecto no
se limita a guardar listas simples: combina persistencia relacional con JPA,
tratamiento de ficheros multimedia y exportacion documental.

## Documentos

- `docs/ada/matriz-evidencias.md`
- `docs/ada/ficheros-y-exportables.md`
- `docs/ada/crud-y-consultas.md`
- `docs/ada/modelo-relacional.md`
- `docs/ada/orm-jpa-y-transacciones.md`

## Resumen rapido

- Desarrollo local con H2 y produccion con PostgreSQL.
- Persistencia ORM con Spring Data JPA sobre entidades de dominio.
- CRUD real sobre propietarios, embarcaciones, partes, ausencias, presupuestos
  y fichajes.
- Consultas derivadas y consultas personalizadas en repositorios.
- Gestion de ficheros para PDF de presupuestos, adjuntos multimedia, firma de
  partes y acta PDF de evidencias.
