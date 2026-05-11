# Matriz de evidencias SGE

## Ampliar la documentacion tecnica para cubrir todos los modulos

- Evidencia: `docs/sge/modulos-tecnicos.md`
- Evidencia: `backend/README.md`, `backend/DEPLOYMENT.md`, `backend/VPS_DEPLOY.md`
- Defensa: se documentan frontend, backend, landing, despliegue e infraestructura

## Anadir diagramas de modulos, clases y flujos principales

- Evidencia: `docs/sge/diagramas-y-flujos.md`
- Defensa: incluye arquitectura general, backend tecnico, clases de evidencia y flujos de login y exportacion

## Documentar verificacion de sistema operativo, Java, BD, variables y despliegue

- Evidencia: `docs/sge/verificacion-entorno-y-despliegue.md`
- Evidencia: `backend/.env.example`, `backend/docker-compose.yml`, `application*.yml`
- Defensa: se contrastan requisitos declarados con herramientas verificadas localmente

## Demostrar consultas sobre datos y acceso segun especificaciones

- Evidencia: `docs/sge/consultas-accesos-y-exportacion.md`
- Evidencia: control de roles en `SecurityConfig` y `@PreAuthorize`
- Defensa: se documentan endpoints de consulta, filtros por rol y rutas administrativas

## Demostrar manipulacion y exportacion de datos

- Evidencia: carga de PDF de presupuestos y multimedia de partes
- Evidencia: exportacion `GET /api/work-orders/{id}/evidence-report`
- Defensa: el sistema crea, actualiza, archiva y exporta informacion operativa real

## Documentar mecanismos de autoria, trazabilidad e incidencias

- Evidencia: `docs/sge/autoria-trazabilidad.md`
- Evidencia: `RequestIdFilter`, `GlobalExceptionHandler`, `WorkOrderEvidenceService`, `BudgetEvent`, `NotificationEntity`
- Defensa: se cubren autoria funcional, trazabilidad tecnica y custodia de evidencias

## Anadir un pequeno registro de incidencias detectadas y como se resolvieron

- Evidencia: `docs/sge/registro-incidencias.md`
- Defensa: se registran incidencias reales detectadas durante la auditoria y su resolucion

## Material recomendable para la entrega

- Captura de `docs/sge/diagramas-y-flujos.md`
- Captura de `backend/.env.example` y `backend/docker-compose.yml`
- Captura de `backend/README.md` o `DEPLOYMENT.md`
- Captura del endpoint de exportacion de evidencias y del estado `actuator/health`
