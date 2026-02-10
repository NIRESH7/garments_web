import { Router } from 'express';
import { GoogleGenerativeAI } from '@google/generative-ai';
import OpenAI from 'openai';
import { generateSql, describeTables } from '../ai/queryEngine.js';
import mongoose from 'mongoose';
import { ChatMessage, SearchLog } from '../models/historyModel.js';
import { formatResults } from '../utils/resultFormatter.js';

const router = Router();

async function askAiFreeForm(question) {
  const prompt = `You are the AI assistant for a "Garments Inventory System".
  DATABASE CONTEXT:
  - Inwards: Records of fabric/materials received (date, party, lot, complaints).
  - Outwards: Records of materials shipped/dispatched.
  - Lots: Unique batches of fabric.
  - Masters: Parties (suppliers/customers) and Lot names.

  User message: "${question}"
  
  If this is a greeting or general system question, answer naturally. 
  If it is a conceptual question (e.g. "Inward vs Outward"), explain the difference in inventory terms.
  If it sounds like they were trying to search for specific data that doesn't exist, explain no matching data was found in this inventory records and suggest 3 short, RELEVANT search ideas (e.g. asking for specific lots, parties or dates).
  
  Be concise and helpful.`;

  const geminiApiKey = process.env.GEMINI_API_KEY;
  if (geminiApiKey) {
    try {
      const genAI = new GoogleGenerativeAI(geminiApiKey);
      const model = genAI.getGenerativeModel({
        model: 'gemini-2.0-flash',
        generationConfig: { temperature: 0.4, maxOutputTokens: 512 }
      });
      const result = await model.generateContent(prompt);
      return result.response.text().trim();
    } catch (error) { }
  }

  const openAiKey = process.env.OPENAI_API_KEY;
  if (openAiKey) {
    try {
      const openai = new OpenAI({ apiKey: openAiKey });
      const response = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.4,
      });
      return response.choices[0].message.content.trim();
    } catch (e) { }
  }

  return "I'm your garments database assistant. Try asking about 'inwards', 'lot numbers', or 'complaints'.";
}

async function askAiAboutData(question, rows) {
  const dataStr = JSON.stringify(rows).substring(0, 2000);
  const prompt = `The user asked: "${question}". \nHere is the data found in the database: \n${dataStr}\n\nProvide a very short, conversational summary of this data. If it is a list, just say what you found. Be concise and helpful.`;

  const geminiApiKey = process.env.GEMINI_API_KEY;
  if (geminiApiKey) {
    try {
      const genAI = new GoogleGenerativeAI(geminiApiKey);
      const model = genAI.getGenerativeModel({
        model: 'gemini-2.0-flash',
        generationConfig: { temperature: 0.4, maxOutputTokens: 512 }
      });
      const result = await model.generateContent(prompt);
      return result.response.text().trim();
    } catch (e) { }
  }
  return `I found ${rows.length} records matching your request.`;
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
    if (aiResult.strategy === 'chat') {
      // It's a general question, handled by skip to Response section
    } else if (aiResult.mongoQuery) {
      try {
        const { collection, type, query: mQuery } = aiResult.mongoQuery;

        // Recursive function to cast ISO date strings to Date objects
        const castDates = (obj) => {
          if (!obj || typeof obj !== 'object') return obj;
          for (let key in obj) {
            if (typeof obj[key] === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(obj[key])) {
              obj[key] = new Date(obj[key]);
            } else if (typeof obj[key] === 'object') {
              castDates(obj[key]);
            }
          }
          return obj;
        };

        const db = mongoose.connection.db;
        const finalQuery = castDates(mQuery);

        if (type === 'find') {
          rows = await db.collection(collection).find(finalQuery).limit(50).toArray();
        } else {
          rows = await db.collection(collection).aggregate(finalQuery).toArray();
        }
      } catch (e) { console.error('Data Exec Error:', e.message); }
    }

    // 4. Response
    let responseText;
    if (aiResult.strategy === 'chat') {
      responseText = await askAiFreeForm(message);
    } else if (rows.length > 0) {
      const aiSummary = await askAiAboutData(message, rows);
      // Always combine AI summary with formatted data to ensure user sees the actual records
      responseText = `${aiSummary}\n\n${formatResults(rows)}`;
    } else {
      responseText = await askAiFreeForm(message);
    }

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

