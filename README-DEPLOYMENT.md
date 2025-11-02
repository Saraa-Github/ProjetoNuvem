# Projeto Integrador - Cloud Developing 2025/1

Lista de Tarefas + AWS (ECS + Lambda + RDS + API Gateway)

## 📋 Visão Geral

Sistema de **gerenciamento de tarefas** com backend Node.js/Express, banco de dados PostgreSQL e infraestrutura AWS completa, incluindo:

- ✅ **Backend API**: Express.js com CRUD completo
- ✅ **Banco de Dados**: AWS RDS PostgreSQL (subnet privada)
- ✅ **Containerização**: Docker + Amazon ECR
- ✅ **Orquestração**: AWS ECS Fargate
- ✅ **API Gateway**: Proxy simples + rota /report
- ✅ **Serverless**: AWS Lambda para gerar relatórios
- ✅ **Load Balancer**: ALB com health check
- ✅ **Infraestrutura as Code**: CloudFormation
- ✅ **Rede Segura**: VPC com subnets públicas/privadas

## 🎯 Escopo do Projeto

### Avaliação (100 pontos)

| Critério | Pontos |
|----------|--------|
| Infra AWS configurada (VPC, RDS privado, ECS, Docker) | 40 |
| Lambda /report funcional | 15 |
| API CRUD operacional | 25 |
| Documentação (README + PDF) | 10 |
| Vídeo (≤5 min, com áudio) | 5 |
| Apresentação ao vivo (10 min) | 5 |
| **CI/CD automático (CodePipeline)** | **BÔNUS** |

## 📁 Estrutura do Repositório

```
projeto-integrador/
├── backend/                    # API Node.js
│   ├── src/
│   │   ├── config/
│   │   │   └── database.js     # Conexão PostgreSQL
│   │   ├── routes/
│   │   │   └── tasks.js        # Endpoints CRUD
│   │   └── index.js            # App principal
│   ├── Dockerfile
│   ├── package.json
│   ├── .env.example
│   ├── init.sql                # Script SQL
│   └── test-api.sh             # Testes
│
├── lambda/                     # Funções Lambda
│   ├── handler.py              # Report function
│   └── requirements.txt
│
├── cloudformation-template.yaml # Infra as Code
├── deploy.sh                    # Script deployment
├── INFRASTRUCTURE.md            # Doc técnica
└── README.md                    # Este arquivo
```

## 🚀 Quick Start

### 1. Clonar o Repositório

```bash
git clone https://github.com/seu-usuario/projeto-integrador.git
cd projeto-integrador
```

### 2. Backend Local (com Supabase)

```bash
cd backend

# Instalar dependências
npm install

# Copiar e configurar .env
cp .env.example .env
# Editar .env com credenciais do banco de dados

# Rodar script SQL no banco de dados (RDS / Supabase ou Docker)
# (SQL Editor do Supabase → copiar/colar init.sql)

# Para rodar com docker, executar "docker-compose up"

# Iniciar servidor
npm run dev
# API em http://localhost:3000
```

### 3. Testar APIs

```bash
# Dar permissão ao script
chmod +x backend/test-api.sh

# Rodar testes
cd backend
./test-api.sh http://localhost:3000 verbose
cd ..
```

### 4. Deploy na AWS

```bash
# Dar permissão ao script deploy
chmod +x deploy.sh

# Criar stack CloudFormation
./deploy.sh create dev "MyPassword123Min12Chars"

# Aguardar conclusão (~15 minutos)

# Obter outputs
./deploy.sh describe dev

# Usar API Gateway URL nos outputs
```

## 📚 Documentação

### Arquivos Principais

| Arquivo | Descrição |
|---------|-----------|
| `INFRASTRUCTURE.md` | Documentação completa da AWS |
| `backend/README.md` | Como rodar backend |
| `cloudformation-template.yaml` | Template IaC (26KB) |
| `lambda/handler.py` | Função Lambda Python |

### Fluxos de Requisições

#### 1. CRUD (GET, POST, PUT, PATCH, DELETE)

```
Cliente
  ↓
API Gateway (/{proxy+})
  ↓
HTTP Proxy → ALB:80
  ↓
ECS Task (Container)
  ↓
RDS PostgreSQL
```

#### 2. Relatório (GET /report)

```
Cliente
  ↓
API Gateway (/report)
  ↓
Lambda (Python)
  ↓
HTTP call → ALB:80/tasks
  ↓
Processa dados
  ↓
Retorna JSON com estatísticas
```

## 🔧 Endpoints da API

### Tasks CRUD

```bash
# Listar todas
GET /tasks

# Filtrar
GET /tasks?status=pending&priority=high

# Buscar uma
GET /tasks/:id

# Criar
POST /tasks
Body: {
  "title": "Estudar Lambda",
  "description": "Revisar módulo 9",
  "status": "pending",
  "priority": "high"
}

# Atualizar completo
PUT /tasks/:id
Body: { ...todos os campos }

# Atualizar parcial
PATCH /tasks/:id
Body: { "status": "completed" }

# Deletar
DELETE /tasks/:id
```

### Especiais

```bash
# Health Check
GET /health

# Relatório (Lambda)
GET /report
Response: {
  "total_tasks": 10,
  "tasks_by_status": {...},
  "completion_rate": 30.0,
  ...
}
```

## 🏗️ Arquitetura AWS

```
┌─────────────────────────────────────────────────────┐
│                    Internet                          │
└────────────────────┬────────────────────────────────┘
                     │
        ┌────────────▼─────────────┐
        │   API Gateway (Regional) │
        │  /{proxy+}  │  /report   │
        └────┬───────────────┬────┘
             │               │
             │           ┌───▼──────┐
             │           │ Lambda   │
             │           │ (Python) │
             │           └────┬─────┘
             │                │
        ┌────▼────────────────▼──┐
        │ ALB (Public Subnets)   │
        └────┬────────────────────┘
             │
   ┌─────────▼─────────┐
   │   VPC 10.0.0.0/16 │
   │                   │
   │  ┌──────────────┐ │
   │  │ ECS Fargate  │ │
   │  │ (Private SN) │ │
   │  └──────┬───────┘ │
   │         │         │
   │  ┌──────▼──────┐  │
   │  │ RDS PG      │  │
   │  │ (Private)   │  │
   │  └─────────────┘  │
   │                   │
   └───────────────────┘
```

## 📝 Variáveis de Ambiente

### Backend

```env
DB_HOST=aws-xxx.pooler.supabase.com
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=xxxxx
DB_NAME=postgres
DB_SSL=true
PORT=3000
NODE_ENV=development
```

### Lambda

```env
API_GATEWAY_URL=http://alb-dns-name
```

## 🔐 Segurança

- ✅ RDS em subnet privada (sem acesso externo)
- ✅ Security Groups restritivos
- ✅ Credenciais em AWS Secrets Manager
- ✅ IAM Roles com princípio de menor privilégio
- ✅ Encryption at rest (RDS)
- ✅ Multi-AZ para alta disponibilidade

## 📊 Monitoramento

### CloudWatch

- **ECS Logs**: `/ecs/dev-tasks-api`
- **Lambda Logs**: `/aws/lambda/dev-tasks-report`
- **Métricas**: CPU, Memory, Network, Requests

### Alertas Recomendados

- RDS CPU > 80%
- ECS CPU > 90%
- ALB unhealthy targets
- Lambda errors > 0

## 💾 Backup e Disaster Recovery

- RDS: Backup automático (7 dias)
- ECR: Últimas 10 imagens mantidas
- CloudFormation: Template versionado

## 🧪 Testes

### Testes Unitários/Integração

```bash
cd backend
./test-api.sh http://localhost:3000 verbose
```

### Testes de Carga (opcional)

```bash
# Com Apache Bench
ab -n 100 -c 10 http://alb-dns/tasks

# Com hey
hey -n 100 -c 10 http://alb-dns/tasks
```

## 🚢 CI/CD (Bonus)

Adicionar CodePipeline + CodeBuild para automação:

```yaml
Source: GitHub
Build: CodeBuild (docker build + push ECR)
Deploy: CloudFormation Update
```

## 📖 Referências

- [AWS CloudFormation](https://docs.aws.amazon.com/cloudformation/)
- [ECS Fargate](https://docs.aws.amazon.com/AmazonECS/)
- [RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/)
- [API Gateway](https://docs.aws.amazon.com/apigateway/)
- [AWS Lambda](https://docs.aws.amazon.com/lambda/)
- [Express.js](https://expressjs.com/)

## 👥 Grupo

| RA | Nome | Responsabilidade |
|----|------|-----------------|
| xxxxx | ... | Backend |
| xxxxx | ... | Infraestrutura AWS |
| xxxxx | ... | Lambda |
| xxxxx | ... | Documentação |
| xxxxx | ... | Apresentação |

## 📞 Suporte

- Issues: GitHub Issues
- Dúvidas: Verificar `INFRASTRUCTURE.md`
- Troubleshooting: Seção em `INFRASTRUCTURE.md`

---

**Versão**: 1.0  
**Data**: Novembro 2025  
**Projeto**: Mackenzie - Cloud Developing 2025/1
