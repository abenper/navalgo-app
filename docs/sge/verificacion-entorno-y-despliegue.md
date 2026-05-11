# Verificacion de entorno y despliegue

## Requisitos declarados por el proyecto

- Java 21 en `backend/pom.xml`
- Maven 3.9 o superior
- Spring Boot 3.3.5
- H2 para desarrollo local
- PostgreSQL para produccion
- Docker y Docker Compose para despliegue del backend
- Nginx para publicacion de dominios

## Verificacion local realizada el 2026-05-11

### Herramientas detectadas en esta maquina

| Elemento | Resultado verificado |
| --- | --- |
| Sistema operativo | Windows 11 amd64 |
| Java | 23.0.2 |
| Maven | 3.9.9 |
| Docker | 29.0.1 |

### Comandos usados

```bash
java -version
mvn -v
docker --version
```

## Interpretacion

- El proyecto declara Java 21, pero la herramienta local disponible es Java 23.
- Maven y Docker estan presentes y permiten desarrollo y despliegue.
- Para produccion conviene homologar el backend con Java 21, que es la version
  indicada en el `pom.xml`.

## Base de datos y perfiles

- `application.yml`: entorno local con H2 en memoria.
- `application-postgres.yml`: entorno PostgreSQL con `ddl-auto: validate`.
- `db/postgres-startup-schema.sql`: reconciliacion de esquema PostgreSQL.

## Variables de entorno principales

### Seguridad y sesion

- `APP_JWT_SECRET`
- `APP_JWT_EXPIRATION_MS`
- `APP_JWT_REFRESH_EXPIRATION_MS`
- `APP_SECURITY_CORS_ALLOWED_ORIGINS`
- `APP_SECURITY_COOKIE_REFRESH_NAME`
- `APP_SECURITY_COOKIE_SAME_SITE`
- `APP_SECURITY_COOKIE_SECURE`
- `APP_SECURITY_COOKIE_PATH`

### Base de datos

- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`

### Multimedia y storage

- `APP_MEDIA_SPACES_ENDPOINT`
- `APP_MEDIA_SPACES_REGION`
- `APP_MEDIA_SPACES_BUCKET`
- `APP_MEDIA_SPACES_ACCESS_KEY`
- `APP_MEDIA_SPACES_SECRET_KEY`
- `APP_MEDIA_PUBLIC_BASE_URL`

### Push y email

- `APP_FIREBASE_ENABLED`
- `APP_FIREBASE_SERVICE_ACCOUNT_PATH`
- `APP_FIREBASE_SERVICE_ACCOUNT_JSON`
- `APP_EMAIL_ENABLED`
- `APP_EMAIL_RESEND_API_KEY`

## Despliegue documentado

### Backend

- `backend/docker-compose.yml`
- `backend/deploy.sh`
- `backend/.env.example`
- `backend/DEPLOYMENT.md`
- `backend/VPS_DEPLOY.md`

### Publicacion

- `naval-go.com`: landing comercial
- `app.naval-go.com`: app Flutter web
- `api.naval-go.com`: backend Spring Boot

### Nginx

- `backend/deploy/nginx-navalgo-site.conf`
- `backend/deploy/nginx-navalgo-app.conf`
- `backend/deploy/nginx-navalgo.conf`

## Checklist operativo de verificacion

- Verificar `curl http://127.0.0.1:8080/actuator/health`
- Verificar `https://api.naval-go.com/actuator/health`
- Verificar `https://api.naval-go.com/swagger-ui/index.html` si Swagger esta expuesto
- Verificar build Flutter web con `API_BASE_URL` correcto
- Verificar secretos antes de levantar `docker compose`

## Limitacion honesta de esta revision

En esta pasada se ha verificado la herramienta local y la documentacion de
despliegue del repositorio, pero no se ha ejecutado un despliegue completo en
VPS desde cero dentro de esta revision.
