# Deploy en VPS DigitalOcean

Esta guía deja montados backend, app Flutter y web comercial con un solo Nginx.

## 1. DNS

Crea estos registros apuntando a la IP activa de la VPS:

- `naval-go.com`
- `www.naval-go.com`
- `app.naval-go.com`
- `api.naval-go.com`

## 2. Preparar el servidor

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg nginx ufw git rsync
```

Firewall:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

## 3. Instalar Docker y Compose

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

Sal y vuelve a entrar en la sesión SSH para aplicar el grupo Docker.

## 4. Subir el proyecto

```bash
cd /opt
sudo mkdir -p navalgo
sudo chown -R $USER:$USER navalgo
cd navalgo

# Opción A
# git clone <tu-repo> .

# Opción B
# subir por scp o rsync
```

## 5. Preparar directorios públicos

```bash
sudo mkdir -p /var/www/naval-go-site
sudo mkdir -p /var/www/naval-go-app
sudo chown -R $USER:$USER /var/www/naval-go-site /var/www/naval-go-app
```

## 6. Configurar backend

En `backend/.env` revisa al menos:

- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `APP_JWT_SECRET`
- `APP_FRONTEND_BASE_URL=https://app.naval-go.com`
- `APP_SECURITY_CORS_ALLOWED_ORIGINS=https://app.naval-go.com,https://naval-go.com,https://www.naval-go.com`
- `APP_EMAIL_ENABLED=true`
- `APP_EMAIL_RESEND_API_KEY`

Levanta el backend:

```bash
cd /opt/navalgo/backend
docker compose up -d --build
docker compose ps
curl http://127.0.0.1:8080/actuator/health
```

## 7. Construir la app Flutter web

Desde tu máquina o desde el servidor, genera el build apuntando al backend:

```bash
flutter build web --release --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.naval-go.com/api
```

Publica la app:

```bash
rsync -av --delete build/web/ /var/www/naval-go-app/
```

## 8. Publicar la web comercial

La landing está en `marketing_site/`.

```bash
rsync -av --delete marketing_site/ /var/www/naval-go-site/
```

## 9. Configurar Nginx

Instala las plantillas del repositorio:

```bash
sudo cp /opt/navalgo/backend/deploy/nginx-navalgo-site.conf /etc/nginx/sites-available/navalgo-site
sudo cp /opt/navalgo/backend/deploy/nginx-navalgo-app.conf /etc/nginx/sites-available/navalgo-app
sudo cp /opt/navalgo/backend/deploy/nginx-navalgo.conf /etc/nginx/sites-available/navalgo-api

sudo ln -s /etc/nginx/sites-available/navalgo-site /etc/nginx/sites-enabled/navalgo-site
sudo ln -s /etc/nginx/sites-available/navalgo-app /etc/nginx/sites-enabled/navalgo-app
sudo ln -s /etc/nginx/sites-available/navalgo-api /etc/nginx/sites-enabled/navalgo-api

sudo nginx -t
sudo systemctl reload nginx
```

## 10. Activar HTTPS

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d naval-go.com -d www.naval-go.com
sudo certbot --nginx -d app.naval-go.com
sudo certbot --nginx -d api.naval-go.com
```

Comprueba la renovación:

```bash
systemctl status certbot.timer
```

## 11. Verificación final

Comprueba:

- `https://naval-go.com`
- `https://app.naval-go.com`
- `https://api.naval-go.com/actuator/health`
- `https://api.naval-go.com/swagger-ui/index.html`

## 12. Actualizaciones futuras

Cuando cambie la app:

```bash
flutter build web --release --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.naval-go.com/api
rsync -av --delete build/web/ /var/www/naval-go-app/
```

Cuando cambie la web comercial:

```bash
rsync -av --delete marketing_site/ /var/www/naval-go-site/
```

Cuando cambie el backend:

```bash
cd /opt/navalgo/backend
./deploy.sh
```
