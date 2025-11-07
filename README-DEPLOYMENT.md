# Projeto Integrador - Cloud Developing 2025/1

Lista de Tarefas + AWS (EC2 + Lambda + RDS + API Gateway)

## 📋 Visão Geral

Sistema de **gerenciamento de tarefas** com backend Node.js/Express, banco de dados PostgreSQL e infraestrutura AWS completa, incluindo:

- ✅ **Backend API**: Express.js com CRUD completo
- ✅ **Banco de Dados**: AWS RDS PostgreSQL (subnet privada)
- ✅ **Containerização**: Docker
- ✅ **API Gateway**: Proxy simples + rota /report
- ✅ **Serverless**: AWS Lambda para gerar relatórios
- ✅ **Rede Segura**: VPC com subnets públicas/privadas

## Escopo do Projeto

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

Projeto Integrador - Cloud Developing 2025/1
Lista de Tarefas + AWS (EC2 + Lambda + RDS + API Gateway)

📋 Visão Geral
Sistema de gerenciamento de tarefas com backend Node.js/Express, banco de dados PostgreSQL em RDS, container Docker em EC2, API Gateway e Lambda para relatórios.
Toda infraestrutura foi criada manualmente pelo console da AWS, sem uso de automação ou templates. Cada recurso foi configurado individualmente: instância EC2, RDS PostgreSQL, API Gateway e Lambda.​

Serviços Utilizados
EC2 (Docker): Backend Node.js/Express rodando em container Docker, exposto na porta 3000 via Security Group configurado manualmente.​

RDS PostgreSQL: Instância criada em subnet privada, liberada apenas para o Security Group da EC2, exigindo conexão SSL (DB_SSL=true no .env).​

API Gateway: Proxy direto para EC2 (endpoints CRUD) e rota /report integrada ao Lambda.

Lambda: Função criada para consumir estatísticas da API e gerar o relatório.

Estrutura do Repositório
text
projeto-integrador/
├── backend/
│   ├── src/
│   └── Dockerfile
├── lambda/
│   └── handler.js
└── README.md
Guia de Deploy Manual
1. EC2 (Backend)
Criar instância EC2 (Amazon Linux)

Instalar Docker

Clonar o projeto e configurar .env com dados do RDS

Rodar container:

bash
docker build -t backend-api .
docker run -p 3000:3000 --env-file .env backend-api
Liberar portas: SSH e HTTP para testes, TCP personalizado porta 3000. Configure o Security Group para permitir acesso à porta 3000 de forma restrita (por IP fonte ou API Gateway).​

2. RDS (Banco de Dados)
Criar instância PostgreSQL em subnet privada

Anotar endpoint, usuário, senha

Liberar acesso ao Security Group da EC2 (porta 5432)

Habilitar conexão SSL (DB_SSL=true)

3. API Gateway
Criar API REST

Configurar proxy para EC2 na porta 3000 (rota /tasks)

Criar rota /report integrada à Lambda

4. Lambda
Criar função com runtime Node.js

Adicionar código para consumir estatísticas do backend via API Gateway

Configurar variável de ambiente API_URL com o endpoint da API

Fluxos de Requisições
CRUD: Cliente → API Gateway → EC2 (Docker) → RDS

Relatório: Cliente → API Gateway (/report) → Lambda → EC2 (Docker) → RDS → Lambda → JSON estatísticas

Segurança
RDS em subnet privada sem acesso externo

Security Groups das instâncias EC2 e RDS configurados manualmente

Credenciais sensíveis protegidas (.env não publicado)

API Gateway expõe apenas o mínimo necessário

Dificuldades e Observações
O backend exigiu configuração SSL explícita para conectar ao RDS (DB_SSL=true)

O Lambda foi adaptado para Node.js pelo limite do ambiente disponível, reescrevendo a lógica do relatório

Todos recursos (incluindo regras dos Security Groups) foram criados manualmente conforme documentação técnica​

Grupo
Gabriel Nóbrega Neri — Infraestrutura/Backend

Maria Clara Torres Ramos — Vídeo/Testes

Matheus Ramalho Malícia — Backend/Infraestrutura

Sara Oliveira Silva Omena — Backend/API Gateway

Tamires Mendes da Silva — Lambda/Documentação

Versão: 1.0
Data: Novembro 2025
Projeto: Mackenzie - Cloud Developing 2025/1

Basta copiar este README – já adequado ao modo de deploy manual e sua configuração real.​
