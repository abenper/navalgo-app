# Navalgo Backend (Spring Boot)

Backend de NavalGO con estos dominios:
- autenticacion y autorizacion
- trabajadores
- empresas
- propietarios y embarcaciones
- partes de trabajo
- fichajes
- ausencias y vacaciones
- notificaciones
- media adjunta y firma digital

## 1) Stack y estado actual

- Java 21
- Maven 3.9+
- Spring Boot 3.3.5
- Spring Security + JWT access token
- Refresh token opaco persistido en base de datos
- PostgreSQL en produccion, H2 para entorno local rapido

La base segura actual mantiene las funcionalidades existentes y añade:
- `access token` corto en respuesta JSON
- `refresh token` rotatorio en cookie `HttpOnly`
- errores API estructurados con `requestId`
- limitacion basica de intentos de login
- validacion de uploads y saneado de texto de entrada

## 2) Arranque

```bash
cd backend
mvn spring-boot:run
```

### Arranque con PostgreSQL

1. Crear base de datos:

```sql
CREATE DATABASE navalgo;
```

2. Aplicar esquema:

```bash
psql -h localhost -U postgres -d navalgo -f navalgo_backend_postgres.sql
```

3. Definir variables de entorno principales:

```bash
APP_JWT_SECRET=un_secreto_de_al_menos_32_bytes
APP_JWT_EXPIRATION_MS=3600000
APP_JWT_REFRESH_EXPIRATION_MS=604800000
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/navalgo
SPRING_DATASOURCE_USERNAME=navalgo
SPRING_DATASOURCE_PASSWORD=cambia_esto
```

4. Arrancar con perfil `postgres`:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=postgres
```

## 3) Auth y sesion

### Login

`POST /api/auth/login`

Request:

```json
{
  "email": "admin@navalgo.com",
  "password": "1234"
}
```

Response:

```json
{
  "user": {
    "id": 1,
    "name": "Admin Navalgo",
    "email": "admin@navalgo.com",
    "role": "ADMIN",
    "mustChangePassword": false,
    "canEditWorkOrders": true
  },
  "token": "...",
  "tokenType": "Bearer",
  "expiresAt": "2026-04-16T18:00:00Z"
}
```

Además, el backend devuelve una cookie `HttpOnly` con el refresh token.

### Refresh

`POST /api/auth/refresh`

- requiere la cookie de refresh
- invalida el refresh token previo y emite uno nuevo
- devuelve un nuevo access token JSON

### Logout

`POST /api/auth/logout`

- revoca el refresh token actual
- limpia la cookie

### Cambio de password

`POST /api/auth/change-password`

- exige usuario autenticado
- revoca sesiones activas tras el cambio

## 4) Endpoints principales

### Trabajadores
- `GET /api/workers`
- `POST /api/workers`
- `PUT /api/workers/{id}`
- `PATCH /api/workers/{id}/active`

### Empresas
- `GET /api/companies`
- `POST /api/companies`
- `GET /api/companies/{id}`

### Flota
- `GET /api/fleet/owners`
- `POST /api/fleet/owners`
- `PUT /api/fleet/owners/{id}`
- `GET /api/fleet/vessels?ownerId=`
- `POST /api/fleet/vessels`
- `PUT /api/fleet/vessels/{id}`

### Partes de trabajo
- `GET /api/work-orders`
- `POST /api/work-orders`
- `PUT /api/work-orders/{id}`
- `PATCH /api/work-orders/{id}/status`
- `PATCH /api/work-orders/{id}/material-checklist`
- `POST /api/work-orders/{id}/material-revision-requests`
- `PATCH /api/work-orders/{id}/material-revision-requests/{requestId}`
- `POST /api/work-orders/{id}/sign`
- `DELETE /api/work-orders/{workOrderId}/attachments/{attachmentId}`

### Plantillas de revisión de material
- `GET /api/material-checklist-templates`
- `POST /api/material-checklist-templates`
- `PUT /api/material-checklist-templates/{id}`

### Fichajes
- `POST /api/time-entries/clock-in`
- `POST /api/time-entries/clock-out`
- `GET /api/time-entries/worker/{workerId}`
- `GET /api/time-entries/today-summary`

### Ausencias / Vacaciones
- `GET /api/leave-requests?workerId=`
- `POST /api/leave-requests`
- `PATCH /api/leave-requests/{id}/status`

## 5) Flutter Web y Flutter móvil

### Access token

El frontend debe seguir enviando el access token en el header `Authorization: Bearer ...`.

### Refresh token en Flutter Web

Para que Chrome acepte y reenvie la cookie de refresh en peticiones `fetch` o `http`, el backend debe estar publicado por HTTPS y con:
- `APP_SECURITY_COOKIE_SAME_SITE=None`
- `APP_SECURITY_COOKIE_SECURE=true`
- `credentials: include` en el cliente
- `CORS` limitado al dominio real del frontend

Si el backend sigue sirviendose por `http://IP:8080`, los navegadores modernos pueden bloquear la cookie de refresh aunque el login funcione. En ese escenario, el access token seguira funcionando, pero la renovacion automatica por cookie no sera fiable.

### Ejemplo Flutter

Web local contra backend local:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

Android emulador:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

Web contra produccion:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://api.tu-dominio.com/api
```

## 6) Configuracion relevante

Propiedades nuevas o endurecidas:
- `APP_JWT_SECRET`
- `APP_JWT_EXPIRATION_MS`
- `APP_JWT_REFRESH_EXPIRATION_MS`
- `APP_SECURITY_CORS_ALLOWED_ORIGINS`
- `APP_SECURITY_COOKIE_REFRESH_NAME`
- `APP_SECURITY_COOKIE_SAME_SITE`
- `APP_SECURITY_COOKIE_SECURE`
- `APP_SECURITY_COOKIE_PATH`
- `APP_MEDIA_MAX_IMAGE_SIZE_BYTES`
- `APP_MEDIA_MAX_VIDEO_SIZE_BYTES`
- `APP_MEDIA_MAX_SIGNATURE_SIZE_BYTES`
- `APP_MEDIA_MAX_PROFILE_PHOTO_SIZE_BYTES`

## 7) Swagger

- http://localhost:8080/swagger-ui/index.html

## 8) Credenciales semilla

Se cargan automaticamente en arranque (`DataInitializer`):
- admin@navalgo.com / 1234
- worker@navalgo.com / 1234

Estas credenciales deben existir solo en desarrollo o demo controlada.

## 9) Checklist DevSecOps

- `APP_JWT_SECRET` definido con longitud suficiente
- PostgreSQL no expuesto publicamente
- backend publicado detras de Nginx o proxy TLS
- `APP_SECURITY_CORS_ALLOWED_ORIGINS` restringido a dominios reales
- cookie de refresh solo con HTTPS en produccion
- backups de PostgreSQL y prueba de restauracion
- logs y monitorizacion de `actuator/health`
- rotacion de secretos y credenciales operativas
