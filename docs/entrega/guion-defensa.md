# Guion de Defensa

## Estructura clara

La defensa puede seguir este orden:

1. Problema.
2. Solucion.
3. Arquitectura.
4. Pruebas.
5. Seguridad y trazabilidad.
6. Demo.
7. Cierre.

## Discurso base

### 1. Problema

> En un entorno naval o de taller hay mucha informacion repartida: clientes, embarcaciones, partes, ausencias, fichajes, firmas y evidencias. Cuando esto no esta integrado, se pierde tiempo, trazabilidad y control operativo.

### 2. Solucion

> NavalGO unifica esa operativa en una sola plataforma. Permite iniciar sesion segun rol, revisar el estado del dia, registrar jornada, gestionar flota, trabajar con partes y cerrar trabajos con firma y evidencias.

### 3. Arquitectura

> La aplicacion cliente esta desarrollada en Flutter con separacion por capas: pantallas, viewmodels, servicios y modelos. El backend esta construido con Spring Boot, API REST, JPA y base de datos relacional. Asi separamos interfaz, logica y persistencia.

Apoyo documental:

- [docs/pmdm/arquitectura-flutter.md](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/pmdm/arquitectura-flutter.md)
- [docs/hlc/poo-y-capas.md](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/hlc/poo-y-capas.md)
- [docs/ada/orm-jpa-y-transacciones.md](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/ada/orm-jpa-y-transacciones.md)

### 4. Pruebas

> Se han documentado pruebas funcionales, pruebas tecnicas y tests automatizados sobre flujos criticos como login, fichaje, partes y firma. Ademas, se ha revisado la adaptacion responsive en movil y escritorio.

Apoyo documental:

- [docs/pmdm/pruebas-funcionales.md](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/pmdm/pruebas-funcionales.md)
- [docs/di/pruebas-tecnicas.md](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/di/pruebas-tecnicas.md)
- [docs/di/responsive-auditoria.md](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/di/responsive-auditoria.md)

### 5. Seguridad y trazabilidad

> La plataforma incorpora autenticacion, control de acceso por rol, validaciones de backend, manejo de firmas y evidencias, exportacion de acta PDF y limpieza programada de registros tecnicos no criticos para mantener la base de datos saneada.

Apoyo documental:

- [docs/sge/autoria-trazabilidad.md](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/sge/autoria-trazabilidad.md)
- [docs/sge/consultas-accesos-y-exportacion.md](/c:/Users/Aaron/Documents/navalgo-app/navalgo/docs/sge/consultas-accesos-y-exportacion.md)
- [SecurityConfig.java](/c:/Users/Aaron/Documents/navalgo-app/navalgo/backend/src/main/java/com/navalgo/backend/security/SecurityConfig.java)

### 6. Demo

> Durante la demo voy a seguir un flujo real: login, dashboard, fichaje, flota, partes, firma y evidencia.

Apoyo:

- [guion-demo-5-7-min.md](./guion-demo-5-7-min.md)

### 7. Cierre

> El valor del proyecto no es solo que funcione, sino que conecta operativa diaria, control tecnico y trazabilidad en una solucion unica y defendible tanto a nivel funcional como tecnico.

## Frases cortas por si te bloqueas

- “He priorizado trazabilidad real, no solo interfaz.”
- “Cada modulo responde a una necesidad operativa concreta.”
- “La separacion por capas facilita mantenimiento y pruebas.”
- “No me he quedado en CRUD; he incluido firma, evidencia y exportacion.”
- “La documentacion enlaza cada criterio con una evidencia concreta del repositorio.”

## Preguntas probables y respuesta breve

### Por que Flutter y Spring Boot

> Porque necesitaba una interfaz multiplataforma consistente y un backend robusto con buen soporte para API REST, seguridad, JPA y transacciones.

### Donde se ve la persistencia real

> En la base de datos relacional y en los exportables del backend, especialmente partes, fichajes, ausencias, presupuestos y evidencia PDF.

### Como justificas la seguridad

> Hay autenticacion, control por roles, validaciones, manejo de tokens, limpieza de registros tecnicos y rutas protegidas en backend.

### Que pruebas has realizado

> Pruebas funcionales guiadas, verificacion responsive y tests automatizados sobre los flujos mas criticos.
