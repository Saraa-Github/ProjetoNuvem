
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

Backend Express.js rodando em EC2 (com Docker)

Banco de dados PostgreSQL no AWS RDS (subnet privada)

API Gateway (proxy + rota /report)

Relatórios gerados via AWS Lambda

Atenção:
Toda a infraestrutura foi configurada manualmente no painel da AWS, sem automação via CloudFormation ou ECS Fargate. Cada recurso foi criado individualmente: EC2, Docker, RDS PostgreSQL, API Gateway e Lambda.​

Serviços Utilizados
RDS PostgreSQL: instância criada em subnet privada, conectada manualmente.

EC2: backend rodando em container Docker com Node/Express.

API Gateway: expõe os endpoints CRUD e rota /report.

Lambda: função para estatísticas (relatório), integrando via API Gateway.

Estrutura Simplificada do Repositório
text
projeto-integrador/
├── backend/                # API Node.js/Express
│   ├── src/
│   └── Dockerfile
├── lambda/                 # Função Lambda
│   └── handler.js          # Código em Node.js
└── README.md               # Este documento
Guia de Uso
1. Backend Local (teste/Dev)
bash
cd backend
npm install
cp .env.example .env # Configurar dados do RDS
npm run dev
# ou via Docker
docker build -t backend-api .
docker run -p 3000:3000 --env-file .env backend-api
2. Deploy Manual AWS
EC2
Criar nova instância EC2 (Amazon Linux)

Instalar Docker

Clonar o projeto

Rodar backend via Docker

RDS
Criar instância PostgreSQL (subnet privada)

Anotar endpoint, usuário e senha

Liberar acesso ao EC2 pelo Security Group

Exigir conexão SSL (DB_SSL=true no .env)

API Gateway
Criar API REST

Configurar proxy para EC2:3000 (/tasks)

Configurar rota /report integrada à função Lambda

Lambda
Criar função Lambda (Node.js)

Código em JavaScript para consumir e processar dados da API

Definir variável de ambiente API_URL com endpoint da API Gateway

Testar retorno das estatísticas.​

Fluxo das Requisições
CRUD
Cliente → API Gateway → EC2 com Docker → RDS

Relatório
Cliente → API Gateway (/report) → Lambda → EC2 (Docker) → RDS → Lambda processa → Retorna estatísticas

Exemplos de Endpoints
Listar tarefas: GET /tasks

Criar tarefa: POST /tasks

Atualizar: PUT /tasks/:id

Deletar: DELETE /tasks/:id

Relatório: GET /report (Resumo do banco)

Segurança
RDS em subnet privada, sem acesso externo

EC2 com Security Groups limitados

Credenciais sensíveis nunca expostas em código

SSL habilitado entre backend e RDS

Dificuldades e Observações
O backend em EC2 exigiu ajuste manual para conexão SSL com o RDS (campo DB_SSL=true no .env).

Lambda foi adaptado para rodar com Node.js devido limitações do runtime.

Toda operação/teste (inclusive integração entre serviços) foi realizada manualmente pelo console AWS.​

Grupo
Gabriel Nóbrega Neri — Infraestrutura/Backend

Maria Clara Torres Ramos — Vídeo/Testes

Matheus Ramalho Malícia — Backend/Infraestrutura

Sara Oliveia Silva Omena — Backend/API Gateway

Tamires Mendes da Silva — Lambda/Documentação

Data: Novembro 2025
Projeto: Mackenzie - Cloud Developing 2025/1

Basta copiar, ajustar usuários/endpoints e colar no seu repositório!.​
