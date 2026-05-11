# Entradas, salidas y servicios externos

## Entradas y salidas usadas

- Entrada de formularios: login, fichaje, ausencias, creacion y firma de
  partes.
- Entrada multimedia: imagenes, firma y video para evidencias de trabajo.
- Entrada de geolocalizacion: fichajes y adjuntos con contexto de ubicacion.
- Salida HTTP: consumo de la API del backend para persistir datos.
- Salida local: sesion recordada con `shared_preferences`.
- Salida documental: generacion y consumo de evidencias adjuntas.

## Librerias justificadas

- `provider`: inyeccion de dependencias y gestion reactiva del estado.
- `http`: cliente para consumir la API REST.
- `shared_preferences`: persistencia ligera de sesion y preferencias.
- `geolocator`: obtencion de posicion para fichaje y trazabilidad.
- `image_picker`: captura de imagen y video desde dispositivo.
- `signature`: captura de firma manuscrita del parte.
- `url_launcher`: apertura de enlaces o recursos externos.
- `intl`: fechas, horas y localizacion en castellano.
- `firebase_core`, `firebase_messaging`, `flutter_local_notifications`:
  soporte de notificaciones push.

## Servicios externos y responsabilidad

- Backend Spring Boot: autenticacion, partes, flota, ausencias, fichajes y
  trabajadores.
- Firebase: inicializacion y recepcion de notificaciones.
- Servicios del dispositivo: camara, almacenamiento temporal y geolocalizacion.

## Defensa para la memoria

Las librerias elegidas no se usan por comodidad sino por necesidad funcional:
estado desacoplado, consumo HTTP, persistencia local, geolocalizacion,
multimedia, firma y notificaciones. Cada dependencia cubre una responsabilidad
tecnica concreta y esta encapsulada desde servicios o utilidades para no
dispersar la logica por toda la interfaz.
