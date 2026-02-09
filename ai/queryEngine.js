import fetch from 'node-fetch';
import { GoogleGenerativeAI } from '@google/generative-ai';

const COLLECTION_METADATA = {
  inwards: ['_id', 'user', 'inwardDate', 'inTime', 'outTime', 'lotName', 'lotNo', 'fromParty', 'process', 'vehicleNo', 'partyDcNo', 'diaEntries'],
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

async function tryGeminiWithModel(apiKey, modelName, question, historyText = '') {
  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: modelName,
      generationConfig: { temperature: 0.1, maxOutputTokens: 600 }
    });

    const schemaDescription = Object.entries(COLLECTION_METADATA)
      .map(([col, fields]) => `- ${col}(${fields.join(', ')})`)
      .join('\n');

    const prompt = `You are a MongoDB expert. Convert the user's natural language question into a MongoDB JSON query.
  Output ONLY a JSON object with:
  1. "collection": name of collection (must be from the list below)
  2. "type": "find" or "aggregate"
  3. "query": the query object or aggregation pipeline array

COLLECTIONS:
${schemaDescription}

RULES:
- For searching name/lot/party, use case-insensitive regex: {"name": {"$regex": "...", "$options": "i"}}
- For Date comparisons, use ISO strings.
- Return ONLY the JSON. No markdown, no explanations.

User: "${question}"
JSON:`;

    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const jsonStr = text.replace(/```json|```/gi, '').trim();

    const mongoQuery = JSON.parse(jsonStr);

    if (!COLLECTION_METADATA[mongoQuery.collection]) {
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
        strategy: 'ollama'
      };
    }
  } catch (e) { /* silent */ }
  return null;
}

export async function generateSql(question, historyText = '') {
  const apiKey = process.env.GEMINI_API_KEY;

  if (apiKey) {
    for (const modelName of MODELS) {
      const result = await tryGeminiWithModel(apiKey, modelName, question, historyText);
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
