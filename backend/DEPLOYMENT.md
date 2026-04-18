# 🚀 Deployment al Servidor (VPS)

## Primera vez (Setup inicial)

```bash
# 1. Clona el repositorio
git clone https://github.com/abenper/navalgo-app.git
cd navalgo-app/backend

# 2. Copia el archivo de ejemplo
cp .env.example .env

# 3. Genera un secret JWT fuerte
openssl rand -base64 48

# 4. Edita .env y actualiza:
nano .env
#   - APP_JWT_SECRET (pega el secret generado arriba)
#   - SPRING_DATASOURCE_PASSWORD (password real de PostgreSQL)

# 5. Da permisos de ejecución al script
chmod +x deploy.sh

# 6. Despliega
./deploy.sh
```

## Deployments posteriores (actualizaciones)

```bash
# Ejecuta el script que hace todo automáticamente
cd /ruta/a/navalgo-app/backend
./deploy.sh
```

El script `deploy.sh` hace automáticamente:
- ✅ Fuerza descarga limpia desde GitHub
- ✅ Limpia artefactos de compilación anterior
- ✅ Valida que existan secretos configurados
- ✅ Reconstruye y despliega el contenedor Docker

En produccion, el `docker-compose.yml` deja el puerto `8080` ligado a `127.0.0.1` por defecto para que la entrada publica sea Nginx (`80/443`).
Si necesitas acceso directo temporal por `IP:8080`, define `BACKEND_BIND_ADDRESS=0.0.0.0` en `.env` antes de desplegar.

## Comandos útiles

```bash
# Ver logs del backend
docker compose logs -f backend

# Reiniciar el servicio
docker compose restart backend

# Detener
docker compose down

# Verificar que está funcionando
curl http://localhost:8080/api/health
```

Si en los logs ves `Invalid character found in method name [0x16 0x03 ...]`, no suele ser una caida del backend: normalmente es trafico HTTPS entrando por error al puerto HTTP `8080`.

## ⚠️ Seguridad

- **NUNCA** subas el archivo `.env` a GitHub
- Usa secretos fuertes (mínimo 64 caracteres para JWT)
- Mantén las credenciales de PostgreSQL seguras
