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

## ⚠️ Seguridad

- **NUNCA** subas el archivo `.env` a GitHub
- Usa secretos fuertes (mínimo 64 caracteres para JWT)
- Mantén las credenciales de PostgreSQL seguras
