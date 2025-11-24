import { Router } from 'express';
import { generateSql, describeTables } from '../ai/queryEngine.js';
import { query } from '../config/db.js';
import { formatResults } from '../utils/resultFormatter.js';

const router = Router();

router.get('/health', (_req, res) => {
  res.json({ status: 'ok', tables: describeTables() });
});

router.get('/history', async (_req, res) => {
  try {
    const rows = await query(
      'SELECT question, generated_sql, created_at FROM search_history ORDER BY created_at DESC LIMIT 10;'
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch history', details: error.message });
  }
});

router.post('/', async (req, res) => {
  const { message } = req.body || {};
  if (!message || !message.trim()) {
    return res.status(400).json({ error: 'Message is required.' });
  }

  try {
    const aiResult = await generateSql(message);
    const rows = await query(aiResult.sql);
    await query('INSERT INTO search_history(question, generated_sql) VALUES (?, ?);', [
      message.trim(),
      aiResult.sql
    ]);

    res.json({
      sql: aiResult.sql,
      strategy: aiResult.strategy,
      explanation: aiResult.explanation,
      data: rows,
      formatted: formatResults(rows)
    });
  } catch (error) {
    console.error('Chat route error:', error);
    res.status(500).json({
      error: 'Unable to answer the question.',
      details: error.message
    });
  }
});

export default router;

