
# 📋 Projeto Integrador - Cloud Developing 2025/1

## Sistema de Gerenciamento de Tarefas com AWS

**Curso**: Sistemas de Informação - Mackenzie
**Data**: Novembro 2025
**Versão**: 1.0

***
## 🎯 Visão Geral

### Objetivo

Desenvolver um sistema CRUD completo com infraestrutura AWS demonstrando:

- ✅ Backend containerizado (ECS Fargate)
- ✅ Banco de dados gerenciado (RDS PostgreSQL em subnet privada)
- ✅ API Gateway com proxy simples
- ✅ Lambda para relatórios (sem acesso direto ao RDS)
- ✅ Infraestrutura como código (CloudFormation)


### Critérios de Avaliação (100 pontos)

| Critério | Pontos |
| :-- | :-- |
| Infra AWS configurada (VPC, RDS privado, ECS, Docker) | 40 |
| Lambda /report funcional | 15 |
| API CRUD operacional | 25 |
| Documentação (README + PDF) | 10 |
| Vídeo (≤5 min, com áudio) | 5 |
| Apresentação ao vivo (10 min) | 5 |
| **CI/CD automático (CodePipeline)** | **BÔNUS** |


***

## 🏗️ Arquitetura

### Diagrama de Componentes

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


### Fluxos de Requisições

#### Fluxo 1: CRUD Operations

```
Cliente HTTP
  ↓
API Gateway (/{proxy+})
  ↓
HTTP Proxy → ALB:80
  ↓
ECS Task (Container na subnet privada)
  ↓
RDS PostgreSQL (subnet privada)
  ↓
Resposta JSON
```


#### Fluxo 2: Relatório Serverless

```
Cliente HTTP
  ↓
API Gateway (/report)
  ↓
AWS Lambda (Python)
  ↓
HTTP call → ALB:80/tasks
  ↓
ECS Task
  ↓
RDS PostgreSQL
  ↓
Lambda calcula estatísticas
  ↓
Retorna JSON com relatório
```


***

## 📦 Componentes do Sistema

### 1. VPC e Networking

#### Configuração da VPC

| Recurso | CIDR/Valor | Descrição |
| :-- | :-- | :-- |
| VPC | `10.0.0.0/16` | Rede principal isolada |
| PublicSubnet1 | `10.0.1.0/24` | AZ 1 - ALB |
| PublicSubnet2 | `10.0.2.0/24` | AZ 2 - ALB |
| PrivateSubnet1 | `10.0.10.0/24` | AZ 1 - RDS + ECS |
| PrivateSubnet2 | `10.0.11.0/24` | AZ 2 - RDS + ECS |

#### Componentes de Rede

- **Internet Gateway**: Acesso à internet para recursos públicos
- **NAT Gateway**: Permite saída segura para recursos privados
- **Route Tables**:
    - Pública: `0.0.0.0/0 → Internet Gateway`
    - Privada: `0.0.0.0/0 → NAT Gateway`


### 2. Security Groups

#### ALB Security Group

```yaml
Ingress:
  - Port: 80 (HTTP)
    Source: 0.0.0.0/0
  - Port: 443 (HTTPS)
    Source: 0.0.0.0/0
```


#### ECS Security Group

```yaml
Ingress:
  - Port: 3000 (Application)
    Source: ALB Security Group
```


#### RDS Security Group (Isolado)

```yaml
Ingress:
  - Port: 5432 (PostgreSQL)
    Source: ECS Security Group
# ❌ SEM ACESSO EXTERNO
```


### 3. Amazon RDS PostgreSQL

#### Configuração

```yaml
Engine: PostgreSQL 16.1
Instance Class: db.t4g.micro
Storage: 20GB gp3
Multi-AZ: true
Backup Retention: 7 dias
Subnet Group: Privado (PrivateSubnet1 + PrivateSubnet2)
Publicly Accessible: false
IAM DB Authentication: true
```


#### Credenciais

- Armazenadas em **AWS Secrets Manager**
- Secret Name: `{environment}/rds/password`
- Formato JSON:

```json
{
  "username": "postgres",
  "password": "***",
  "engine": "postgres",
  "host": "rds-endpoint.rds.amazonaws.com",
  "port": 5432,
  "dbname": "tasks_db"
}
```


### 4. Amazon ECR (Container Registry)

```bash
# Repositório
{account-id}.dkr.ecr.{region}.amazonaws.com/{environment}-tasks-api

# Configurações
- Image Scanning: Habilitado
- Lifecycle Policy: Manter últimas 10 imagens
- Encryption: Habilitado
```


### 5. Amazon ECS Fargate

#### Cluster

```yaml
Name: {environment}-tasks-cluster
Type: Fargate (Serverless)
Container Insights: Habilitado
```


#### Task Definition

```yaml
Family: {environment}-tasks-api
CPU: 256
Memory: 512 MB
Network Mode: awsvpc
Execution Role: ECSTaskExecutionRole
Task Role: ECSTaskRole

Container:
  Name: tasks-api
  Port: 3000
  Environment:
    - DB_HOST: {rds-endpoint}
    - DB_PORT: 5432
    - DB_USER: postgres
    - DB_NAME: tasks_db
    - DB_SSL: true
    - NODE_ENV: {environment}
  Secrets:
    - DB_PASSWORD (via Secrets Manager)
```


#### Service

```yaml
Desired Count: 2
Max: 2
Min: 1
Deployment Strategy:
  Max Percent: 200
  Min Healthy Percent: 100
Placement: Multi-AZ (ambas subnets privadas)
Health Check: /health a cada 30s
Load Balancer: ALB Target Group
```


#### Auto Scaling

```yaml
Metric: CPU Utilization
Target Value: 70%
Scale Out Cooldown: 60s
Scale In Cooldown: 300s
```


### 6. Application Load Balancer

```yaml
Name: {environment}-tasks-alb
Scheme: internet-facing
Subnets: PublicSubnet1, PublicSubnet2
Security Group: ALBSecurityGroup

Target Group:
  Name: {environment}-tasks-tg
  Protocol: HTTP
  Port: 3000
  Target Type: IP (Fargate)
  Health Check:
    Path: /health
    Interval: 30s
    Timeout: 5s
    Healthy Threshold: 2
    Unhealthy Threshold: 3
    Matcher: 200
```


### 7. API Gateway

#### REST API

```yaml
Name: {environment}-tasks-api
Type: Regional
Stage: {environment}
```


#### Recursos e Métodos

**1. Proxy Simples (`/{proxy+}`)**

```yaml
Method: ANY
Authorization: NONE
Integration Type: HTTP_PROXY
Integration HTTP Method: ANY
URI: http://{ALB-DNS}:80/{proxy}
```

**Resultado**: Todas as rotas CRUD (GET/POST/PUT/PATCH/DELETE /tasks) são roteadas automaticamente para o ALB.

**2. Rota de Relatório (`/report`)**

```yaml
Method: GET
Authorization: NONE
Integration Type: AWS_PROXY
Integration: Lambda Function
Function: {environment}-tasks-report
```

**Resultado**: Lambda é invocada, consome `/tasks` via HTTP e retorna estatísticas.

### 8. AWS Lambda

#### Configuração

```yaml
Function Name: {environment}-tasks-report
Runtime: Python 3.11
Handler: index.lambda_handler
Memory: 128 MB
Timeout: 30s
Role: LambdaExecutionRole
```


#### Environment Variables

```yaml
API_GATEWAY_URL: http://{ALB-DNS}
```


#### Comportamento

1. Recebe evento do API Gateway (`/report`)
2. Faz HTTP GET para `{API_GATEWAY_URL}/tasks`
3. Processa lista de tarefas
4. Calcula estatísticas:
    - Total de tarefas
    - Contagem por status (pending, in_progress, completed)
    - Contagem por prioridade (low, medium, high)
    - Taxa de conclusão
    - Tarefas em progresso
    - Tarefas de alta prioridade pendentes
5. Retorna JSON

#### Resposta Exemplo

```json
{
  "success": true,
  "data": {
    "total_tasks": 10,
    "tasks_by_status": {
      "pending": 5,
      "in_progress": 3,
      "completed": 2
    },
    "tasks_by_priority": {
      "low": 2,
      "medium": 5,
      "high": 3
    },
    "completion_rate": 20.0,
    "tasks_in_progress_count": 3,
    "high_priority_pending": 1
  },
  "generated_at": "2025-11-02T14:30:00.000Z"
}
```


### 9. CloudWatch Logs

#### Log Groups

| Log Group | Retenção | Conteúdo |
| :-- | :-- | :-- |
| `/ecs/{environment}-tasks-api` | 7 dias | Logs da aplicação Node.js |
| `/aws/lambda/{environment}-tasks-report` | 7 dias | Logs da função Lambda |


***

## 💻 Backend API

### Estrutura do Projeto

```
backend/
├── src/
│   ├── config/
│   │   └── database.js       # Pool de conexões  PostgreSQL
│   ├── routes/
│   │   └── tasks.js          # Rotas CRUD
│   └── index.js              # App Express
├── Dockerfile
├── package.json
├── .env.example
├── init.sql                  # Script SQL
└── test-api.sh               # Script de testes
```


### Endpoints Disponíveis

#### Health Check

```http
GET /health

Response 200:
{
  "success": true,
  "status": "healthy",
  "database": "connected",
  "timestamp": "2025-11-02T14:30:00.000Z"
}
```


#### Listar Tarefas

```http
GET /tasks
GET /tasks?status=pending
GET /tasks?priority=high
GET /tasks?status=pending&priority=high

Response 200:
{
  "success": true,
  "count": 5,
  "data": [
    {
      "id": 1,
      "title": "Configurar RDS",
      "description": "Criar instância PostgreSQL",
      "status": "pending",
      "priority": "high",
      "created_at": "2025-11-01T20:00:00.000Z",
      "updated_at": "2025-11-01T20:00:00.000Z"
    },
    ...
  ]
}
```


#### Buscar Tarefa Específica

```http
GET /tasks/:id

Response 200:
{
  "success": true,
  "data": {
    "id": 1,
    "title": "Configurar RDS",
    ...
  }
}

Response 404:
{
  "success": false,
  "error": "Tarefa não encontrada"
}
```


#### Criar Tarefa

```http
POST /tasks
Content-Type: application/json

Body:
{
  "title": "Implementar Lambda",        # Obrigatório
  "description": "Criar função report",
  "status": "pending",                  # Padrão: pending
  "priority": "medium"                  # Padrão: medium
}

Response 201:
{
  "success": true,
  "message": "Tarefa criada com sucesso",
  "data": {
    "id": 10,
    "title": "Implementar Lambda",
    "description": "Criar função report",
    "status": "pending",
    "priority": "medium",
    "created_at": "2025-11-02T14:30:00.000Z",
    "updated_at": "2025-11-02T14:30:00.000Z"
  }
}

Response 400 (título vazio):
{
  "success": false,
  "error": "O título da tarefa é obrigatório"
}
```


#### Atualizar Tarefa Completa (PUT)

```http
PUT /tasks/:id
Content-Type: application/json

Body:
{
  "title": "Implementar Lambda - DONE",
  "description": "Função report criada e testada",
  "status": "completed",
  "priority": "high"
}

Response 200:
{
  "success": true,
  "message": "Tarefa atualizada com sucesso",
  "data": { ... }
}
```


#### Atualizar Parcialmente (PATCH)

```http
PATCH /tasks/:id
Content-Type: application/json

Body:
{
  "status": "completed"
}
# Ou
{
  "priority": "low"
}

Response 200:
{
  "success": true,
  "message": "Tarefa atualizada com sucesso",
  "data": { ... }
}
```


#### Deletar Tarefa

```http
DELETE /tasks/:id

Response 200:
{
  "success": true,
  "message": "Tarefa deletada com sucesso",
  "data": { ... }
}

Response 404:
{
  "success": false,
  "error": "Tarefa não encontrada"
}
```


### Script SQL

```sql
-- Criar tabela de tarefas
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending' 
      CHECK (status IN ('pending', 'in_progress', 'completed')),
    priority VARCHAR(20) DEFAULT 'medium' 
      CHECK (priority IN ('low', 'medium', 'high')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para performance
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_created_at ON tasks(created_at DESC);

-- Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_tasks_updated_at 
  BEFORE UPDATE ON tasks
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Dados de exemplo
INSERT INTO tasks (title, description, status, priority) VALUES
  ('Estudar AWS Lambda', 'Revisar módulo 9', 'pending', 'high'),
  ('Configurar RDS', 'Instância PostgreSQL privada', 'in_progress', 'high'),
  ('Implementar API Gateway', 'Proxy + Lambda', 'pending', 'medium');
```


### Variáveis de Ambiente

```env
# .env
DB_HOST=aws-0-us-east-1.pooler.supabase.com
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=sua_senha_aqui
DB_NAME=postgres
DB_SSL=true
PORT=3000
NODE_ENV=development
```


***

## ⚡ Lambda Function

### Código Completo (Python)

```python
"""
Lambda Function - Report Generator
Consome API via HTTP e retorna estatísticas
"""

import json
import http.client
from urllib.parse import urlparse
import logging
from datetime import datetime
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def call_api(url, method='GET'):
    try:
        logger.info(f'Chamando API: {method} {url}')
        
        parsed_url = urlparse(url)
        port = 443 if parsed_url.scheme == 'https' else 80
        
        if parsed_url.scheme == 'https':
            conn = http.client.HTTPSConnection(parsed_url.netloc, port, timeout=10)
        else:
            conn = http.client.HTTPConnection(parsed_url.netloc, port, timeout=10)
        
        path = parsed_url.path
        if parsed_url.query:
            path += f'?{parsed_url.query}'
        
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'AWS-Lambda-Report-Function'
        }
        
        conn.request(method, path, headers=headers)
        response = conn.getresponse()
        data = response.read().decode('utf-8')
        conn.close()
        
        if response.status == 200:
            return json.loads(data)
        else:
            logger.error(f'API retornou status {response.status}: {data}')
            return None
            
    except Exception as e:
        logger.error(f'Erro ao chamar API: {str(e)}')
        return None

def lambda_handler(event, context):
    try:
        logger.info(f'Evento: {json.dumps(event)}')
        
        api_url = os.environ.get('API_GATEWAY_URL')
        if not api_url:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'success': False,
                    'error': 'API_GATEWAY_URL não configurada'
                })
            }
        
        # Consumir API
        tasks_url = f'{api_url}/tasks'
        api_response = call_api(tasks_url)
        
        if not api_response or 'data' not in api_response:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'success': False,
                    'error': 'Erro ao obter dados da API'
                })
            }
        
        tasks = api_response.get('data', [])
        
        # Calcular estatísticas
        stats = {
            'total_tasks': len(tasks),
            'tasks_by_status': {
                'pending': 0,
                'in_progress': 0,
                'completed': 0
            },
            'tasks_by_priority': {
                'low': 0,
                'medium': 0,
                'high': 0
            },
            'completion_rate': 0.0,
            'tasks_in_progress_count': 0,
            'high_priority_pending': 0
        }
        
        for task in tasks:
            status = task.get('status', 'pending')
            priority = task.get('priority', 'medium')
            
            if status in stats['tasks_by_status']:
                stats['tasks_by_status'][status] += 1
            if priority in stats['tasks_by_priority']:
                stats['tasks_by_priority'][priority] += 1
            
            if status == 'in_progress':
                stats['tasks_in_progress_count'] += 1
            if status == 'pending' and priority == 'high':
                stats['high_priority_pending'] += 1
        
        if len(tasks) > 0:
            completed = stats['tasks_by_status']['completed']
            stats['completion_rate'] = round((completed / len(tasks)) * 100, 2)
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'success': True,
                'data': stats,
                'generated_at': datetime.utcnow().isoformat()
            }, indent=2)
        }
    
    except Exception as e:
        logger.error(f'Erro: {str(e)}', exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': str(e)
            })
        }
```


***

## ☁️ CloudFormation

### Parâmetros

```yaml
Parameters:
  EnvironmentName:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]
  
  DBName:
    Type: String
    Default: tasks_db
  
  DBUsername:
    Type: String
    Default: postgres
    NoEcho: true
  
  DBPassword:
    Type: String
    NoEcho: true
    MinLength: 12
  
  ECSTaskMemory:
    Type: Number
    Default: 512
    AllowedValues: [256, 512, 1024, 2048, 4096]
  
  ECSTaskCPU:
    Type: Number
    Default: 256
    AllowedValues: [256, 512, 1024, 2048, 4096]
```


### Outputs Principais

```yaml
Outputs:
  VPCId:
    Value: !Ref TasksVPC
  
  RDSEndpoint:
    Value: !GetAtt RDSDatabase.Endpoint.Address
    Description: Endpoint privado do RDS
  
  ECRRepositoryUri:
    Value: !GetAtt ECRRepository.RepositoryUri
  
  ALBDNSName:
    Value: !GetAtt TasksALB.DNSName
  
  APIGatewayURL:
    Value: !Sub 'https://${TasksAPIGateway}.execute-api.${AWS::Region}.amazonaws.com/${EnvironmentName}'
  
  ReportEndpoint:
    Value: !Sub 'https://${TasksAPIGateway}.execute-api.${AWS::Region}.amazonaws.com/${EnvironmentName}/report'
  
  ECSClusterName:
    Value: !Ref ECSCluster
  
  LambdaFunctionName:
    Value: !Ref TasksReportFunction
```


***

## 🚀 Deployment

### Pré-requisitos


# Guia Completo: AWS CLI no Windows

## Pré-requisitos

Antes de iniciar a instalação, você precisará de:

- **Conta AWS**: Crie uma em https://aws.amazon.com/ se ainda não tiver[^4]
- **Credenciais IAM**: Acesse o console AWS, crie um usuário IAM (não use credenciais root) e gere suas chaves de acesso (Access Key ID e Secret Access Key)
- **Conexão com internet** para fazer o download do instalador

***

## Instalação no Windows

### Método 1: Usando o Instalador MSI (Recomendado)

**Passo 1: Fazer o Download**

1. Acesse: https://awscli.amazonaws.com/AWSCLIV2.msi
2. O arquivo `AWSCLIV2.msi` será baixado automaticamente
3. Salve-o em uma pasta de fácil acesso (como Downloads)

**Passo 2: Executar o Instalador**

1. Localize o arquivo `AWSCLIV2.msi` na pasta de Downloads
2. Clique duas vezes no arquivo para iniciar a instalação
3. A janela do instalador será exibida

**Passo 3: Completar a Instalação**

1. Clique em "Next" (Próximo)
2. Leia e aceite o contrato de licença
3. Clique em "I agree" ou aceite os termos
4. Na tela "Custom Setup", clique em "Next" (configurações padrão recomendadas)
5. Clique em "Install" para iniciar a instalação
6. Aguarde a conclusão (pode levar alguns minutos)
7. Clique em "Finish" para finalizar

**Passo 4: Verificar Instalação**

1. Abra o **Command Prompt** ou **PowerShell**
2. Digite o comando:

```
aws --version
```

3. Pressione Enter
4. Se instalado corretamente, você verá algo como: `AWS CLI 2.x.x Python/3.x.x ...`

## Configuração do AWS CLI

Após a instalação, configure suas credenciais AWS:

### Passo 1: Executar aws configure

Abra o Command Prompt ou PowerShell e digite:

```
aws configure
```


### Passo 2: Fornecer as Credenciais

O sistema solicitará as seguintes informações:

1. **AWS Access Key ID**: Cole sua chave de acesso (fornecida pelo IAM)

```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
```

2. **AWS Secret Access Key**: Cole sua chave secreta

```
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

3. **Default region name**: Digite a região AWS desejada (ex: us-east-1, eu-west-1, sa-east-1)

```
Default region name [None]: us-east-1
```

4. **Default output format**: Deixe em branco ou digite `json` (recomendado)

```
Default output format [None]: json
```


### Passo 3: Verificar Configuração

As credenciais serão salvas em: `C:\Users\<seu_usuario>\.aws\credentials`

***


```bash
# 1. AWS CLI
aws --version

# 2. Docker
docker --version

# 3. Git
git --version

# 4. Node.js
node --version
```


### Passo a Passo

#### 1. Preparar Backend

```bash
cd backend

# Instalar dependências
npm install

# Build Docker
docker build -t tasks-api:latest .
```


#### 2. Push para ECR

```bash
# Obter account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ENV=dev

# Login no ECR (criar repositório primeiro)
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Tag
docker tag tasks-api:latest \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ENV-tasks-api:latest

# Push
docker push \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ENV-tasks-api:latest
```


#### 3. Deploy CloudFormation

```bash
# Dar permissão ao script
chmod +x deploy.sh

# Criar stack
./deploy.sh create dev "MySecurePassword123Min12Chars"

# Aguardar (~15 minutos)
# Acompanhar no console AWS CloudFormation
```


#### 4. Obter Outputs

```bash
./deploy.sh describe dev
```

Você receberá:

- API Gateway URL
- Report Endpoint
- ALB DNS Name
- RDS Endpoint
- ECR URI


#### 5. Executar Script SQL no RDS

Conectar ao RDS via bastion host ou AWS Systems Manager Session Manager e executar `init.sql`.

#### 6. Testar API

```bash
# Via API Gateway
API_URL="https://xxx.execute-api.us-east-1.amazonaws.com/dev"

# Listar tarefas
curl $API_URL/tasks

# Criar tarefa
curl -X POST $API_URL/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Teste via API Gateway","priority":"high"}'

# Relatório
curl $API_URL/report
```


***

## 🧪 Testes

### Script de Testes Automatizado

```bash
cd backend
chmod +x test-api.sh

# Testar localmente
./test-api.sh http://localhost:3000

# Testar via API Gateway
./test-api.sh https://xxx.execute-api.us-east-1.amazonaws.com/dev verbose
```


### Testes Inclusos

- ✅ Health Check (2 testes)
- ✅ CREATE - POST (5 testes)
- ✅ READ - GET (6 testes)
- ✅ UPDATE - PUT (2 testes)
- ✅ UPDATE - PATCH (3 testes)
- ✅ DELETE (3 testes)
- ✅ Validação (3 testes)
- ✅ Performance (2 testes)

**Total**: 25+ testes automatizados


***

## 🔐 Segurança

### Implementações

1. **RDS em Subnet Privada**
    - ❌ Sem IP público
    - ❌ Sem porta exposta à internet
    - ✅ Acesso apenas via ECS
2. **Security Groups Restritivos**
    - Tráfego mínimo necessário
    - Regras específicas por camada
3. **Credenciais Seguras**
    - AWS Secrets Manager

### Checklist de Segurança

- [x] RDS sem acesso público
- [x] Security Groups mínimos

***


### Tecnologias

- [Express.js](https://expressjs.com/)
- [Node.js](https://nodejs.org/)
- [PostgreSQL](https://www.postgresql.org/)
- [Docker](https://www.docker.com/)


### AWS Academy

- Módulo 7: Contêineres
- Módulo 9: Lambda
- Módulo 10: API Gateway
- Módulo 13: CI/CD

***

## 👥 Grupo

| RA | Nome | Responsabilidade |
| :-- | :-- | :-- |
| xxxxx | ... | Backend API |
| xxxxx | ... | Infraestrutura AWS |
| xxxxx | ... | Lambda Function |
| xxxxx | ... | Documentação |
| xxxxx | ... | Apresentação |