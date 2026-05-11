# ORM, JPA y transacciones

## ORM usado

El backend usa Spring Data JPA con Hibernate como ORM. Esto permite mapear
tablas relacionales a clases Java y trabajar con entidades de dominio en lugar
de SQL manual para la mayoria de operaciones.

## Donde se aprovecha JPA

- Entidades anotadas con `@Entity` como `Worker`, `Owner`, `Vessel`,
  `WorkOrder`, `WorkOrderAttachment`, `LeaveRequestEntity`, `TimeEntry`,
  `Budget` o `NotificationEntity`.
- Repositorios que extienden `JpaRepository` para CRUD automatico.
- Relaciones `@ManyToOne`, `@OneToMany`, `@ManyToMany` y `@OneToOne`.
- `cascade = CascadeType.ALL` y `orphanRemoval = true` en agregados como
  adjuntos, checklist y horas de motor del parte.
- Consultas derivadas por nombre de metodo y algunas consultas personalizadas
  con `@Query`.

## Relaciones JPA destacables

- `WorkOrder` -> `Owner` y `Vessel` con `ManyToOne`.
- `WorkOrder` -> `assignedWorkers` con `ManyToMany`.
- `WorkOrder` -> `attachments` y `engineHourLogs` con `OneToMany`.
- `WorkOrder` -> `materialChecklist` con `OneToOne`.
- `WorkOrderAttachment` -> `uploadedByWorker` con `ManyToOne`.
- `LeaveRequestEntity` -> `Worker` con `ManyToOne`.
- `TimeEntry` -> `Worker` con `ManyToOne`.
- `Owner` -> `Company` con `ManyToOne`.

## Transacciones

Se usan `@Transactional(readOnly = true)` para lectura y `@Transactional` para
operaciones de escritura o de negocio que afectan a varias entidades.

### Casos donde aporta valor real

- `FleetController.deleteOwner(...)`: decide entre borrado fisico y archivado
  segun historial en presupuestos, partes y embarcaciones relacionadas.
- `WorkOrderService`: crea y actualiza partes con trabajadores, checklist,
  adjuntos, sellado y firma dentro de operaciones coordinadas.
- `BudgetService`: crea, reemite y actualiza presupuestos registrando ademas
  eventos historicos.
- `LeaveRequestService` y `TimeTrackingService`: aplican validaciones de negocio
  y persisten cambios coherentes sobre ausencias y fichajes.

## Ventajas del ORM en este proyecto

- Reduce SQL repetitivo para CRUD comun.
- Hace mas legibles las relaciones del dominio.
- Facilita reutilizar entidades, DTO y repositorios.
- Permite evolucionar el modelo con menos friccion en servicios y controladores.

## Inconvenientes o limites a reconocer

- Hay que controlar bien el `fetch` y las relaciones para evitar sobrecarga o
  lecturas innecesarias.
- Algunas consultas complejas terminan necesitando metodos mas especificos o
  consultas personalizadas.
- El ORM no sustituye la necesidad de pensar el esquema ni la integridad.

## Defensa para la memoria

El uso de JPA no se limita a un CRUD simple: se aprovecha para mapear el
dominio naval, resolver relaciones entre trabajadores, partes, clientes y
embarcaciones, y coordinar operaciones transaccionales que afectan a varias
tablas y entidades en una sola unidad logica.
