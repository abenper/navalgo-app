# Matriz final de evidencias DI

## Resumen rapido

Estado actual estimado para DI:

- Distribucion coherente y estetica: bien cubierta.
- Adaptacion a distintos tamanos: cubierta en codigo, pendiente de rematar con capturas.
- Pruebas incluyendo usabilidad: cubierta de forma tecnica; pendientes sesiones reales con usuarios.
- Documentacion y difusion: cubierta.
- Guia visual coherente: cubierta.

## 1. Distribucion coherente y estetica de componentes

### Evidencia

- Tema global en [navalgo_theme.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/theme/navalgo_theme.dart)
- Componentes reutilizables en [navalgo_ui.dart](/c:/Users/Aaron/Documents/navalgo-app/navalgo/lib/widgets/navalgo_ui.dart)
- Shells por rol y estructura visual consistente.

### Como defenderlo

La interfaz utiliza una guia visual propia con paneles, chips, tarjetas y menús persistentes, priorizando legibilidad y accion rapida.

## 2. Adaptacion a todo tipo de pantallas

### Evidencia

- Auditoria en [responsive-auditoria.md](./responsive-auditoria.md)
- Uso de `LayoutBuilder`, `MediaQuery`, `Wrap`, `NavigationRail`, `Drawer` y `NavigationBar` en las pantallas principales.

### Falta para el 4 de 4

- Capturas reales en movil, tablet y web.

## 3. Pruebas incluyendo usabilidad

### Evidencia

- Pruebas tecnicas en [pruebas-tecnicas.md](./pruebas-tecnicas.md)
- Protocolo de usuarios en [usabilidad.md](./usabilidad.md)
- Tests Flutter de login, fichaje, partes y firma.

### Falta para el 4 de 4

- Completar tabla con 3 a 5 usuarios reales y 3 a 5 incidencias o mejoras.

## 4. Documentacion y contenido de difusion

### Evidencia

- Manual de usuario en [manual-usuario.md](./manual-usuario.md)
- Landing comercial en [difusion.md](./difusion.md)

### Como defenderlo

Existe un manual de uso y un medio de difusion claro alineado con el producto.

## 5. Guia visual del sistema objetivo o guia propia coherente

### Evidencia

- [guia-visual.md](./guia-visual.md)
- Tema y componentes compartidos entre app y landing.

### Como defenderlo

Se ha definido una guia propia consistente en color, tipografia, componentes y tono visual, adecuada a un contexto naval profesional.

## 6. Textos y acabados visuales

### Evidencia

- Correccion de cadenas con codificacion rota en `partes_screen.dart`.
- Checklist de revision previa en [responsive-auditoria.md](./responsive-auditoria.md)

### Falta para cerrar

- Revisar visualmente las pantallas finales antes de capturar.

## 7. Frase breve para la memoria

> NavalGO cumple los criterios principales de Desarrollo de Interfaces gracias a una interfaz coherente y adaptable a movil, tablet y escritorio, una guia visual propia consistente, documentacion de uso, una landing comercial de apoyo y pruebas tecnicas sobre los flujos mas importantes del producto.
