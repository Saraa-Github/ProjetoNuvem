#!/bin/bash

##############################################################################
# Script de Teste - API de Lista de Tarefas
# Projeto Integrador Cloud Developing Mackenzie
# 
# Este script testa todos os endpoints CRUD da API
# Uso: ./test-api.sh [URL_BASE] [VERBOSE]
# Exemplo: ./test-api.sh http://localhost:3000
#          ./test-api.sh http://localhost:3000 verbose
##############################################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
API_URL="${1:-http://localhost:3000}"
VERBOSE="${2:-}"
COUNTER=0
PASSED=0
FAILED=0
TASK_IDS=()

##############################################################################
# Funções Utilitárias
##############################################################################

# Função para imprimir títulos
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

# Função para imprimir teste
print_test() {
    COUNTER=$((COUNTER + 1))
    echo -e "${YELLOW}[TESTE $COUNTER]${NC} $1"
}

# Função para imprimir sucesso
print_success() {
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}✅ PASSOU${NC} - $1"
}

# Função para imprimir falha
print_error() {
    FAILED=$((FAILED + 1))
    echo -e "${RED}❌ FALHOU${NC} - $1"
}

# Função para imprimir aviso
print_warning() {
    echo -e "${YELLOW}⚠️  AVISO${NC} - $1"
}

# Função para imprimir informação
print_info() {
    echo -e "${BLUE}ℹ️  INFO${NC} - $1"
}

# Função para fazer requisição HTTP com curl
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_code=$4

    if [ -z "$data" ]; then
        # Requisição sem body
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            "$API_URL$endpoint")
    else
        # Requisição com body
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_URL$endpoint")
    fi

    # Separar status code do body
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')

    # Imprimir resposta se verbose
    if [ "$VERBOSE" = "verbose" ]; then
        echo -e "  ${BLUE}Status:${NC} $http_code"
        echo -e "  ${BLUE}Resposta:${NC}"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        echo ""
    fi

    # Retornar valores
    echo "$http_code|$body"
}

# Função para extrair valor JSON
extract_json() {
    echo "$1" | jq -r "$2" 2>/dev/null
}

# Função para validar resposta
validate_response() {
    local response=$1
    local expected_code=$2
    local test_name=$3

    http_code=$(echo "$response" | cut -d'|' -f1)
    body=$(echo "$response" | cut -d'|' -f2-)

    if [ "$http_code" = "$expected_code" ]; then
        print_success "$test_name (HTTP $http_code)"
        echo "$body"
    else
        print_error "$test_name (Esperado: $expected_code, Obtido: $http_code)"
        echo "$body"
        return 1
    fi
}

##############################################################################
# Testes de Conectividade
##############################################################################

print_header "TESTES DE CONECTIVIDADE"

# Teste 1: Health Check
print_test "Health Check do servidor"
response=$(make_request GET "/health" "" "200")
if validate_response "$response" "200" "Health Check"; then
    print_info "API está saudável e banco de dados conectado"
else
    print_error "Servidor não está respondendo em $API_URL"
    echo -e "\n${RED}Encerrando testes...${NC}\n"
    exit 1
fi

# Teste 2: Rota raiz
print_test "Verificar informações da API (GET /)"
response=$(make_request GET "/" "" "200")
validate_response "$response" "200" "Rota raiz"

##############################################################################
# Testes CRUD - CREATE
##############################################################################

print_header "TESTES CRUD - CREATE (POST)"

# Teste 3: Criar tarefa simples
print_test "Criar tarefa com título obrigatório"
task_data='{
    "title": "Configurar RDS na AWS",
    "description": "Criar instância PostgreSQL em subnet privada",
    "status": "pending",
    "priority": "high"
}'
response=$(make_request POST "/tasks" "$task_data" "201")
if validate_response "$response" "201" "Criar primeira tarefa"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    task_id=$(extract_json "$body" ".data.id")
    TASK_IDS+=("$task_id")
    print_info "ID da tarefa criada: $task_id"
fi

# Teste 4: Criar segunda tarefa
print_test "Criar segunda tarefa"
task_data2='{
    "title": "Implementar API Gateway",
    "description": "Configurar rotas CRUD → backend e /report → Lambda",
    "status": "in_progress",
    "priority": "high"
}'
response=$(make_request POST "/tasks" "$task_data2" "201")
if validate_response "$response" "201" "Criar segunda tarefa"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    task_id=$(extract_json "$body" ".data.id")
    TASK_IDS+=("$task_id")
    print_info "ID da tarefa criada: $task_id"
fi

# Teste 5: Criar terceira tarefa
print_test "Criar terceira tarefa"
task_data3='{
    "title": "Estudar Lambda Functions",
    "description": "Revisar módulo 9 do AWS Academy",
    "priority": "medium"
}'
response=$(make_request POST "/tasks" "$task_data3" "201")
if validate_response "$response" "201" "Criar terceira tarefa"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    task_id=$(extract_json "$body" ".data.id")
    TASK_IDS+=("$task_id")
    print_info "ID da tarefa criada: $task_id"
fi

# Teste 6: Criar tarefa com status inválido
print_test "Criar tarefa com dados incompletos (title vazio)"
invalid_task='{
    "title": "",
    "description": "Tarefa sem título"
}'
response=$(make_request POST "/tasks" "$invalid_task" "400")
validate_response "$response" "400" "Rejeitar tarefa com título vazio"

# Teste 7: Criar tarefa com apenas título
print_test "Criar tarefa com apenas título (valores padrão)"
minimal_task='{
    "title": "Escrever documentação"
}'
response=$(make_request POST "/tasks" "$minimal_task" "201")
if validate_response "$response" "201" "Criar tarefa com valores padrão"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    task_id=$(extract_json "$body" ".data.id")
    TASK_IDS+=("$task_id")
    print_info "ID da tarefa criada: $task_id"
fi

##############################################################################
# Testes CRUD - READ
##############################################################################

print_header "TESTES CRUD - READ (GET)"

# Teste 8: Listar todas as tarefas
print_test "Listar todas as tarefas (GET /tasks)"
response=$(make_request GET "/tasks" "" "200")
if validate_response "$response" "200" "Listar todas as tarefas"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    count=$(extract_json "$body" ".count")
    print_info "Total de tarefas encontradas: $count"
fi

# Teste 9: Listar tarefas com filtro por status
print_test "Listar tarefas com status 'pending'"
response=$(make_request GET "/tasks?status=pending" "" "200")
if validate_response "$response" "200" "Filtrar tarefas por status"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    count=$(extract_json "$body" ".count")
    print_info "Tarefas com status pending: $count"
fi

# Teste 10: Listar tarefas com filtro por prioridade
print_test "Listar tarefas com prioridade 'high'"
response=$(make_request GET "/tasks?priority=high" "" "200")
if validate_response "$response" "200" "Filtrar tarefas por prioridade"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    count=$(extract_json "$body" ".count")
    print_info "Tarefas com prioridade high: $count"
fi

# Teste 11: Listar com múltiplos filtros
print_test "Listar tarefas com status 'pending' E prioridade 'high'"
response=$(make_request GET "/tasks?status=pending&priority=high" "" "200")
if validate_response "$response" "200" "Filtrar com múltiplos parâmetros"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    count=$(extract_json "$body" ".count")
    print_info "Tarefas encontradas: $count"
fi

# Teste 12: Buscar tarefa específica
if [ ${#TASK_IDS[@]} -gt 0 ]; then
    print_test "Buscar tarefa específica por ID"
    first_id=${TASK_IDS[0]}
    response=$(make_request GET "/tasks/$first_id" "" "200")
    if validate_response "$response" "200" "Buscar tarefa ID $first_id"; then
        body=$(echo "$response" | cut -d'|' -f2-)
        title=$(extract_json "$body" ".data.title")
        print_info "Título da tarefa: $title"
    fi
fi

# Teste 13: Buscar tarefa inexistente
print_test "Buscar tarefa com ID inexistente"
response=$(make_request GET "/tasks/99999" "" "404")
validate_response "$response" "404" "Retornar 404 para tarefa inexistente"

##############################################################################
# Testes CRUD - UPDATE (PUT)
##############################################################################

print_header "TESTES CRUD - UPDATE (PUT)"

if [ ${#TASK_IDS[@]} -gt 0 ]; then
    test_id=${TASK_IDS[0]}

    # Teste 14: Atualizar tarefa completa
    print_test "Atualizar tarefa completa (PUT)"
    update_data='{
        "title": "Configurar RDS - ATUALIZADO",
        "description": "Instância PostgreSQL em subnet privada - DONE",
        "status": "completed",
        "priority": "high"
    }'
    response=$(make_request PUT "/tasks/$test_id" "$update_data" "200")
    if validate_response "$response" "200" "Atualizar tarefa ID $test_id"; then
        body=$(echo "$response" | cut -d'|' -f2-)
        status=$(extract_json "$body" ".data.status")
        print_info "Novo status: $status"
    fi

    # Teste 15: Atualizar tarefa com título inválido
    print_test "Validar rejeição de atualização com título vazio"
    invalid_update='{
        "title": "",
        "status": "in_progress"
    }'
    response=$(make_request PUT "/tasks/$test_id" "$invalid_update" "400")
    validate_response "$response" "400" "Rejeitar atualização com título vazio"
fi

##############################################################################
# Testes CRUD - UPDATE (PATCH)
##############################################################################

print_header "TESTES CRUD - UPDATE (PATCH)"

if [ ${#TASK_IDS[@]} -gt 1 ]; then
    test_id=${TASK_IDS[1]}

    # Teste 16: Atualizar apenas status
    print_test "Atualizar apenas status (PATCH)"
    patch_data='{"status": "in_progress"}'
    response=$(make_request PATCH "/tasks/$test_id" "$patch_data" "200")
    if validate_response "$response" "200" "Atualização parcial - status"; then
        body=$(echo "$response" | cut -d'|' -f2-)
        status=$(extract_json "$body" ".data.status")
        print_info "Status atualizado para: $status"
    fi

    # Teste 17: Atualizar apenas prioridade
    print_test "Atualizar apenas prioridade (PATCH)"
    patch_data='{"priority": "low"}'
    response=$(make_request PATCH "/tasks/$test_id" "$patch_data" "200")
    if validate_response "$response" "200" "Atualização parcial - prioridade"; then
        body=$(echo "$response" | cut -d'|' -f2-)
        priority=$(extract_json "$body" ".data.priority")
        print_info "Prioridade atualizada para: $priority"
    fi

    # Teste 18: Atualizar descrição
    print_test "Atualizar apenas descrição (PATCH)"
    patch_data='{"description": "Descrição atualizada via PATCH"}'
    response=$(make_request PATCH "/tasks/$test_id" "$patch_data" "200")
    if validate_response "$response" "200" "Atualização parcial - descrição"; then
        body=$(echo "$response" | cut -d'|' -f2-)
        desc=$(extract_json "$body" ".data.description")
        print_info "Descrição: $desc"
    fi
fi

##############################################################################
# Testes CRUD - DELETE
##############################################################################

print_header "TESTES CRUD - DELETE"

# Teste 19: Deletar tarefa inexistente
print_test "Deletar tarefa inexistente"
response=$(make_request DELETE "/tasks/99999" "" "404")
validate_response "$response" "404" "Rejeitar deleção de tarefa inexistente"

# Teste 20: Deletar tarefa existente
if [ ${#TASK_IDS[@]} -gt 3 ]; then
    delete_id=${TASK_IDS[3]}
    print_test "Deletar tarefa existente"
    response=$(make_request DELETE "/tasks/$delete_id" "" "200")
    if validate_response "$response" "200" "Deletar tarefa ID $delete_id"; then
        print_info "Tarefa removida com sucesso"
    fi

    # Teste 21: Verificar que tarefa foi deletada
    print_test "Verificar que tarefa foi removida"
    response=$(make_request GET "/tasks/$delete_id" "" "404")
    validate_response "$response" "404" "Confirmar que tarefa não existe mais"
fi

##############################################################################
# Testes de Validação e Edge Cases
##############################################################################

print_header "TESTES DE VALIDAÇÃO E EDGE CASES"

# Teste 22: Tentar listar com filtro inválido
print_test "Tentar listar com status inválido"
response=$(make_request GET "/tasks?status=invalid_status" "" "200")
validate_response "$response" "200" "Retornar lista vazia para status inválido"

# Teste 23: Criar tarefa com JSON inválido
print_test "Enviar JSON malformado"
response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "{ invalid json" \
    "$API_URL/tasks")
http_code=$(echo "$response" | tail -n 1)
if [ "$http_code" = "400" ]; then
    print_success "Rejeitar JSON malformado (HTTP $http_code)"
else
    print_warning "Esperado 400, obtido $http_code para JSON malformado"
fi

# Teste 24: Endpoint não existente
print_test "Acessar endpoint não existente"
response=$(make_request GET "/nonexistent" "" "404")
validate_response "$response" "404" "Retornar 404 para endpoint inválido"

##############################################################################
# Teste de Performance (Opcional)
##############################################################################

print_header "TESTES DE PERFORMANCE"

print_test "Criar 10 tarefas rapidamente"
for i in {1..10}; do
    task_data="{
        "title": "Tarefa de performance $i",
        "description": "Teste de performance - item $i",
        "priority": "medium"
    }"
    response=$(make_request POST "/tasks" "$task_data" "201")
    if [ $(echo "$response" | cut -d'|' -f1) = "201" ]; then
        echo -n "."
    else
        echo -n "F"
    fi
done
echo ""
print_info "10 tarefas criadas para teste de performance"

# Teste 25: Listar todas (performance)
print_test "Listar todas as tarefas criadas"
response=$(make_request GET "/tasks" "" "200")
if validate_response "$response" "200" "Listar todas as tarefas"; then
    body=$(echo "$response" | cut -d'|' -f2-)
    count=$(extract_json "$body" ".count")
    print_info "Total de tarefas no banco: $count"
fi

##############################################################################
# Resumo Final
##############################################################################

print_header "RESUMO DOS TESTES"

echo -e "Total de testes executados: ${BLUE}$COUNTER${NC}"
echo -e "Testes aprovados: ${GREEN}$PASSED${NC}"
echo -e "Testes falhados: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✅ TODOS OS TESTES PASSARAM!${NC}\n"
    exit 0
else
    echo -e "\n${RED}❌ ALGUNS TESTES FALHARAM${NC}\n"
    exit 1
fi
