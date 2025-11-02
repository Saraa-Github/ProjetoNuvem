
"""
AWS Lambda Function - Report Generator
Projeto Integrador Cloud Developing Mackenzie

Esta função consome a API via API Gateway e retorna estatísticas em JSON.
Não acessa diretamente o RDS, apenas consome o endpoint /tasks da API.

Environment Variables necessárias:
- API_GATEWAY_URL: URL base do API Gateway (ex: https://xxxxx.execute-api.region.amazonaws.com/prod)
"""

import json
import http.client
from urllib.parse import urlparse
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def call_api(url, method='GET'):
    """
    Faz requisição HTTP para a API via API Gateway

    Args:
        url (str): URL completa do endpoint
        method (str): Método HTTP (GET, POST, etc)

    Returns:
        dict: Resposta JSON da API ou None em caso de erro
    """
    try:
        logger.info(f'Chamando API: {method} {url}')

        parsed_url = urlparse(url)

        # Determinar porta baseado no esquema
        port = 443 if parsed_url.scheme == 'https' else 80

        if parsed_url.scheme == 'https':
            conn = http.client.HTTPSConnection(parsed_url.netloc, port, timeout=10)
        else:
            conn = http.client.HTTPConnection(parsed_url.netloc, port, timeout=10)

        # Construir path com query string se existir
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


def generate_report(api_gateway_url):
    """
    Gera relatório de estatísticas consumindo a API

    Args:
        api_gateway_url (str): URL base do API Gateway

    Returns:
        dict: Estatísticas calculadas
    """

    # Chamar API para obter todas as tarefas
    tasks_url = f'{api_gateway_url}/tasks'
    api_response = call_api(tasks_url)

    if not api_response or 'data' not in api_response:
        logger.warning('Não foi possível obter dados da API')
        return {
            'success': False,
            'error': 'Não foi possível obter dados da API',
            'timestamp': datetime.utcnow().isoformat()
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
        'average_priority': None,
        'oldest_task': None,
        'newest_task': None,
        'tasks_in_progress_count': 0,
        'high_priority_pending': 0,
    }

    if len(tasks) > 0:
        # Contar por status
        for task in tasks:
            status = task.get('status', 'pending')
            priority = task.get('priority', 'medium')

            if status in stats['tasks_by_status']:
                stats['tasks_by_status'][status] += 1

            if priority in stats['tasks_by_priority']:
                stats['tasks_by_priority'][priority] += 1

            # Contar tarefas em progresso
            if status == 'in_progress':
                stats['tasks_in_progress_count'] += 1

            # Contar tarefas de alta prioridade pendentes
            if status == 'pending' and priority == 'high':
                stats['high_priority_pending'] += 1

        # Calcular taxa de conclusão
        completed = stats['tasks_by_status']['completed']
        stats['completion_rate'] = round((completed / len(tasks)) * 100, 2)

        # Encontrar tarefa mais antiga e mais recente
        try:
            tasks_sorted_by_date = sorted(
                tasks,
                key=lambda t: t.get('created_at', ''),
                reverse=False
            )
            stats['oldest_task'] = {
                'id': tasks_sorted_by_date[0].get('id'),
                'title': tasks_sorted_by_date[0].get('title'),
                'created_at': tasks_sorted_by_date[0].get('created_at')
            }

            tasks_sorted_by_date.reverse()
            stats['newest_task'] = {
                'id': tasks_sorted_by_date[0].get('id'),
                'title': tasks_sorted_by_date[0].get('title'),
                'created_at': tasks_sorted_by_date[0].get('created_at')
            }
        except Exception as e:
            logger.error(f'Erro ao processar datas: {str(e)}')

        # Calcular prioridade média (low=1, medium=2, high=3)
        priority_values = []
        for task in tasks:
            priority = task.get('priority', 'medium')
            if priority == 'low':
                priority_values.append(1)
            elif priority == 'medium':
                priority_values.append(2)
            elif priority == 'high':
                priority_values.append(3)

        if priority_values:
            avg_priority = sum(priority_values) / len(priority_values)
            stats['average_priority'] = round(avg_priority, 2)

            # Converter para label
            if avg_priority < 1.5:
                stats['average_priority_label'] = 'Baixa'
            elif avg_priority < 2.5:
                stats['average_priority_label'] = 'Média'
            else:
                stats['average_priority_label'] = 'Alta'

    return stats


def lambda_handler(event, context):
    """
    AWS Lambda Handler

    Event esperado:
    {
        "resource": "/report",
        "requestContext": {...}
    }
    """

    try:
        logger.info(f'Recebido evento: {json.dumps(event)}')

        # Obter URL da API Gateway das variáveis de ambiente
        api_gateway_url = context.get_remaining_time_in_millis
        # Melhor forma: obter do environment ou do event

        # Para production, usar variável de ambiente
        import os
        api_gateway_url = os.environ.get('API_GATEWAY_URL')

        if not api_gateway_url:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'success': False,
                    'error': 'API_GATEWAY_URL não configurada'
                })
            }

        logger.info(f'Gerando relatório... API_GATEWAY_URL: {api_gateway_url}')

        # Gerar relatório
        report = generate_report(api_gateway_url)

        return {
            'statusCode': 200 if report.get('total_tasks') is not None else 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': True,
                'message': 'Relatório gerado com sucesso',
                'data': report,
                'generated_at': datetime.utcnow().isoformat()
            }, indent=2)
        }

    except Exception as e:
        logger.error(f'Erro na Lambda: {str(e)}', exc_info=True)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'success': False,
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }
