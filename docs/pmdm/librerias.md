# Librerias usadas y justificacion

## Flutter y estado

| Libreria | Uso principal | Justificacion |
| --- | --- | --- |
| `provider` | Inyeccion de dependencias y estado | Ligera, clara y suficiente para una app de modulos separados |
| `shared_preferences` | Persistencia de sesion y recordatorio de correo | Permite restaurar sesion y mejorar UX |
| `intl` | Formato regional de fechas y textos | Facilita presentacion coherente |
| `google_fonts` | Tipografia | Refuerza identidad visual |

## Red y API

| Libreria | Uso principal | Justificacion |
| --- | --- | --- |
| `http` | Consumo de API REST | Cliente simple y controlado para web y movil |
| `http_parser` | Tipos MIME en multipart | Necesaria para adjuntos y firmas |

## Movil y multimedia

| Libreria | Uso principal | Justificacion |
| --- | --- | --- |
| `geolocator` | Geolocalizacion puntual en fichaje | Cumple requisito funcional de registrar ubicacion al inicio |
| `image_picker` | Seleccion de imagenes y evidencias | Permite adjuntar material desde el dispositivo |
| `signature` | Firma manuscrita | Necesaria para cierre de partes y firma de cliente |
| `file_picker` | Seleccion de archivos | Facilita subir adjuntos y PDFs |
| `video_player` | Reproduccion de video | Soporta evidencias multimedia |
| `crop_your_image` | Recorte de foto de perfil | Mejora la gestion visual del usuario |

## Firebase y notificaciones

| Libreria | Uso principal | Justificacion |
| --- | --- | --- |
| `firebase_core` | Bootstrap de Firebase | Base para mensajeria push |
| `firebase_messaging` | Notificaciones push | Permite avisos operativos |
| `flutter_local_notifications` | Notificaciones locales | Complementa la recepcion y presentacion |

## Enlaces y utilidades

| Libreria | Uso principal | Justificacion |
| --- | --- | --- |
| `url_launcher` | Apertura de enlaces externos | Soporta PDFs, enlaces y recursos web |
| `cupertino_icons` | Iconografia iOS | Cobertura visual multiplataforma |

## Relacion con PMDM

- Hay uso real de librerias de servicios web, multimedia, base de datos remota y notificaciones.
- Las librerias no estan de adorno: cada una responde a un caso de uso funcional.
- La integracion se apoya en servicios cliente desacoplados, lo que mejora mantenimiento y pruebas.
