# Capturas de Entrega

## Criterio general

Las capturas finales deben demostrar:

- acceso y primer uso;
- vision global del sistema;
- operativa diaria;
- gestion funcional de negocio;
- firma y evidencia;
- respaldo tecnico en API o base de datos.

## Capturas ya listas

| Pantalla | Desktop | Mobile | Estado |
| --- | --- | --- | --- |
| Login | `capturas/Login-Desktop.png` | `capturas/Login-Mobile.png` | Lista |
| Dashboard | `capturas/Dashboard-Desktop.png` | `capturas/Dashboard-Mobile.png` | Lista |
| Fichaje | `capturas/Fichaje-Desktop.png` | `capturas/Fichaje-Mobile.png` | Lista |
| Flota / nuevo propietario | `capturas/Cliente-Desktop.png` | `capturas/Cliente-Mobile.png` | Lista |

## Capturas pendientes

| Bloque | Captura recomendada | Que debe verse | Prioridad |
| --- | --- | --- | --- |
| Partes | Listado de partes o detalle de un parte abierto | Estado, horas, operario, CTA visible | Alta |
| Firma | Dialogo o panel de firma del parte | Lienzo de firma, accion de guardar, estado del parte | Alta |
| Ausencias | Calendario o listado de ausencias | Solicitudes, estados y lectura clara | Alta |
| Evidencia API | Exportacion `GET /api/work-orders/{id}/evidence-report` o respuesta de firma | URL o respuesta real del backend | Alta |
| Evidencia BD | Tabla o fila relacionada con parte firmado / adjunto / notificacion | Persistencia real de datos | Media |

## Orden recomendado para la memoria o diapositivas

1. Login desktop.
2. Login mobile.
3. Dashboard desktop.
4. Dashboard mobile.
5. Fichaje desktop.
6. Fichaje mobile.
7. Flota desktop.
8. Flota mobile.
9. Parte abierto.
10. Firma del parte.
11. Ausencias.
12. Evidencia API.
13. Evidencia BD.

## Instrucciones para las capturas que faltan

### Partes

- Abrir un parte con datos visibles pero limpios.
- Mostrar cabecera, estado, operario asignado y una zona funcional del formulario.
- Evitar capturas vacias si puedes cargar un ejemplo real.

### Firma

- Abrir el flujo de firma en [partes_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/admin/partes_screen.dart).
- Mostrar el lienzo y el boton de guardado.
- Si el parte ya esta firmado, hacer tambien una captura donde se vea el estado firmado.

### Ausencias

- Abrir [ausencias_screen.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/screens/worker/ausencias_screen.dart).
- Priorizar la vista con calendario, estado y tarjetas o eventos visibles.
- Comprobar antes que no haya textos cortados ni huecos raros.

### Evidencia API

- Usar el endpoint `GET /api/work-orders/{id}/evidence-report`.
- Alternativa valida: captura del `POST /api/work-orders/{id}/client-signature` o `POST /api/work-orders/{id}/sign` en Swagger/Postman mostrando respuesta correcta.
- Si puedes, acompana la captura con una segunda donde se vea el PDF exportado abierto.

### Evidencia BD

- Mostrar una tabla o fila asociada a un parte real.
- Opciones utiles:
  - `work_orders`
  - `work_order_attachments`
  - `notifications`
  - `time_entries`
- Si haces solo una captura de BD, prioriza `work_orders` o `work_order_attachments`.

## Checklist visual antes de exportar

- Sin overlays de error ni toasts a medias.
- Sin textos con acentos rotos.
- Sin barras del sistema tapando botones clave.
- Sin datos de prueba absurdos o incoherentes.
- Con la accion principal visible en cada pantalla.
- Con nombres de seccion legibles a primera vista.

## Nota sobre las capturas actuales

Las capturas de login, dashboard, fichaje y flota ya estan copiadas en `docs/entrega/capturas/` para que no dependas del escritorio al preparar la memoria o las diapositivas.
