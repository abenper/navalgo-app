#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔄 Actualizando desde GitHub..."
git fetch --all
git reset --hard origin/main

echo "🐳 Reconstruyendo contenedor..."
docker compose down
docker compose up -d --build

echo "✅ Hecho. Logs: docker compose logs -f backend"
