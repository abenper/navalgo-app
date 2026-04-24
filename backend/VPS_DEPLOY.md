# Deploy en VPS DigitalOcean (backend + HTTPS + Managed DB)

Este flujo asume Ubuntu 22.04/24.04 en tu VPS.

## 1) Que IP usar

- `104.248.22.99` es la IP publica normal del droplet.
- `143.244.206.168` es una Reserved IP (Floating IP) para failover.

Si la Reserved IP esta asignada al droplet, usa esa en DNS (recomendado para futuro).
Si no esta asignada, usa la publica normal.

Comprobacion rapida desde el VPS:

```bash
curl -4 ifconfig.me
```

La que te devuelva es la IP de salida activa del servidor.

## 2) Preparar servidor

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg nginx ufw git
```

Firewall:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

## 3) Instalar Docker + Compose plugin

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

Cierra sesion SSH y vuelve a entrar para aplicar el grupo docker.

## 4) Subir codigo

```bash
cd /opt
sudo mkdir -p navalgo
sudo chown -R $USER:$USER navalgo
cd navalgo

# Opcion A: clonar repo
# git clone <tu-repo> .

# Opcion B: subir por scp/rsync desde tu equipo
```

## 5) Configurar variables seguras

Edita `backend/docker-compose.yml` y cambia al menos:

- `POSTGRES_PASSWORD`
- `SPRING_DATASOURCE_PASSWORD`
- `APP_JWT_SECRET` (largo y aleatorio, minimo 32-64 caracteres)

## 6) Managed PostgreSQL (DigitalOcean)

1. En DigitalOcean, copia estos datos del cluster Managed DB:
   - Host
   - Port (normalmente `25060`)
   - Database (normalmente `defaultdb`)
   - User (normalmente `doadmin`)
   - Password

2. En `backend/docker-compose.yml`, configura:
   - `SPRING_DATASOURCE_URL=jdbc:postgresql://<HOST>:25060/defaultdb?sslmode=require`
   - `SPRING_DATASOURCE_USERNAME=doadmin`
   - `SPRING_DATASOURCE_PASSWORD=<PASSWORD>`

3. Importa el esquema una sola vez en Managed DB:

```bash
psql "host=<HOST> port=25060 dbname=defaultdb user=doadmin sslmode=require" -f navalgo_backend_postgres.sql
```

Si la base de produccion ya existe y solo vas a subir una nueva version del backend, aplica la migracion idempotente antes de levantar contenedores:

```bash
psql "host=<HOST> port=25060 dbname=defaultdb user=doadmin sslmode=require" -f navalgo_backend_postgres_migration.sql
```

## 7) Levantar backend

```bash
cd /opt/navalgo/backend
docker compose up -d --build
docker compose ps
docker compose logs -f backend
```

Por defecto el compose publica `8080` solo en `127.0.0.1` para que Nginx sea la unica entrada publica del backend. Si necesitas exponerlo temporalmente por IP, define `BACKEND_BIND_ADDRESS=0.0.0.0` en `.env` y vuelve a desplegar.

Prueba local en VPS:

```bash
curl http://127.0.0.1:8080/actuator/health
```

## 8) Nginx reverse proxy (dominio recomendado)

1. Crea un DNS A record:
   - `api.tudominio.com` -> IP activa del VPS (publica o reserved asignada)

2. Instala config:

```bash
sudo cp /opt/navalgo/backend/deploy/nginx-navalgo.conf /etc/nginx/sites-available/navalgo
sudo sed -i 's/api.tudominio.com/api.TU_DOMINIO_REAL.com/g' /etc/nginx/sites-available/navalgo
sudo ln -s /etc/nginx/sites-available/navalgo /etc/nginx/sites-enabled/navalgo
sudo nginx -t
sudo systemctl reload nginx
```

## 9) HTTPS con Let's Encrypt

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.TU_DOMINIO_REAL.com
```

Comprueba renovacion automatica:

```bash
systemctl status certbot.timer
```

## 10) Conectar app Flutter

Lanza tu app apuntando al backend:

```bash
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.TU_DOMINIO_REAL.com/api
```

Si aun no tienes dominio:

```bash
BACKEND_BIND_ADDRESS=0.0.0.0 docker compose up -d
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://104.248.22.99:8080/api
```

No uses `https://IP:8080`: ese puerto habla HTTP plano. Si necesitas HTTPS, publícalo por Nginx en `443`.

## 11) Verificacion final

- Swagger: `https://api.TU_DOMINIO_REAL.com/swagger-ui/index.html`
- Health: `https://api.TU_DOMINIO_REAL.com/actuator/health`
- Login backend: `POST /api/auth/login`

## 12) Recomendaciones de seguridad extra

- En Managed DB, activa "Trusted Sources" y permite solo tu VPS.
- Rotar credenciales y secreto JWT periodicamente.
- Activar backups diarios de PostgreSQL.
- Mantener servidor actualizado mensualmente.
