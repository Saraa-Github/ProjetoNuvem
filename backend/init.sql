-- Script SQL para criar a tabela de tarefas
-- Compatível com PostgreSQL (Supabase e RDS)

CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed')),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice para melhorar performance de queries por status
CREATE INDEX idx_tasks_status ON tasks(status);

-- Índice para ordenação por data de criação
CREATE INDEX idx_tasks_created_at ON tasks(created_at DESC);

-- Função para atualizar automaticamente o campo updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar o campo updated_at automaticamente
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Inserir algumas tarefas de exemplo para teste
INSERT INTO tasks (title, description, status, priority) VALUES
    ('Estudar AWS Lambda', 'Revisar o módulo 9 do AWS Academy sobre Lambda functions', 'pending', 'high'),
    ('Configurar RDS', 'Criar instância PostgreSQL no RDS em subnet privada', 'in_progress', 'high'),
    ('Implementar API Gateway', 'Configurar rotas no API Gateway para o CRUD', 'pending', 'medium'),
    ('Documentar arquitetura', 'Criar diagrama da arquitetura no PDF técnico', 'pending', 'medium');
