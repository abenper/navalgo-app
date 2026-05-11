# Version Estable

## Objetivo

Llegar a la entrega con una version cerrada, comprobada y sin cambios de ultima hora.

## Congelacion recomendada

### 1. Verificacion tecnica

Ejecutar y anotar resultado:

```bash
flutter analyze
flutter test
cd backend
mvn test
cd ..
flutter build web --release
```

### 2. Verificacion funcional minima

- Login correcto.
- Dashboard carga.
- Fichaje abre y muestra historico.
- Flota permite abrir el alta de propietario.
- Partes abre un detalle real.
- Firma abre el lienzo o muestra un parte firmado.
- Ausencias carga sin errores.
- Exportacion de evidencia responde.

### 3. Verificacion visual minima

- Todas las capturas finales estan hechas.
- No hay textos con acentos rotos.
- No hay pantallas vacias por datos mal cargados.
- No hay botones tapados en movil.

### 4. Paquete de entrega

- Documentacion `docs/pmdm`, `docs/di`, `docs/hlc`, `docs/ada`, `docs/sge`.
- Carpeta [docs/entrega](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/entrega/README.md).
- Capturas copiadas en `docs/entrega/capturas/`.
- Demo ensayada una vez completa con cronometro.

## Regla final

Cuando todo este validado:

- no cambies diseno ni textos;
- no metas nuevas funcionalidades;
- no toques validaciones si no hay fallo real;
- si detectas algo menor, documentalo y no rompas la version estable.

## Recomendacion practica

- Guarda una copia comprimida del proyecto ya verificado.
- Si usas Git para la entrega, deja identificado el punto final con una rama o tag local.
- Entrega siempre la build y la documentacion de la misma revision.

## Estado actual sugerido

Checklist para rellenar el dia final:

| Elemento | Estado | Observaciones |
| --- | --- | --- |
| `flutter analyze` | Pendiente |  |
| `flutter test` | Pendiente |  |
| `backend/mvn test` | Pendiente |  |
| `flutter build web --release` | Pendiente |  |
| Capturas completas | Pendiente |  |
| Demo ensayada | Pendiente |  |
| Defensa ensayada | Pendiente |  |
| Copia congelada creada | Pendiente |  |
