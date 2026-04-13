# Navalgo Backend (Spring Boot)

Backend completo para NavalGO con modulos de:
- Autenticacion JWT
- Trabajadores
- Empresas
- Propietarios y embarcaciones (flota)
- Partes de trabajo
- Fichajes (clock in/out)
- Ausencias y vacaciones

## 1) Requisitos

- Java 21
- Maven 3.9+

## 2) Arranque

```bash
cd backend
mvn spring-boot:run
```

Si no tienes Maven, instala Maven o ejecuta el proyecto desde IntelliJ/STS usando el `pom.xml`.

### Arranque con PostgreSQL (recomendado)

1. Crea la base de datos vacia (ejemplo):

```sql
CREATE DATABASE navalgo;
```

2. Importa el esquema nuevo alineado con backend:

```bash
psql -h localhost -U postgres -d navalgo -f navalgo_backend_postgres.sql
```

3. Ajusta credenciales en `src/main/resources/application-postgres.yml`.

4. Arranca Spring con perfil postgres:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=postgres
```

## 3) Swagger

- http://localhost:8080/swagger-ui/index.html

## 4) Credenciales semilla

Se cargan automaticamente en arranque (`DataInitializer`):
- admin@navalgo.com / 1234 (ADMIN)
- worker@navalgo.com / 1234 (WORKER)

## 5) Endpoints principales

### Auth
- `POST /api/auth/login`

Body:
```json
{
  "email": "admin@navalgo.com",
  "password": "1234"
}
```

Respuesta:
```json
{
  "user": {
    "id": 1,
    "name": "Admin Navalgo",
    "email": "admin@navalgo.com",
    "role": "ADMIN"
  },
  "token": "..."
}
```

### Trabajadores
- `GET /api/workers`
- `POST /api/workers`
- `PATCH /api/workers/{id}/active`

### Empresas
- `GET /api/companies`
- `POST /api/companies`
- `GET /api/companies/{id}`

### Flota
- `GET /api/fleet/owners`
- `POST /api/fleet/owners`
- `GET /api/fleet/vessels?ownerId=`
- `POST /api/fleet/vessels`

### Partes de trabajo
- `GET /api/work-orders`
- `POST /api/work-orders`
- `PATCH /api/work-orders/{id}/status`

### Fichajes
- `POST /api/time-entries/clock-in`
- `POST /api/time-entries/clock-out`
- `GET /api/time-entries/worker/{workerId}`

### Ausencias / Vacaciones
- `GET /api/leave-requests?workerId=`
- `POST /api/leave-requests`
- `PATCH /api/leave-requests/{id}/status`

## 6) Conectar Flutter

Ejecuta Flutter asi para usar API real:

```bash
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://localhost:8080/api
```

En Android emulador normalmente debes usar:

```bash
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

## 7) Produccion

- Cambia `app.jwt.secret` por un secreto largo y seguro.
- Usa PostgreSQL con el perfil `postgres` y `ddl-auto: validate`.
- Activa migraciones (Flyway recomendado).
- Mueve adjuntos a S3/MinIO (ahora se guarda URL).

## 8) Hardening (VPS DigitalOcean)

Checklist recomendado para un despliegue seguro:

1. Sistema y acceso
- Actualiza paquetes: `sudo apt update; sudo apt upgrade -y`
- Crea usuario admin sin usar `root` para operar.
- Desactiva login por password y usa solo claves SSH en `sshd_config`.
- Cambia el puerto SSH si tu politica lo permite y activa `fail2ban`.

2. Firewall
- Permite solo puertos necesarios: `22`, `80`, `443`.
- No expongas `5432` (PostgreSQL) a Internet.
- Si usas UFW: `sudo ufw allow OpenSSH; sudo ufw allow 80; sudo ufw allow 443; sudo ufw enable`

3. Docker/Compose
- Define secretos con variables de entorno fuertes (minimo 32 bytes para JWT).
- Mantén contenedores con `restart: unless-stopped`.
- Evita privilegios extras (`no-new-privileges`, filesystem read-only en backend).

4. TLS y reverse proxy
- Publica el backend detras de Nginx o Traefik.
- Emite certificados con Let's Encrypt.
- Redirige HTTP -> HTTPS y aplica HSTS.

5. Seguridad de app
- Limita CORS a dominios reales de frontend en `SecurityConfig`.
- Reduce `APP_JWT_EXPIRATION_MS` (por defecto ya 1h).
- Rota el secreto JWT y credenciales de DB periodicamente.

6. Observabilidad y respaldo
- Activa logs centralizados (Loki/ELK o similar).
- Backups diarios de PostgreSQL (`pg_dump`) y pruebas de restauracion.
- Monitoriza `actuator/health` y alerta caidas.
