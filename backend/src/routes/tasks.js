
import express from 'express';
import { query } from '../config/database.js';

const router = express.Router();

// GET /tasks - Listar todas as tarefas
router.get('/', async (req, res) => {
  try {
    const { status, priority } = req.query;
    
    let queryText = 'SELECT * FROM tasks';
    const queryParams = [];
    const conditions = [];

    // Filtros opcionais
    if (status) {
      conditions.push(`status = $${conditions.length + 1}`);
      queryParams.push(status);
    }
    if (priority) {
      conditions.push(`priority = $${conditions.length + 1}`);
      queryParams.push(priority);
    }

    if (conditions.length > 0) {
      queryText += ' WHERE ' + conditions.join(' AND ');
    }

    queryText += ' ORDER BY created_at DESC';

    const result = await query(queryText, queryParams);
    
    res.json({
      success: true,
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Erro ao buscar tarefas:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao buscar tarefas',
      message: error.message
    });
  }
});

// GET /tasks/:id - Buscar uma tarefa específica
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await query(
      'SELECT * FROM tasks WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tarefa não encontrada'
      });
    }

    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erro ao buscar tarefa:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao buscar tarefa',
      message: error.message
    });
  }
});

// POST /tasks - Criar nova tarefa
router.post('/', async (req, res) => {
  try {
    const { title, description, status, priority } = req.body;

    // Validação básica
    if (!title || title.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'O título da tarefa é obrigatório'
      });
    }

    const result = await query(
      `INSERT INTO tasks (title, description, status, priority) 
       VALUES ($1, $2, $3, $4) 
       RETURNING *`,
      [
        title.trim(),
        description?.trim() || null,
        status || 'pending',
        priority || 'medium'
      ]
    );

    res.status(201).json({
      success: true,
      message: 'Tarefa criada com sucesso',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erro ao criar tarefa:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao criar tarefa',
      message: error.message
    });
  }
});

// PUT /tasks/:id - Atualizar tarefa completa
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, status, priority } = req.body;

    // Validação básica
    if (!title || title.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'O título da tarefa é obrigatório'
      });
    }

    const result = await query(
      `UPDATE tasks 
       SET title = $1, description = $2, status = $3, priority = $4
       WHERE id = $5 
       RETURNING *`,
      [
        title.trim(),
        description?.trim() || null,
        status || 'pending',
        priority || 'medium',
        id
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tarefa não encontrada'
      });
    }

    res.json({
      success: true,
      message: 'Tarefa atualizada com sucesso',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erro ao atualizar tarefa:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao atualizar tarefa',
      message: error.message
    });
  }
});

// PATCH /tasks/:id - Atualizar parcialmente uma tarefa
router.patch('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    // Campos permitidos para atualização
    const allowedFields = ['title', 'description', 'status', 'priority'];
    const updateFields = [];
    const updateValues = [];

    Object.keys(updates).forEach((key, index) => {
      if (allowedFields.includes(key) && updates[key] !== undefined) {
        updateFields.push(`${key} = $${index + 1}`);
        updateValues.push(updates[key]);
      }
    });

    if (updateFields.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Nenhum campo válido para atualizar'
      });
    }

    updateValues.push(id);

    const result = await query(
      `UPDATE tasks SET ${updateFields.join(', ')} WHERE id = $${updateValues.length} RETURNING *`,
      updateValues
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tarefa não encontrada'
      });
    }

    res.json({
      success: true,
      message: 'Tarefa atualizada com sucesso',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erro ao atualizar tarefa:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao atualizar tarefa',
      message: error.message
    });
  }
});

// DELETE /tasks/:id - Deletar tarefa
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await query(
      'DELETE FROM tasks WHERE id = $1 RETURNING *',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tarefa não encontrada'
      });
    }

    res.json({
      success: true,
      message: 'Tarefa deletada com sucesso',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erro ao deletar tarefa:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao deletar tarefa',
      message: error.message
    });
  }
});

export default router;
