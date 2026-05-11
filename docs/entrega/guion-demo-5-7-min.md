# Guion de Demo 5-7 Min

## Objetivo

Demostrar que NavalGO resuelve una operativa real de taller naval con login, control diario, fichaje, gestion funcional, firma y evidencia tecnica.

## Guion recomendado

### 0:00 - 0:40 Problema

Texto sugerido:

> NavalGO nace para centralizar una operativa que normalmente esta dispersa entre llamadas, WhatsApp, partes en papel, fichajes sueltos y evidencias mal trazadas. La idea es unificar acceso, trabajo diario, firma y trazabilidad en una sola plataforma.

### 0:40 - 1:15 Login

- Mostrar [Login-Desktop.png](./capturas/Login-Desktop.png) o entrar en vivo.
- Comentar que el acceso esta unificado por roles.
- Si entras en vivo, iniciar sesion como admin.

Texto sugerido:

> El acceso se hace con autenticacion centralizada. Desde aqui cada perfil entra a la misma plataforma, pero ve modulos y acciones segun su rol.

### 1:15 - 2:00 Dashboard

- Mostrar dashboard desktop o mobile.
- Ensenar panel, contadores y lectura rapida de operativa.

Texto sugerido:

> El panel resume el estado del dia: partes, urgencias, personal activo y ausencias. La idea es que un responsable vea la situacion operativa en segundos.

### 2:00 - 2:45 Fichaje

- Mostrar [Fichaje-Desktop.png](./capturas/Fichaje-Desktop.png) o [Fichaje-Mobile.png](./capturas/Fichaje-Mobile.png).
- Explicar inicio de turno, resumen del dia e historico reciente.

Texto sugerido:

> El modulo de fichaje registra la jornada, resume el tiempo acumulado y conserva historico reciente. Ademas, se integra con notificaciones y automatismos de cierre o recordatorio.

### 2:45 - 3:30 Flota

- Mostrar [Cliente-Desktop.png](./capturas/Cliente-Desktop.png) o la version mobile.
- Explicar alta de propietario y organizacion de embarcaciones.

Texto sugerido:

> Aqui se gestiona la parte de negocio: propietarios y embarcaciones. Hemos cuidado formularios claros y validaciones distintas segun si el propietario es particular o empresa.

### 3:30 - 4:45 Partes y firma

- Abrir un parte real.
- Mostrar checklist, horas o estado del parte.
- Abrir el flujo de firma.

Texto sugerido:

> El parte concentra el trabajo tecnico: horas, checklist, materiales, multimedia y cierre. Cuando procede, el operario o el cliente pueden firmar directamente sobre la app.

### 4:45 - 5:40 Evidencia y trazabilidad

- Mostrar exportacion `evidence-report` o respuesta API.
- Si puedes, ensenar tambien el PDF de evidencia.

Texto sugerido:

> Una vez firmado, el sistema conserva evidencias y puede exportar un informe tecnico. Esto permite justificar la operativa y reforzar la trazabilidad del servicio.

### 5:40 - 6:20 Ausencias

- Abrir la pantalla de ausencias.
- Mostrar calendario o solicitudes.

Texto sugerido:

> Las ausencias se gestionan desde una vista clara, con estados y lectura rapida para que no se mezclen con el resto de la operativa diaria.

### 6:20 - 7:00 Cierre tecnico

- Mencionar backend, pruebas y seguridad.

Texto sugerido:

> A nivel tecnico, la solucion combina Flutter en frontend y Spring Boot en backend, con pruebas automatizadas, control de acceso por roles, firma, exportables y limpieza programada de datos tecnicos no criticos.

## Plan B si falla internet o la demo en vivo

- Usar las capturas de `docs/entrega/capturas/`.
- Enseniar la documentacion de `docs/pmdm`, `docs/di`, `docs/ada` y `docs/sge`.
- Cerrar con `mvn test`, `flutter test` y `flutter analyze` como evidencia de estabilidad.

## Consejo de ritmo

- No expliques cada boton.
- Cuenta una historia de uso real.
- Si algo tarda, habla del valor funcional mientras carga.
- Cierra siempre con trazabilidad y pruebas, porque eso eleva mucho la defensa.
