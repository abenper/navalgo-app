# Pruebas funcionales y evidencias

## 1. Pruebas automatizadas disponibles

### Flutter

Comandos:

```bash
flutter analyze
flutter test
```

Cobertura funcional automatizada introducida en este proyecto:

- Login: parseo y mapeo correcto de la sesion.
- Fichaje: peticion de `clock-in` con payload correcto.
- Partes: creacion de parte con serializacion correcta.
- Firma: envio multipart de firma con adjuntos de prueba.

## 2. Evidencias manuales que deben adjuntarse a la entrega

Anadir una captura por cada bloque:

1. Login.
2. Dashboard de administrador.
3. Dashboard de trabajador.
4. Fichaje con jornada iniciada.
5. Listado o detalle de partes.
6. Flujo de firma del parte.
7. Flota con propietarios o embarcaciones.
8. Presupuestos en area comercial o cliente.
9. Swagger o base de datos mostrando persistencia real.

## 3. Guion de demostracion recomendado

### Escenario A: login por rol

1. Entrar como administrador.
2. Mostrar redireccion a shell de admin.
3. Cerrar sesion.
4. Entrar como trabajador.
5. Mostrar shell de trabajador.

### Escenario B: fichaje

1. Abrir `Fichaje`.
2. Elegir `Taller` o `Viaje`.
3. Autorizar ubicacion puntual.
4. Iniciar jornada.
5. Cerrar jornada.
6. Mostrar el historico actualizado.

### Escenario C: parte

1. Crear un parte desde admin.
2. Asignar operario.
3. Asociar embarcacion.
4. Adjuntar evidencia.
5. Mostrar el parte desde el rol trabajador.

### Escenario D: firma

1. Abrir detalle del parte.
2. Firmar como trabajador.
3. Firmar como cliente si procede.
4. Descargar o abrir acta de integridad en web.

## 4. Criterios de aceptacion para PMDM

- La app arranca sin errores.
- La navegacion principal depende del rol.
- El boton atras no rompe la sesion ni deja rutas inconsistentes.
- Los formularios muestran validaciones basicas.
- Se usan librerias para red, multimedia, firma y geolocalizacion.
- Existe documentacion de instalacion y de uso.

## 5. Material recomendado para la defensa

- Capturas limpias.
- Video de 3 a 5 minutos.
- Resultado de `flutter analyze`.
- Resultado de `flutter test`.
- Muestra de Swagger o datos persistidos.
