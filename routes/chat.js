import { Router } from 'express';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { generateSql, describeTables } from '../ai/queryEngine.js';
import mongoose from 'mongoose';
import { ChatMessage, SearchLog } from '../models/historyModel.js';
import { formatResults } from '../utils/resultFormatter.js';

const router = Router();

async function askGeminiFreeForm(question) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return "AI unavailable (Missing API Key).";

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.0-flash',
      generationConfig: { temperature: 0.4, maxOutputTokens: 512 }
    });

    const prompt = `Explain that no matching data was found for "${question}" in the garments database. Give 3 short search suggestions.`;
    const result = await model.generateContent(prompt);
    return result.response.text().trim();
  } catch (error) {
    if (error.message.includes('429') || error.message.includes('quota')) return "AI Quota limit reached. Please try in a minute.";
    if (error.message.includes('404')) return "AI Model error (retired). Switching to fallback...";
    return "No records found. Try: 'all products', 'total weight', 'lot deepak'.";
  }
}

router.get('/health', (_req, res) => {
  res.json({ status: 'ok', collections: describeTables() });
});

router.get('/history', async (_req, res) => {
  try {
    const logs = await SearchLog.find().sort({ created_at: -1 }).limit(10).lean();
    res.json(logs);
  } catch (e) { res.status(500).json({ error: 'Failed' }); }
});

router.get('/messages', async (_req, res) => {
  try {
    const msgs = await ChatMessage.find().sort({ created_at: 1 }).limit(50).lean();
    res.json(msgs);
  } catch (e) { res.status(500).json({ error: 'Failed' }); }
});

router.post('/', async (req, res) => {
  const { message } = req.body || {};
  if (!message?.trim()) return res.status(400).json({ error: 'Empty message' });

  try {
    // 1. Context
    const recent = await ChatMessage.find().sort({ created_at: -1 }).limit(3).lean();
    const historyText = recent.reverse().map(m => `User: ${m.user_message}\nAI: ${m.ai_response}`).join('\n\n');

    // 2. AI Query
    const aiResult = await generateSql(message, historyText).catch(() => ({ strategy: 'err', mongoQuery: null }));

    // 3. Mongo Exec
    let rows = [];
    if (aiResult.mongoQuery) {
      try {
        const { collection, type, query: mQuery } = aiResult.mongoQuery;
        const db = mongoose.connection.db;
        if (type === 'find') {
          rows = await db.collection(collection).find(mQuery).limit(50).toArray();
        } else {
          rows = await db.collection(collection).aggregate(mQuery).toArray();
        }
      } catch (e) { console.error('Data Exec Error:', e.message); }
    }

    // 4. Response
    let responseText = rows.length > 0 ? formatResults(rows) : await askGeminiFreeForm(message);

    // 5. Save History
    ChatMessage.create({ user_message: message.trim(), ai_response: responseText }).catch(() => { });
    if (aiResult.mongoQuery) SearchLog.create({ question: message.trim(), generated_query: aiResult.mongoQuery }).catch(() => { });

    res.json({
      mongoQuery: aiResult.mongoQuery,
      strategy: aiResult.strategy,
      data: rows,
      formatted: responseText,
      rowCount: rows.length
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal Error', details: error.message });
  }
});

export default router;
