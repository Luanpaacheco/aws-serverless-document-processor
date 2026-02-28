# 🎨 Visualização do Diagrama de Arquitetura

## 📊 Diagrama Principal (Mermaid)

O diagrama de arquitetura está embutido no [README.md](README.md) usando **Mermaid**, que o GitHub renderiza automaticamente.

### Como Visualizar

#### No GitHub

1. Acesse o repositório no GitHub
2. O README.md renderizará o diagrama automaticamente
3. Cores e ícones são aplicados automaticamente

#### Localmente (VS Code)

1. Instale a extensão **Markdown Preview Mermaid Support**
2. Abra o README.md
3. Use `Ctrl+Shift+V` para preview

#### Online (Mermaid Live Editor)

1. Acesse: https://mermaid.live/
2. Cole o código abaixo:

```mermaid
graph TB
    Client[Cliente/API REST]
    API[Express API<br/>:3000]
    SQS[Amazon SQS<br/>documents-queue]
    Lambda[AWS Lambda<br/>document-processor]
    DynamoAlunos[(DynamoDB<br/>Alunos)]
    DynamoJobs[(DynamoDB<br/>Jobs)]
    S3[Amazon S3<br/>documents-bucket]

    Client -->|POST /request-document| API
    API -->|1. Cria Job| DynamoJobs
    API -->|2. Envia mensagem| SQS
    SQS -->|3. Trigger| Lambda
    Lambda -->|4. Busca dados| DynamoAlunos
    Lambda -->|5. Gera PDF<br/>PDFKit| Lambda
    Lambda -->|6. Upload PDF| S3
    Lambda -->|7. Atualiza status| DynamoJobs
    Client -->|GET /request-document/:id| API
    API -->|8. Consulta status| DynamoJobs

    style Lambda fill:#FF9900
    style SQS fill:#FF4F8B
    style DynamoAlunos fill:#4053D6
    style DynamoJobs fill:#4053D6
    style S3 fill:#569A31
    style API fill:#68A063
```

---

## 🎯 Versão Simplificada (ASCII)

Para apresentações em terminal ou documentos plain text:

```
┌─────────────┐
│   Cliente   │
│   (HTTP)    │
└──────┬──────┘
       │ POST /request-document
       ▼
┌─────────────┐      ┌──────────────┐
│  Express    │──1──▶│  DynamoDB    │
│    API      │      │     Jobs     │
│   :3000     │      └──────────────┘
└──────┬──────┘
       │ 2. Envia mensagem
       ▼
┌─────────────┐
│   Amazon    │
│     SQS     │
│    Queue    │
└──────┬──────┘
       │ 3. Trigger
       ▼
┌─────────────┐      ┌──────────────┐
│   Lambda    │──4──▶│  DynamoDB    │
│  Processor  │      │    Alunos    │
└──────┬──────┘      └──────────────┘
       │
       │ 5. Gera PDF
       ▼
    [PDFKit]
       │
       │ 6. Upload
       ▼
┌─────────────┐
│   Amazon    │
│     S3      │
│   Bucket    │
└─────────────┘
       │
       │ 7. Update status
       ▼
┌─────────────┐
│  DynamoDB   │
│    Jobs     │
│  (COMPLETED)│
└─────────────┘
```

---

## 🔄 Diagrama de Sequência

Para visualizar o fluxo temporal:

```mermaid
sequenceDiagram
    participant C as Cliente
    participant A as API
    participant D as DynamoDB
    participant Q as SQS
    participant L as Lambda
    participant S as S3

    C->>A: POST /request-document {matricula}
    A->>D: Criar Job (pending)
    D-->>A: Job criado
    A->>Q: Enviar mensagem
    Q-->>A: Message ID
    A-->>C: {jobId, status: "pending"}

    Note over Q,L: Trigger automático
    Q->>L: Invoke com evento

    L->>D: Get Aluno (matricula)
    D-->>L: Dados do aluno

    Note over L: Gera PDF (PDFKit)

    L->>S: Upload PDF
    S-->>L: Success

    L->>D: Update Job (COMPLETED)
    D-->>L: Success

    C->>A: GET /request-document/{jobId}
    A->>D: Get Job
    D-->>A: Job data
    A-->>C: {status: "COMPLETED", pdfKey}
```

---

## 🏗️ Diagrama de Infraestrutura

### Versão Mermaid (Renderiza no GitHub)

```mermaid
graph TD
    subgraph Host["🖥️ Host Machine"]
        API[Express API<br/>Port: 3000<br/>Routes: /request-document]
    end

    subgraph Docker["🐳 Docker/LocalStack :4566"]
        subgraph Queue["📮 Message Queue"]
            SQS[Amazon SQS<br/>documents-queue<br/>batch_size: 1]
        end

        subgraph Compute["⚡ Compute"]
            Lambda[AWS Lambda<br/>document-processor<br/>Runtime: nodejs18.x<br/>Memory: 512MB<br/>Timeout: 60s]
        end

        subgraph Storage["💾 Storage Layer"]
            DynamoAlunos[(DynamoDB<br/>Alunos Table<br/>PK: matricula)]
            DynamoJobs[(DynamoDB<br/>Jobs Table<br/>PK: jobId)]
            S3[S3 Bucket<br/>documents-bucket<br/>Path: /documents/]
        end
    end

    API -->|Envia mensagens| SQS
    SQS -->|Event Source Mapping| Lambda
    Lambda -->|Lê dados| DynamoAlunos
    Lambda -->|Atualiza status| DynamoJobs
    Lambda -->|Upload PDF| S3
    API -->|Consulta status| DynamoJobs

    style Lambda fill:#FF9900,stroke:#232F3E,stroke-width:3px
    style SQS fill:#FF4F8B,stroke:#232F3E,stroke-width:2px
    style DynamoAlunos fill:#4053D6,stroke:#232F3E,stroke-width:2px
    style DynamoJobs fill:#4053D6,stroke:#232F3E,stroke-width:2px
    style S3 fill:#569A31,stroke:#232F3E,stroke-width:2px
    style API fill:#68A063,stroke:#232F3E,stroke-width:2px
    style Host fill:#f0f0f0,stroke:#333,stroke-width:2px
    style Docker fill:#e6f3ff,stroke:#0066cc,stroke-width:3px
```

### Versão ASCII (Para Terminal/Documentos)

```
┌────────────────────────────────────────────────────┐
│              Docker Host (LocalStack)              │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │           Amazon SQS                         │ │
│  │     documents-queue                          │ │
│  │     batch_size: 1                            │ │
│  └────────────┬─────────────────────────────────┘ │
│               │ Event Source Mapping              │
│               ▼                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │     AWS Lambda Function                      │ │
│  │     Name: document-processor                 │ │
│  │     Runtime: nodejs18.x                      │ │
│  │     Memory: 512MB                            │ │
│  │     Timeout: 60s                             │ │
│  │     Env: AWS_ENDPOINT, BUCKET_NAME           │ │
│  └──────────────────────────────────────────────┘ │
│               │                                    │
│       ┌───────┼───────┐                           │
│       ▼       ▼       ▼                            │
│  ┌─────┐ ┌─────┐ ┌─────┐                        │
│  │ DB  │ │ DB  │ │ S3  │                        │
│  │Alunos│ │Jobs │ │Docs │                       │
│  └─────┘ └─────┘ └─────┘                        │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│              Host Machine                          │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │          Express API                         │ │
│  │          Port: 3000                          │ │
│  │          Routes: /request-document           │ │
│  └──────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

---

## 📸 Exportar Diagrama como Imagem

### Opção 1: Mermaid CLI

```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i diagram.mmd -o diagram.png
```

### Opção 2: Online

1. Acesse https://mermaid.live/
2. Cole o código Mermaid
3. Clique em "Download PNG/SVG"

### Opção 3: No GitHub

1. GitHub renderiza automaticamente
2. Use screenshot tool (Win+Shift+S)

---

## 🎨 Cores Utilizadas

| Componente | Cor         | Hex     | Significado          |
| ---------- | ----------- | ------- | -------------------- |
| Lambda     | Laranja     | #FF9900 | AWS Lambda oficial   |
| SQS        | Rosa        | #FF4F8B | AWS SQS oficial      |
| DynamoDB   | Azul        | #4053D6 | AWS DynamoDB oficial |
| S3         | Verde       | #569A31 | AWS S3 oficial       |
| API        | Verde Claro | #68A063 | Express.js           |

---

## 📱 Para Apresentações

### PowerPoint/Google Slides

- Use screenshot do diagrama renderizado no GitHub
- Adicione animações nos passos numerados
- Destaque cada serviço AWS com cores oficiais

### Notion/Confluence

- Importe o código Mermaid diretamente
- Ambos suportam renderização nativa

### PDF

- Export do GitHub como imagem
- Ou use Mermaid Live Editor para exportar SVG

---

<div align="center">

**Diagrama desenvolvido para máxima clareza em entrevistas técnicas**

</div>
