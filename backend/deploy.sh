#!/bin/bash
set -e

echo "🔄 Forzando actualización desde GitHub..."
cd "$(dirname "$0")"

# Guarda cambios locales temporalmente (si hay)
git stash

# Fuerza descarga limpia del repositorio
git fetch --all
git reset --hard origin/main
git clean -fd

# Limpia compilaciones anteriores
echo "🧹 Limpiando artefactos anteriores..."
rm -rf target/
docker-compose down -v

# Verifica/genera archivo .env con secretos
if [ ! -f .env ]; then
  echo "⚠️  No existe .env, generando secretos..."
  
  # Genera JWT secret fuerte (64 caracteres base64)
  JWT_SECRET=$(openssl rand -base64 48)
  
  cat > .env << EOF
# Secretos generados automáticamente - NO SUBIR A GIT
APP_JWT_SECRET=${JWT_SECRET}
APP_JWT_EXPIRATION_MS=3600000

# PostgreSQL - ACTUALIZA CON TUS CREDENCIALES REALES
SPRING_DATASOURCE_URL=jdbc:postgresql://private-navalgo-db-do-user-33837097-0.h.db.ondigitalocean.com:25060/defaultdb?sslmode=require
SPRING_DATASOURCE_USERNAME=doadmin
SPRING_DATASOURCE_PASSWORD=CAMBIA_ESTO_POR_TU_PASSWORD_REAL
EOF

  echo "✅ Archivo .env creado. EDITA .env y actualiza SPRING_DATASOURCE_PASSWORD"
  echo "⛔ Deployment detenido - configura primero tus credenciales en .env"
  exit 1
fi

# Verifica que el secret JWT no sea el por defecto
if grep -q "change-this" .env; then
  echo "⛔ ERROR: Aún tienes secretos por defecto en .env"
  echo "Edita .env y actualiza APP_JWT_SECRET y credenciales de DB"
  exit 1
fi

echo "🐳 Construyendo y desplegando contenedor..."
docker-compose up -d --build

echo ""
echo "✅ Deployment completado!"
echo "📊 Verifica logs con: docker-compose logs -f backend"
echo "🔍 Health check: curl http://localhost:8080/api/health"
