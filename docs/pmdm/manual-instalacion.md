# Manual de instalacion

## 1. Requisitos

- Flutter SDK 3.11 o superior.
- Dart SDK compatible con el `pubspec.yaml`.
- Java 21 para el backend.
- Maven 3.9 o superior.
- PostgreSQL para entorno persistente.
- Chrome o un dispositivo Android para pruebas de la app.

## 2. Estructura del proyecto

- `lib/`: app Flutter.
- `backend/`: API Spring Boot.
- `marketing_site/`: web comercial estatica.
- `web/`: shell Flutter web.

## 3. Instalacion rapida del frontend

```bash
flutter pub get
flutter run
```

## 4. Arranque web contra backend local

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

## 5. Build web de produccion

```bash
flutter build web --release --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.naval-go.com/api
```

## 6. Arranque del backend

```bash
cd backend
mvn spring-boot:run
```

## 7. PostgreSQL para desarrollo persistente

Crear base de datos:

```sql
CREATE DATABASE navalgo;
```

Aplicar esquema:

```bash
psql -h localhost -U postgres -d navalgo -f navalgo_backend_postgres.sql
```

Si la base ya existe y solo hay que migrar:

```bash
psql -h localhost -U postgres -d navalgo -f navalgo_backend_postgres_migration.sql
```

## 8. Variables recomendadas del backend

```bash
APP_JWT_SECRET=un_secreto_de_al_menos_32_bytes
APP_JWT_EXPIRATION_MS=3600000
APP_JWT_REFRESH_EXPIRATION_MS=7776000000
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/navalgo
SPRING_DATASOURCE_USERNAME=navalgo
SPRING_DATASOURCE_PASSWORD=cambia_esto
```

## 9. Arranque del backend con perfil postgres

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=postgres
```

## 10. Comprobaciones tras instalar

- Abrir `http://localhost:8080/swagger-ui/index.html`.
- Verificar que `flutter analyze` no devuelve errores.
- Verificar que `flutter test` pasa.
- Abrir la app y confirmar que aparece la pantalla `Acceso a NavalGO`.

## 11. Credenciales de demo

- `admin@navalgo.com / 1234`
- `worker@navalgo.com / 1234`
- `comercial@navalgo.com / 1234` en modo mock.
- `cliente@navalgo.com / 1234` en modo mock.

## 12. Despliegue recomendado

- `naval-go.com`: marketing site.
- `app.naval-go.com`: Flutter web.
- `api.naval-go.com`: backend Spring Boot detras de Nginx y TLS.

Las guias de despliegue ampliadas estan en:

- `backend/DEPLOYMENT.md`
- `backend/VPS_DEPLOY.md`
