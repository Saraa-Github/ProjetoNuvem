# Documentação de Infraestrutura AWS

## Projeto Integrador Cloud Developing - Mackenzie

Arquitetura completa de deployment da API de Lista de Tarefas utilizando AWS, com RDS privado, ECS Fargate, API Gateway e Lambda.

---

## 📋 Índice

1. [Visão Geral da Arquitetura](#visão-geral-da-arquitetura)
2. [Componentes AWS](#componentes-aws)
3. [Fluxo de Requisições](#fluxo-de-requisições)
4. [Deployment](#deployment)
5. [Monitoramento](#monitoramento)
6. [Troubleshooting](#troubleshooting)

---

## 🏗️ Visão Geral da Arquitetura

```
Internet
   |
   ↓
[API Gateway]
   |
   ├─→ {proxy+} ────→ [ALB] ────→ [ECS Fargate] (Privado)
   |                               ↓
   |                          [RDS PostgreSQL] (Privado)
   |
   └─→ /report ────→ [Lambda] ────→ [ALB] ────→ API
```

### Características principais

- **VPC Privada**: Isolamento seguro dos recursos
- **RDS em Subnet Privada**: Nenhum acesso externo direto
- **ECS Fargate**: Containers gerenciados (serverless)
- **API Gateway**: Proxy simples com rota /report para Lambda
- **Lambda**: Consome a API via ALB para gerar estatísticas
- **ALB**: Load balancer com health check automático
- **Auto Scaling**: ECS com políticas de scaling automático

---

## 🔧 Componentes AWS

### 1. VPC e Networking

#### VPC (Virtual Private Cloud)
- **CIDR**: `10.0.0.0/16`
- **DNS**: Habilitado para comunicação interna

#### Subnets

| Subnet | CIDR | Tipo | Propósito |
|--------|------|------|----------|
| PublicSubnet1 | 10.0.1.0/24 | Pública | ALB |
| PublicSubnet2 | 10.0.2.0/24 | Pública | ALB |
| PrivateSubnet1 | 10.0.10.0/24 | Privada | RDS + ECS |
| PrivateSubnet2 | 10.0.11.0/24 | Privada | RDS + ECS |

#### Internet Gateway
- Permite tráfego de saída da VPC

#### NAT Gateway
- Permite que recursos privados acessem a internet
- Hospedado na subnet pública

### 2. Security Groups

#### ALB Security Group
```
Entrada:
  - HTTP (80) de 0.0.0.0/0
  - HTTPS (443) de 0.0.0.0/0
```

#### ECS Security Group
```
Entrada:
  - TCP 3000 do ALB Security Group
```

#### RDS Security Group
```
Entrada:
  - PostgreSQL (5432) do ECS Security Group
```

**Importante**: RDS NÃO tem porta exposta para internet

### 3. Banco de Dados (RDS)

#### Configuração
- **Engine**: PostgreSQL 16.1
- **Instance Type**: db.t4g.micro (gratuito na AWS free tier)
- **Storage**: 20GB gp3
- **Multi-AZ**: Sim (alta disponibilidade)
- **Subnet Group**: Privada (sem acesso externo)
- **Backup**: 7 dias de retenção

#### Conectividade
- Acessível APENAS por instâncias ECS
- Credenciais armazenadas em AWS Secrets Manager
- IAM Database Authentication habilitado

#### Logs
- CloudWatch Logs habilitados para PostgreSQL

### 4. Container Registry (ECR)

#### Amazon ECR
- **Repositório**: `{account-id}.dkr.ecr.{region}.amazonaws.com/{environment}-tasks-api`
- **Image Scanning**: Ativado (detecção de vulnerabilidades)
- **Lifecycle Policy**: Mantém últimas 10 imagens

#### Como fazer push da imagem

```bash
# 1. Fazer login no ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  {account-id}.dkr.ecr.us-east-1.amazonaws.com

# 2. Build da imagem
docker build -t tasks-api:latest .

# 3. Tag da imagem
docker tag tasks-api:latest \
  {account-id}.dkr.ecr.us-east-1.amazonaws.com/dev-tasks-api:latest

# 4. Push
docker push \
  {account-id}.dkr.ecr.us-east-1.amazonaws.com/dev-tasks-api:latest
```

### 5. Elastic Container Service (ECS)

#### Cluster
- **Nome**: `{environment}-tasks-cluster`
- **Type**: Fargate (serverless)
- **Container Insights**: Habilitado

#### Task Definition
- **CPU**: 256 unidades
- **Memory**: 512 MB
- **Container Port**: 3000

#### Service
- **Desired Count**: 2 (2 tasks em execução)
- **Placement**: Multi-AZ (ambas as subnets privadas)
- **Health Check**: Cada 30s, path `/health`

#### Auto Scaling
- **Mín**: 2 tasks
- **Máx**: 4 tasks
- **Métrica**: CPU > 70%
- **Scale Out**: 60s
- **Scale In**: 5min

### 6. Load Balancer (ALB)

#### Application Load Balancer
- **Nome**: `{environment}-tasks-alb`
- **Subnets**: PublicSubnet1 + PublicSubnet2
- **Scheme**: Internet-facing

#### Target Group
- **Protocol**: HTTP
- **Port**: 3000
- **Path Health Check**: `/health`
- **Intervalo**: 30s
- **Timeout**: 5s
- **Healthy Threshold**: 2

### 7. API Gateway

#### REST API
- **Nome**: `{environment}-tasks-api`
- **Type**: Regional endpoint

#### Recursos

**1. Proxy simples (`/{proxy+}`)**
```
Method: ANY
Integration: HTTP_PROXY
URI: http://{ALB-DNS}:80/{proxy}

Resultado: Todas as rotas CRUD são roteadas para o ALB
```

**2. Rota de relatório (`/report`)**
```
Method: GET
Integration: AWS_PROXY (Lambda)
Function: {environment}-tasks-report

Resultado: Lambda consome /tasks e retorna estatísticas
```

### 8. Lambda Function

#### Detalhes
- **Runtime**: Python 3.11
- **Memory**: 128 MB (padrão)
- **Timeout**: 30s

#### Environment Variables
```
API_GATEWAY_URL=http://{ALB-DNS}
```

#### Comportamento
1. Recebe requisição em `/report`
2. Faz HTTP call para `http://{ALB-DNS}/tasks` (acessa a API)
3. Processa dados e calcula estatísticas
4. Retorna JSON com relatório

#### Estatísticas Retornadas
```json
{
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
  "tasks_in_progress": 3,
  "high_priority_pending": 1,
  "generated_at": "2025-11-01T20:30:00.000Z"
}
```

### 9. Secrets Manager

#### AWS Secrets Manager
- **Secret Name**: `{environment}/rds/password`
- **Conteúdo**:
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

#### Acesso
- ECS: Via AWS Secrets Manager integração
- Lambda: Via IAM Role

### 10. CloudWatch Logs

#### Log Groups

| Log Group | Retenção | Propósito |
|-----------|----------|----------|
| `/ecs/{env}-tasks-api` | 7 dias | Logs da aplicação ECS |
| `/aws/lambda/{env}-tasks-report` | 7 dias | Logs da Lambda |

---

## 🔄 Fluxo de Requisições

### Fluxo 1: CRUD via API Gateway

```
Cliente HTTP
    ↓
API Gateway (/{proxy+})
    ↓
HTTP Proxy para ALB:80
    ↓
ALB (Application Load Balancer)
    ↓
ECS Task (Container na subnet privada)
    ↓
RDS PostgreSQL (Subnet privada)
    ↓
Resposta JSON
```

### Fluxo 2: Relatório via Lambda

```
Cliente HTTP
    ↓
API Gateway (/report)
    ↓
AWS Lambda
    ↓
HTTP call para ALB:80/tasks (via NAT Gateway)
    ↓
ECS Task
    ↓
RDS PostgreSQL
    ↓
Lambda processa dados
    ↓
Retorna estatísticas JSON
```

---

## 🚀 Deployment

### Pré-requisitos

1. **AWS CLI** configurado
   ```bash
   aws configure
   ```

2. **Docker** instalado para build da imagem

3. **Permissões IAM** para:
   - CloudFormation
   - ECS
   - RDS
   - Lambda
   - API Gateway
   - ECR

### Passos de Deployment

#### 1. Preparar o Backend

```bash
# Copiar o Dockerfile para o projeto backend
cp Dockerfile backend/

# Build da imagem Docker
cd backend
docker build -t tasks-api:latest .
cd ..
```

#### 2. Push para ECR

```bash
# Obter account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1

# Login no ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Tag
docker tag tasks-api:latest \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/dev-tasks-api:latest

# Push
docker push \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/dev-tasks-api:latest
```

#### 3. Deploy da Stack CloudFormation

```bash
# Dar permissão ao script
chmod +x deploy.sh

# Criar stack
./deploy.sh create dev "MySecurePassword123!Min12Chars"

# Aguardar criação (10-15 minutos)
```

#### 4. Obter Outputs

```bash
# Depois que a stack foi criada
./deploy.sh describe dev

# Você receberá:
# - VPC-Id
# - RDS-Endpoint
# - ECR-Uri
# - ALB-DNS
# - APIGateway-URL
# - Report-Endpoint
# - ECS-Cluster
# - Lambda-Function
```

#### 5. Criar Tabelas no RDS

```bash
# Obter endpoint do RDS
RDS_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name dev-tasks-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`RDSEndpoint`].OutputValue' \
  --output text)

# Conectar ao RDS (bastion host necessário ou SSM Session Manager)
# E executar o script SQL de criação de tabelas
psql -h $RDS_ENDPOINT -U postgres -d tasks_db \
  -f backend/init.sql
```

#### 6. Atualizar Task Definition

Após o push para ECR, atualizar a task definition para apontar para a nova imagem.

### Verificações Pós-Deploy

```bash
# 1. Verificar status da stack
aws cloudformation describe-stacks \
  --stack-name dev-tasks-stack \
  --query 'Stacks[0].StackStatus'

# 2. Verificar ECS Service
aws ecs describe-services \
  --cluster dev-tasks-cluster \
  --services dev-tasks-service \
  --query 'services[0].[RunningCount,DesiredCount]'

# 3. Verificar ALB health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]'

# 4. Testar API via API Gateway
curl https://{api-gateway-url}/tasks

# 5. Testar Lambda /report
curl https://{api-gateway-url}/report
```

---

## 📊 Monitoramento

### CloudWatch

#### Dashboards

Criar dashboard com métricas:
- **ECS**: CPU, Memory, Network
- **RDS**: Connections, CPU, Storage
- **Lambda**: Invocations, Duration, Errors
- **ALB**: Request Count, Target Latency

#### Alertas Recomendados

```
- RDS CPU > 80%
- ECS Task CPU > 90%
- ALB unhealthy targets > 0
- Lambda errors > 0
- API Gateway errors > 10
```

#### Logs

Consultar logs:
```bash
# Logs ECS
aws logs tail /ecs/dev-tasks-api --follow

# Logs Lambda
aws logs tail /aws/lambda/dev-tasks-report --follow
```

---

## 🔐 Segurança

### Implementações

1. **RDS em Subnet Privada**
   - Sem acesso direto da internet
   - Comunicação apenas via ECS

2. **Security Groups Restritivos**
   - Cada camada tem seu próprio SG
   - Tráfego mínimo necessário

3. **Credenciais em Secrets Manager**
   - Não hardcoded
   - Rotação automática possível

4. **IAM Roles**
   - Princípio de menor privilégio
   - ECS e Lambda com roles específicos

5. **VPC Endpoints** (opcional)
   - Para serviços AWS (S3, DynamoDB)

6. **Encryption**
   - RDS encryption at rest
   - EBS encryption habilitada

### Boas Práticas

- Mudar senha padrão do RDS regularmente
- Usar AWS Systems Manager Session Manager para acesso ao RDS
- Habilitar MFA para console AWS
- Usar CloudTrail para auditoria

---

## 🐛 Troubleshooting

### Problema: ECS Task não inicia

**Causa comum**: Erro de conexão com RDS

**Solução**:
```bash
# Verificar logs
aws logs tail /ecs/dev-tasks-api --follow

# Verificar security group do ECS
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --query 'SecurityGroups[0].IpPermissions'

# Verificar task definition
aws ecs describe-task-definition \
  --task-definition dev-tasks-api \
  --query 'taskDefinition.containerDefinitions[0].environment'
```

### Problema: Lambda não consegue chamar API

**Causa**: URL da API não está correta

**Solução**:
```bash
# Verificar environment variable
aws lambda get-function-configuration \
  --function-name dev-tasks-report \
  --query 'Environment.Variables'

# Atualizar se necessário
aws lambda update-function-configuration \
  --function-name dev-tasks-report \
  --environment Variables={API_GATEWAY_URL=http://new-alb-dns}
```

### Problema: RDS Connection Timeout

**Causa**: Firewall/Security Group bloqueando

**Solução**:
1. Verificar RDS security group permite porta 5432 do ECS SG
2. Verificar RDS está em subnet privada com NAT
3. Verificar subnet route table

```bash
# Validar RDS security group
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx-rds \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==5432]'
```

### Problema: ALB unhealthy targets

**Causa**: Health check falhando

**Solução**:
1. Verificar path `/health` existe na API
2. Verificar security group permite 3000 do ALB SG
3. Verificar logs da aplicação

```bash
# Health check detalhado
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:... \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table
```

---

## 💰 Estimativa de Custos (AWS Free Tier)

| Serviço | Gratuito? | Notas |
|---------|-----------|-------|
| RDS db.t4g.micro | ✅ Sim | 1 instância, 20GB storage |
| ECS Fargate | ✅ Sim | 750 horas/mês |
| ALB | ❌ Não | ~$16/mês + data transfer |
| Lambda | ✅ Sim | 1M requests/mês |
| API Gateway | ✅ Sim | 1M requests/mês |
| NAT Gateway | ❌ Não | ~$32/mês + data transfer |
| ECR | ✅ Sim | 500MB storage |
| CloudWatch | ✅ Sim | 5GB logs/mês |

**Total estimado**: ~$50-80/mês (fora do free tier)

---

## 📚 Referências

- [AWS CloudFormation](https://docs.aws.amazon.com/cloudformation/)
- [ECS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_types.html)
- [RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [API Gateway](https://docs.aws.amazon.com/apigateway/)
- [AWS Lambda](https://docs.aws.amazon.com/lambda/)

---

**Versão**: 1.0  
**Data**: Novembro 2025  
**Projeto**: Mackenzie Cloud Developing
