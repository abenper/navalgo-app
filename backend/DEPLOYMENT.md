# Deployment en VPS

## Arquitectura recomendada

Usa el mismo Nginx de la VPS para servir tres entradas distintas:

- `https://naval-go.com`: web comercial estática
- `https://app.naval-go.com`: app Flutter web
- `https://api.naval-go.com`: backend Spring Boot

Los enlaces de invitación, reseteo de contraseña y verificación de cuenta deben apuntar a `app.naval-go.com`, por eso el backend ya queda preparado con ese valor por defecto.

## Primera vez

```bash
git clone https://github.com/abenper/navalgo-app.git
cd navalgo-app/backend
cp .env.example .env
openssl rand -base64 48
```

Edita `.env` y revisa al menos:

- `APP_JWT_SECRET`
- `SPRING_DATASOURCE_PASSWORD`
- `APP_FRONTEND_BASE_URL=https://app.naval-go.com`
- `APP_SECURITY_CORS_ALLOWED_ORIGINS=https://app.naval-go.com,https://naval-go.com,https://www.naval-go.com`
- `APP_EMAIL_ENABLED=true`
- `APP_EMAIL_RESEND_API_KEY`

Después despliega el backend:

```bash
chmod +x deploy.sh
./deploy.sh
```

## Despliegues posteriores

```bash
cd /ruta/a/navalgo-app/backend
./deploy.sh
```

El script:

- descarga cambios
- limpia artefactos previos
- valida secretos
- reconstruye y levanta el contenedor

## Comandos útiles

```bash
docker compose logs -f backend
docker compose restart backend
docker compose down
curl http://127.0.0.1:8080/actuator/health
```

## Notas

- En producción, `docker-compose.yml` expone `8080` solo en `127.0.0.1`.
- Si necesitas abrirlo temporalmente por IP, define `BACKEND_BIND_ADDRESS=0.0.0.0` en `.env`.
- Si ves `Invalid character found in method name [0x16 0x03 ...]`, suele ser tráfico HTTPS entrando por error al puerto HTTP `8080`.

## Seguridad

- No subas `.env` al repositorio.
- Usa un secreto JWT largo y aleatorio.
- Mantén PostgreSQL restringido a la VPS y con backups.
