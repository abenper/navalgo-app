# Limpieza y mantenibilidad

## Cambios aplicados

- Se ha eliminado `lib/screens/admin/dashboard_screen.dart` porque era una
  pantalla legacy sin referencias desde la navegacion real.
- Se ha eliminado `lib/screens/admin/mapa_screen.dart` porque era una pantalla
  MVP no integrada en el flujo actual.
- Se ha retirado la implementacion antigua de ausencias basada en estado local
  y se ha dejado una unica pantalla funcional en
  `lib/screens/worker/ausencias_screen.dart`.
- Se han actualizado los shells de admin, worker y comercial para importar una
  unica pantalla de ausencias.

## Mejora conseguida

- Se reduce codigo muerto y confusion durante el mantenimiento.
- Se evita tener dos pantallas distintas con la misma clase `AusenciasScreen`.
- Los nombres pasan a reflejar mejor el comportamiento real de la app.
- El flujo de navegacion queda alineado con el codigo realmente entregado.

## Defensa para la memoria

Se ha realizado una limpieza de pantallas legacy y de prototipos no integrados
para dejar solo los modulos usados por la aplicacion final. Esta decision mejora
la mantenibilidad, evita ambiguedades en nombres y facilita la evolucion del
proyecto sin arrastrar codigo muerto.
