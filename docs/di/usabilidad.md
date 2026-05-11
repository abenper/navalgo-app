# Pruebas de usabilidad

## Estado

Todavia falta completar sesiones con 3 a 5 usuarios reales. Este documento deja el protocolo y una estructura lista para rellenar con resultados.

Si quieres ejecutar la sesion ya, usa directamente:

- [Sesion guiada de usabilidad](./usabilidad-sesion-guiada.md)

## Objetivo

Validar si los flujos principales son claros para perfiles no tecnicos:

- iniciar sesion;
- fichar;
- localizar un parte;
- firmar o revisar una evidencia;
- abrir un presupuesto o consultar flota.

## Participantes recomendados

- 1 administrativo o perfil de oficina.
- 1 operario o perfil tecnico.
- 1 comercial o persona cercana a gestion de cliente.
- opcional 1 cliente de prueba.
- opcional 1 usuario sin contexto previo para medir intuicion.

## Guion de tareas

1. Iniciar sesion con unas credenciales facilitadas.
2. Localizar la pantalla de fichaje.
3. Iniciar una jornada y encontrar donde se cierra.
4. Abrir un parte o presupuesto.
5. Encontrar la cuenta o privacidad.
6. Volver atras sin perderse.

## Metricas sencillas

- Tiempo hasta completar la tarea.
- Numero de dudas o bloqueos.
- Numero de errores.
- Valoracion subjetiva de 1 a 5.

## Plantilla para rellenar

| Usuario | Perfil | Tarea | Resultado | Duda detectada | Mejora propuesta |
| --- | --- | --- | --- | --- | --- |
| U1 | Oficina | Login y panel | Pendiente | Pendiente | Pendiente |
| U2 | Operario | Fichaje y parte | Pendiente | Pendiente | Pendiente |
| U3 | Comercial o cliente | Presupuesto o cuenta | Pendiente | Pendiente | Pendiente |

## Version minima valida para entregar

Si vas justo de tiempo, completa al menos:

- 3 usuarios;
- 1 tarea principal por usuario;
- 1 problema real por usuario;
- 1 mejora propuesta por usuario.

Con eso ya puedes justificar que hubo prueba de usabilidad real y no solo inspeccion tecnica.

## Hallazgos de inspeccion experta ya detectados

- Se detectaron textos con codificacion rota en `partes_screen.dart` y se han corregido antes de capturar.
- Conviene revisar la densidad visual de los listados mas largos antes de grabar el video final.
- Conviene comprobar manualmente que la navegacion de comercial y cliente sigue siendo intuitiva en movil con `Drawer`.

## Mejoras que puedes documentar si aparecen en la prueba

- Renombrar botones ambiguos.
- Subir contraste de textos secundarios.
- Acortar mensajes demasiado largos en modales.
- Reordenar acciones principales para reducir taps.

## Como presentarlo en la memoria

Basta con una tabla breve de usuarios, 3 a 5 incidencias reales y 3 a 5 mejoras aplicadas o planificadas. No hace falta un estudio largo; hace falta que se vea que hubo validacion con personas.
