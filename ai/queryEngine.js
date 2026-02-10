import fetch from 'node-fetch';
import { GoogleGenerativeAI } from '@google/generative-ai';
import OpenAI from 'openai';

const COLLECTION_METADATA = {
  inwards: ['_id', 'user', 'inwardDate', 'inTime', 'outTime', 'lotName', 'lotNo', 'fromParty', 'process', 'vehicleNo', 'partyDcNo', 'diaEntries', 'qualityStatus', 'complaintText'],
  outwards: ['_id', 'user', 'dcNo', 'lotName', 'dateTime', 'dia', 'lotNo', 'partyName', 'process', 'address', 'vehicleNo', 'inTime', 'outTime', 'items'],
  products: ['_id', 'user', 'name', 'brand', 'category', 'description', 'price', 'countInStock', 'rating', 'numReviews'],
  assignments: ['_id', 'user', 'fabricItem', 'size', 'dia', 'efficiency', 'dozenWeight'],
  categories: ['_id', 'name', 'values'],
  lot_masters: ['_id', 'lotName', 'lotNo'],
  party_masters: ['_id', 'name', 'address', 'phone', 'process']
};

// Updated for 2026: Exclusively using Gemini 2.x models as 1.x are retired
const MODELS = [
  'gemini-2.0-flash',
  'gemini-2.0-flash-lite',
  'gemini-2.5-flash',
  'gemini-2.0-pro'
];

async function tryOpenAI(apiKey, question, today, historyText = '') {
  try {
    const openai = new OpenAI({ apiKey });

    const schemaDescription = Object.entries(COLLECTION_METADATA)
      .map(([col, fields]) => `- ${col}(${fields.join(', ')})`)
      .join('\n');

    const prompt = `You are a MongoDB expert for a Garments Inventory System.
  INWARDS: Records of materials received.
  OUTWARDS: Records of materials shipped.
  LOTS/PARTIES/PROCESSES: Stored in the 'categories' collection.

  Convert the user's natural language question into a MongoDB JSON query.
  Output ONLY a JSON object with:
  1. "collection": name of collection (must be from the list below)
  2. "type": "find" or "aggregate"
  3. "query": the query object or aggregation pipeline array

COLLECTIONS:
${schemaDescription}

RULES:
- "lot names", "available lots", "list of lots" -> collection: "categories", query: {"name": "lot name"}
- "item names", "items", "available items" -> collection: "categories", query: {"name": "Item name"}
- "party names", "available parties" -> collection: "party_masters"
- "colours", "colors", "available colours" -> collection: "categories", query: {"name": "Colour"}
- "gsm list", "available gsm" -> collection: "categories", query: {"name": "GSM"}
- "processes", "available processes" -> collection: "categories", query: {"name": "Process"}
- "dia list" -> collection: "categories", query: {"name": "Dia"}
- "racks" -> collection: "categories", query: {"name": "Rack"}
- "pallets" -> collection: "categories", query: {"name": "Pallet"}
- "aging report", "lot aging", "aging details" -> collection: "inwards", type: "find", query: {}

- "complaints" or "issues" should map to "complaintText" in inwards.
- "quality" or "status" should map to "qualityStatus" in inwards.
- "date" for inwards refers to "inwardDate", for outwards refers to "dateTime".
- Today\'s Date is: ${today}. Interpret dates as DD/MM/YYYY.
- For single day queries, ALWAYS use a range: {"$gte": "YYYY-MM-DDT00:00:00Z", "$lt": "YYYY-MM-(D+1)DT00:00:00Z"}.
- If the question is purely a greeting or completely off-topic, return: {"strategy": "chat"}
- If the question is about concepts like "What is an inward?", return: {"strategy": "chat"}
- ALWAYS return a JSON query if the user asks for "available", "list", "show", "how many", or specific names.
- Consider the CONVERSATION HISTORY below for context/follow-up.

CONVERSATION HISTORY:
${historyText}

User: "${question}"
JSON:`;

    const response = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.1,
    });

    const text = response.choices[0].message.content.trim();
    const jsonStr = text.replace(/```json|```/gi, '').trim();
    const mongoQuery = JSON.parse(jsonStr);

    if (mongoQuery.strategy === 'chat') {
      return { strategy: 'chat' };
    }

    if (!mongoQuery.collection || !COLLECTION_METADATA[mongoQuery.collection]) {
      throw new Error(`Invalid collection: ${mongoQuery.collection}`);
    }

    return {
      mongoQuery,
      explanation: `Generated via OpenAI (gpt-4o)`,
      strategy: 'openai'
    };
  } catch (error) {
    console.warn(`OpenAI unexpected error:`, error.message);
    return null;
  }
}

async function tryGeminiWithModel(apiKey, modelName, question, historyText = '', today) {
  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: modelName,
      generationConfig: { temperature: 0.1, maxOutputTokens: 600 }
    });

    const schemaDescription = Object.entries(COLLECTION_METADATA)
      .map(([col, fields]) => `- ${col}(${fields.join(', ')})`)
      .join('\n');

    const prompt = `You are a MongoDB expert for a Garments Inventory System.
  INWARDS: Records of materials received.
  OUTWARDS: Records of materials shipped.
  LOTS/PARTIES/PROCESSES: Stored in the 'categories' collection.

  Convert the user's natural language question into a MongoDB JSON query.
  Output ONLY a JSON object with:
  1. "collection": name of collection (must be from the list below)
  2. "type": "find" or "aggregate"
  3. "query": the query object or aggregation pipeline array

COLLECTIONS:
${schemaDescription}

RULES:
- "lot names", "available lots", "list of lots" -> collection: "categories", query: {"name": "lot name"}
- "item names", "items", "available items" -> collection: "categories", query: {"name": "Item name"}
- "party names", "available parties" -> collection: "party_masters"
- "colours", "colors", "available colours" -> collection: "categories", query: {"name": "Colour"}
- "gsm list", "available gsm" -> collection: "categories", query: {"name": "GSM"}
- "processes", "available processes" -> collection: "categories", query: {"name": "Process"}
- "dia list" -> collection: "categories", query: {"name": "Dia"}
- "racks" -> collection: "categories", query: {"name": "Rack"}
- "pallets" -> collection: "categories", query: {"name": "Pallet"}
- "aging report", "lot aging", "aging details" -> collection: "inwards", type: "find", query: {}

- "complaints" or "issues" should map to "complaintText" in inwards.
- "quality" or "status" should map to "qualityStatus" in inwards.
- "date" for inwards refers to "inwardDate", for outwards refers to "dateTime".
- Today\'s Date is: ${today}. Interpret dates as DD/MM/YYYY.
- For single day queries, ALWAYS use a range: {"$gte": "YYYY-MM-DDT00:00:00Z", "$lt": "YYYY-MM-(D+1)DT00:00:00Z"}.
- If the question is purely a greeting or completely off-topic, return: {"strategy": "chat"}
- If the question is about concepts like "What is an inward?", return: {"strategy": "chat"}
- ALWAYS return a JSON query if the user asks for "available", "list", "show", "how many", or specific names.
- Consider the CONVERSATION HISTORY below for context/follow-up.

CONVERSATION HISTORY:
${historyText}

User: "${question}"
JSON:`;

    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const jsonStr = text.replace(/```json|```/gi, '').trim();

    const mongoQuery = JSON.parse(jsonStr);

    if (mongoQuery.strategy === 'chat') {
      return { strategy: 'chat' };
    }

    if (!mongoQuery.collection || !COLLECTION_METADATA[mongoQuery.collection]) {
      throw new Error(`Invalid collection: ${mongoQuery.collection}`);
    }

    return {
      mongoQuery,
      explanation: `Generated via Gemini (${modelName})`,
      strategy: 'gemini',
      modelUsed: modelName
    };
  } catch (error) {
    const msg = error.message.toLowerCase();
    if (msg.includes('404') || msg.includes('not found')) return { error: 'NOT_FOUND' };
    if (msg.includes('429') || msg.includes('quota') || msg.includes('limit')) return { error: 'QUOTA_EXCEEDED' };
    console.warn(`Gemini (${modelName}) unexpected error:`, error.message);
    return null;
  }
}

async function tryOllama(question) {
  const model = process.env.OLLAMA_MODEL || 'llama3';
  try {
    const response = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt: `Convert to MongoDB JSON query for collections ${Object.keys(COLLECTION_METADATA).join(',')}:\n${question}\nJSON:`,
        stream: false
      }),
      timeout: 5000
    });

    if (response.ok) {
      const data = await response.json();
      const text = data.response.trim();
      const jsonStr = text.replace(/```json|```/gi, '').trim();
      return {
        mongoQuery: JSON.parse(jsonStr),
        explanation: 'Generated via local Ollama.',
        strategy: data.strategy === 'chat' ? 'chat' : 'ollama'
      };
    }
  } catch (e) { /* silent */ }
  return null;
}

export async function generateSql(question, historyText = '') {
  const today = new Date().toISOString();
  const openAiKey = process.env.OPENAI_API_KEY;
  if (openAiKey) {
    const result = await tryOpenAI(openAiKey, question, today, historyText);
    if (result) return result;
  }

  const geminiApiKey = process.env.GEMINI_API_KEY;
  if (geminiApiKey) {
    for (const modelName of MODELS) {
      const result = await tryGeminiWithModel(geminiApiKey, modelName, question, historyText, today);
      if (result && !result.error) return result;
      // Try next model if this one is retired (404) or busy (429)
      if (result?.error === 'NOT_FOUND' || result?.error === 'QUOTA_EXCEEDED') continue;
    }
  }

  const ollamaResult = await tryOllama(question);
  if (ollamaResult) return ollamaResult;

  return {
    mongoQuery: { collection: 'products', type: 'find', query: {} },
    explanation: 'System Busy - Fallback to listing products.',
    strategy: 'fallback'
  };
}

export function describeTables() {
  return COLLECTION_METADATA;
}

