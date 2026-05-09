# NavalGO

NavalGO es una plataforma de gestión naval para partes de trabajo, flota, evidencias, fichajes, presupuestos y cierre firmado de operativas.

## Estructura

- `lib/`: app Flutter
- `backend/`: API Spring Boot y despliegue
- `marketing_site/`: web comercial estática para `naval-go.com`
- `web/`: shell web de Flutter para `app.naval-go.com`

## Arquitectura recomendada

- `naval-go.com`: web comercial
- `app.naval-go.com`: app Flutter web
- `api.naval-go.com`: backend

## Despliegue

La guía principal está en:

- `backend/DEPLOYMENT.md`
- `backend/VPS_DEPLOY.md`

## Desarrollo Flutter

```bash
flutter pub get
flutter run
```

## Build web

```bash
flutter build web --release --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.naval-go.com/api
```
