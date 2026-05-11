# Modulos tecnicos

## Vision general del proyecto

NavalGO se organiza en varios modulos tecnicos complementarios:

- `lib/`: aplicacion Flutter principal para web y movil.
- `backend/`: API Spring Boot con seguridad, persistencia, media y notificaciones.
- `marketing_site/`: landing comercial estatica.
- `web/`: shell web generado por Flutter.
- `android/`, `ios/`, `windows/`, `linux/`, `macos/`: plataformas cliente.
- `test/`: pruebas de Flutter.
- `docs/`: documentacion academica y tecnica.

## Modulos del frontend Flutter

- `app/`: arranque global y elementos de aplicacion.
- `config/`: configuracion del cliente.
- `models/`: modelos de dominio mostrados en UI.
- `screens/`: pantallas por rol y funcionalidad.
- `services/`: acceso HTTP y operaciones de cliente.
- `viewmodels/`: estado y coordinacion con `provider`.
- `widgets/`: componentes reutilizables.
- `utils/` y `theme/`: utilidades transversales y estilo visual.

## Modulos del backend

- `api`: salud y gestion global de errores.
- `auth`: login, refresh token, registro, verificacion y password reset.
- `security`: JWT, filtros, CORS, cookies y cabeceras de seguridad.
- `worker`: gestion de empleados y perfiles.
- `company`: empresas.
- `fleet`: propietarios y embarcaciones.
- `workorder`: partes, checklist, evidencias, firma y exportacion PDF.
- `timetracking`: fichajes, ajustes y recordatorios programados.
- `leave`: ausencias y vacaciones.
- `budget`: presupuestos y eventos de historial.
- `notification`: centro de notificaciones, push y diagnostico.
- `media`: proxy y validacion de multimedia.
- `common`: enums, saneado de entrada y datos semilla.

## Modulos de infraestructura y operacion

- `backend/docker-compose.yml`: servicio backend para despliegue.
- `backend/deploy.sh`: despliegue automatizado en servidor.
- `backend/.env.example`: variables de entorno.
- `backend/deploy/*.conf`: configuracion Nginx para dominios publico, app y API.
- `backend/DEPLOYMENT.md` y `backend/VPS_DEPLOY.md`: guias operativas.
- `backend/src/main/resources/application*.yml`: configuracion local y de
  produccion.

## Cobertura funcional por modulo

- Comercial: landing y presupuestos.
- Operativa interna: partes, fichajes, ausencias, flota y equipo.
- Cliente: consulta de presupuestos y relacion con embarcaciones.
- Sistema: autenticacion, sesiones, media, notificaciones, auditoria y salud.

## Defensa para la memoria

La documentacion tecnica ya no se limita al backend. Quedan cubiertos los
modulos de interfaz, negocio, persistencia, despliegue y operacion, de forma
coherente con una solucion empresarial completa.
