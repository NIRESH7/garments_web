import { Router } from 'express';
import { GoogleGenerativeAI } from '@google/generative-ai';
import OpenAI from 'openai';
import { generateSql, describeTables } from '../ai/queryEngine.js';
import mongoose from 'mongoose';
import { ChatMessage, SearchLog } from '../models/historyModel.js';
import { formatResults } from '../utils/resultFormatter.js';

const router = Router();

function detectLanguage(text) {
  const tamilRegex = /[\u0B80-\u0BFF]/;
  return tamilRegex.test(text) ? 'tamil' : 'english';
}

async function askAiFreeForm(question, isOutOfScope = false) {
  const lang = detectLanguage(question);
  const date = new Date().toLocaleDateString('en-GB');
  
  if (isOutOfScope) {
    return lang === 'tamil' 
      ? "இந்த பயன்பாட்டுடன் தொடர்புடைய கேள்விகளுக்கு மட்டுமே நான் பதிலளிக்க முடியும்."
      : "I can only answer questions related to this application.";
  }

  const prompt = `You are a production-grade AI chatbot for a "Garments Inventory System".
  RULES:
  1. Detect the user's language (Tamil/English).
  2. If greeting, respond in the same language.
  3. If conceptual garments question (e.g. "What is an inward?"), explain concisely in the same language.
  4. NEVER guess data.
  5. User Language: ${lang}
  - Use regex for all string searches: {"$regex": "...", "$options": "i"}
  - "total outward", "how many outwards" -> type: "aggregate", query: [{"$count": "total_outwards"}]
  - "available lots", "show all lots" -> collection: "categories", query: {"name": "lot name"}, sort by: {"updatedAt": -1}
  - "list of parties" -> collection: "party_masters", query: {}, sort by: {"name": 1}
  - "latest 5 inwards" -> type: "aggregate", query: [{"$sort": {"inwardDate": -1}}, {"$limit": 5}]
  - Interpret "total" as a request for COUNT or SUM using aggregate pipelines.
  - Interprets dates as DD/MM/YYYY. Today is: ${date}.
  6. User Question: "${question}"
  
  Provide a concise, user-friendly response.`;

  const geminiApiKey = process.env.GEMINI_API_KEY;
  if (geminiApiKey) {
    try {
      const genAI = new GoogleGenerativeAI(geminiApiKey);
      const model = genAI.getGenerativeModel({
        model: 'gemini-2.0-flash',
        generationConfig: { temperature: 0.1, maxOutputTokens: 512 }
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
        temperature: 0.1,
      });
      return response.choices[0].message.content.trim();
    } catch (e) { }
  }

  return lang === 'tamil' ? "மன்னிக்கவும், என்னால் இப்போது பதிலளிக்க முடியவில்லை." : "System busy. Please try again.";
}

async function askAiAboutData(question, rows) {
  const lang = detectLanguage(question);
  const dataStr = JSON.stringify(rows).substring(0, 3000);
  const prompt = `You are an AI for a Garments Inventory System.
  The user asked (Language: ${lang}): "${question}".
  DATABASE RESULTS: ${dataStr}
  
  Instructions:
  1. Summarize the data concisely in ${lang}.
  2. Do NOT add any information NOT present in the database.
  3. If listing items, keep it clear.
  4. Respond only in ${lang}.`;

  const geminiApiKey = process.env.GEMINI_API_KEY;
  if (geminiApiKey) {
    try {
      const genAI = new GoogleGenerativeAI(geminiApiKey);
      const model = genAI.getGenerativeModel({
        model: 'gemini-2.0-flash',
        generationConfig: { temperature: 0.1, maxOutputTokens: 512 }
      });
      const result = await model.generateContent(prompt);
      return result.response.text().trim();
    } catch (e) { }
  }
  return lang === 'tamil' ? `${rows.length} பதிவுகள் கிடைத்தன.` : `I found ${rows.length} records.`;
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
    const lang = detectLanguage(message);
    // 1. Context
    const recent = await ChatMessage.find().sort({ created_at: -1 }).limit(3).lean();
    const historyText = recent.reverse().map(m => `User: ${m.user_message}\nAI: ${m.ai_response}`).join('\n\n');

    // 2. AI Query
    const aiResult = await generateSql(message, historyText).catch(() => ({ strategy: 'err', mongoQuery: null }));

    // 3. Handle Special Strategies
    if (aiResult.strategy === 'out-of-scope') {
      const responseText = await askAiFreeForm(message, true);
      ChatMessage.create({ user_message: message.trim(), ai_response: responseText }).catch(() => { });
      return res.json({ formatted: responseText, strategy: 'out-of-scope', data: [], rowCount: 0 });
    }

    // 4. Mongo Exec
    let rows = [];
    if (aiResult.strategy === 'chat') {
      // General greeting / concept
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
          rows = await db.collection(collection).find(finalQuery).limit(20).toArray(); // LIMIT TO 20
        } else if (type === 'aggregate') {
            const pipeline = Array.isArray(finalQuery) ? finalQuery : [finalQuery];
            if (!pipeline.some(p => p.$limit)) {
                pipeline.push({ $limit: 20 });
            }
          rows = await db.collection(collection).aggregate(pipeline).toArray();
        }
      } catch (e) { console.error('Data Exec Error:', e.message); }
    }

    // 5. Response Generation
    let responseText;
    if (aiResult.strategy === 'chat') {
      responseText = await askAiFreeForm(message);
    } else if (rows.length > 0) {
      const aiSummary = await askAiAboutData(message, rows);
      const formattedTable = formatResults(rows);
      responseText = formattedTable ? `${aiSummary}\n\n${formattedTable}` : aiSummary;
    } else {
      // STRICT FAILURE: NO DATA FOUND
      responseText = lang === 'tamil'
        ? "மன்னிக்கவும், பயன்பாட்டில் தொடர்புடைய தகவல் கிடைக்கவில்லை."
        : "Sorry, I couldn't find relevant information in the app.";
    }

    // 6. Save History
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

