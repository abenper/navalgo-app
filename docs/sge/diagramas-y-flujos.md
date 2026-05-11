# Diagramas y flujos

## Diagrama de modulos

```mermaid
flowchart LR
    U[Usuarios]
    M[Movil y Web Flutter]
    B[Backend Spring Boot]
    DB[(PostgreSQL o H2)]
    S3[Spaces o S3]
    FCM[Firebase Push]
    MAIL[Resend Email]
    SITE[Landing marketing_site]
    N[Nginx]

    U --> M
    U --> SITE
    M --> N
    SITE --> N
    N --> B
    B --> DB
    B --> S3
    B --> FCM
    B --> MAIL
```

## Diagrama tecnico de backend

```mermaid
flowchart TD
    C[Controllers] --> S[Services]
    S --> R[Repositories JPA]
    R --> DB[(Base de datos)]
    S --> E[Servicios de evidencias y media]
    E --> OBJ[Storage de objetos]
    S --> NTF[NotificationService]
    NTF --> PUSH[PushNotificationService]
    PUSH --> FCM[FirebasePushGateway]
    S --> PDF[WorkOrderEvidencePdfService]
```

## Diagrama de clases simplificado de evidencias

```mermaid
classDiagram
    class WorkOrder {
      +Long id
      +String title
      +WorkOrderStatus status
      +Set~WorkOrderAttachment~ attachments
      +String signatureUrl
      +String clientSignatureUrl
      +Instant evidenceSealedAt
      +String evidenceManifestHash
      +String evidenceServerSignature
    }

    class WorkOrderAttachment {
      +Long id
      +String fileUrl
      +String fileType
      +String contentType
      +Instant uploadedAt
      +Long fileSizeBytes
      +String sha256Hex
      +String serverSignature
      +String uploadIp
      +String uploadUserAgent
    }

    class WorkOrderService
    class WorkOrderMediaService
    class WorkOrderEvidenceService
    class WorkOrderEvidencePdfService

    WorkOrder "1" --> "*" WorkOrderAttachment
    WorkOrderService --> WorkOrderMediaService
    WorkOrderService --> WorkOrderEvidenceService
    WorkOrderService --> WorkOrderEvidencePdfService
```

## Flujo principal de autenticacion

```mermaid
sequenceDiagram
    participant User as Usuario
    participant App as Flutter
    participant Auth as AuthController
    participant Service as AuthService
    participant DB as WorkerRepository

    User->>App: Introduce email y password
    App->>Auth: POST /api/auth/login
    Auth->>Service: login(request)
    Service->>DB: findByEmailIgnoreCase(...)
    DB-->>Service: Worker
    Service-->>Auth: LoginResponse + refresh cookie
    Auth-->>App: access token + datos de usuario
    App->>App: Navegacion por rol
```

## Flujo de parte con evidencia y exportacion

```mermaid
sequenceDiagram
    participant App as Flutter
    participant API as WorkOrderController
    participant Media as WorkOrderMediaService
    participant WOS as WorkOrderService
    participant Seal as WorkOrderEvidenceService
    participant PDF as WorkOrderEvidencePdfService
    participant S3 as Storage
    participant DB as PostgreSQL

    App->>API: POST /api/work-orders/{id}/attachments
    API->>Media: uploadWorkOrderAttachment(...)
    Media->>S3: Subida del binario final
    Media-->>API: UploadedAttachmentDto
    API->>WOS: addAttachment(...)
    WOS->>DB: Persistir adjunto y metadatos

    App->>API: POST /api/work-orders/{id}/sign
    API->>WOS: signWorkOrder(...)
    WOS->>Seal: sealWorkOrder(...)
    Seal-->>WOS: manifestHash + serverSignature
    WOS->>DB: Guardar sellado final

    App->>API: GET /api/work-orders/{id}/evidence-report
    API->>WOS: generateEvidenceReport(...)
    WOS->>PDF: buildReport(...)
    PDF-->>API: bytes PDF
    API-->>App: Descarga del informe
```

## Defensa para la memoria

Los diagramas muestran que el sistema no es un prototipo aislado: existe una
separacion clara entre cliente, API, persistencia, almacenamiento de objetos,
notificaciones y exportacion documental.
