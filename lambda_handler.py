
"""
AWS Lambda Function - Report Generator
Projeto Integrador Cloud Developing Mackenzie

Esta função consome a API via API Gateway e retorna estatísticas em JSON.
Não acessa diretamente o RDS, apenas consome o endpoint /tasks da API.

Environment Variables necessárias:
- API_GATEWAY_URL: URL base do API Gateway (ex: https://xxxxx.execute-api.region.amazonaws.com/prod)
"""

import https from 'https';
import http from 'http';

export const handler = async (event) => {
    const API_URL = 'http://10.0.1.241:3000/tasks';
    
    try {
        const data = await makeHttpRequest(API_URL);
        const parsedData = JSON.parse(data);
        
        const report = generateReport(parsedData);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(report)
        };
        
    } catch (error) {
        console.error('Erro ao buscar dados:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                error: 'Erro ao processar requisição',
                message: error.message
            })
        };
    }
};

function makeHttpRequest(url) {
    return new Promise((resolve, reject) => {
        http.get(url, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                if (res.statusCode === 200) {
                    resolve(data);
                } else {
                    reject(new Error(`Status Code: ${res.statusCode}`));
                }
            });
            
        }).on('error', (error) => {
            reject(error);
        });
    });
}

function generateReport(apiResponse) {
    const { success, count, data } = apiResponse;
    
    // Estatísticas por status
    const statusStats = data.reduce((acc, task) => {
        acc[task.status] = (acc[task.status] || 0) + 1;
        return acc;
    }, {});
    
    // Estatísticas por prioridade
    const priorityStats = data.reduce((acc, task) => {
        acc[task.priority] = (acc[task.priority] || 0) + 1;
        return acc;
    }, {});
    
    // Tarefas mais recentes (top 5)
    const recentTasks = [...data]
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .slice(0, 5)
        .map(task => ({
            id: task.id,
            title: task.title,
            status: task.status,
            priority: task.priority,
            created_at: task.created_at
        }));
    
    return {
        summary: {
            success,
            totalTasks: count,
            generatedAt: new Date().toISOString()
        },
        statistics: {
            byStatus: statusStats,
            byPriority: priorityStats
        },
        recentTasks,
        fullData: data
    };
}
