#!/bin/bash

##############################################################################
# Script de Deployment - CloudFormation
# Projeto Integrador Cloud Developing Mackenzie
#
# Uso:
#   ./deploy.sh create [environment] [db-password]
#   ./deploy.sh update [environment]
#   ./deploy.sh delete [environment]
#   ./deploy.sh describe [environment]
#
# Exemplo:
#   ./deploy.sh create dev "MySecurePassword123!"
#   ./deploy.sh update dev
#   ./deploy.sh delete dev
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/cloudformation-template.yaml"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Validação
if [ $# -lt 2 ]; then
    echo "Uso: $0 [create|update|delete|describe] [environment] [db-password (apenas create)]"
    echo ""
    echo "Exemplos:"
    echo "  $0 create dev 'MyPassword123!'"
    echo "  $0 update dev"
    echo "  $0 delete dev"
    echo "  $0 describe dev"
    exit 1
fi

ACTION=$1
ENVIRONMENT=$2
DB_PASSWORD=$3

STACK_NAME="${ENVIRONMENT}-tasks-stack"

# Verificar se template existe
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Template não encontrado: $TEMPLATE_FILE"
    exit 1
fi

# ==================== CREATE ====================
if [ "$ACTION" = "create" ]; then
    print_header "Criando Stack CloudFormation: $STACK_NAME"

    if [ -z "$DB_PASSWORD" ]; then
        print_error "Senha do RDS é obrigatória para criar a stack"
        exit 1
    fi

    if [ ${#DB_PASSWORD} -lt 12 ]; then
        print_error "Senha deve ter no mínimo 12 caracteres"
        exit 1
    fi

    print_info "Ambiente: $ENVIRONMENT"
    print_info "Senha RDS: ******* (${#DB_PASSWORD} caracteres)"

    echo ""
    read -p "Deseja continuar? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warning "Operação cancelada"
        exit 0
    fi

    print_info "Criando stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters \
            "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
            "ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region us-east-1

    print_success "Stack criada com sucesso!"
    print_info "Aguardando criação... (você pode monitorar no console AWS)"

    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region us-east-1 2>/dev/null || true

    print_success "Stack $STACK_NAME criada!"

# ==================== UPDATE ====================
elif [ "$ACTION" = "update" ]; then
    print_header "Atualizando Stack: $STACK_NAME"

    print_info "Ambiente: $ENVIRONMENT"
    echo ""
    read -p "Deseja continuar? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warning "Operação cancelada"
        exit 0
    fi

    print_info "Atualizando stack..."
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters \
            "ParameterKey=EnvironmentName,UsePreviousValue=true" \
            "ParameterKey=DBPassword,UsePreviousValue=true" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region us-east-1 || {
            print_warning "Nenhuma mudança detectada ou erro ao atualizar"
        }

    print_success "Stack atualizada!"

# ==================== DELETE ====================
elif [ "$ACTION" = "delete" ]; then
    print_header "Deletando Stack: $STACK_NAME"

    print_warning "ATENÇÃO: Esta operação é irreversível!"
    print_warning "Isto deletará todos os recursos (RDS, ECS, ALB, etc)"
    echo ""
    read -p "Digite o nome da stack ($STACK_NAME) para confirmar: " confirm
    if [ "$confirm" != "$STACK_NAME" ]; then
        print_warning "Operação cancelada"
        exit 0
    fi

    print_info "Deletando stack..."
    aws cloudformation delete-stack \
        --stack-name "$STACK_NAME" \
        --region us-east-1

    print_success "Stack deletada!"
    print_info "Aguardando deleção..."

    aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME" \
        --region us-east-1 2>/dev/null || true

# ==================== DESCRIBE ====================
elif [ "$ACTION" = "describe" ]; then
    print_header "Informações da Stack: $STACK_NAME"

    # Verificar status
    stack_info=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region us-east-1 \
        --query 'Stacks[0].[StackStatus,CreationTime,StackName]' \
        --output json 2>/dev/null || echo "null")

    if [ "$stack_info" = "null" ]; then
        print_error "Stack não encontrada"
        exit 1
    fi

    echo ""
    print_info "Listando Outputs:"
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region us-east-1 \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table

    echo ""
    print_info "Listando Recursos:"
    aws cloudformation list-stack-resources \
        --stack-name "$STACK_NAME" \
        --region us-east-1 \
        --query 'StackResourceSummaries[*].[LogicalResourceId,ResourceType,ResourceStatus]' \
        --output table

else
    print_error "Ação desconhecida: $ACTION"
    exit 1
fi
