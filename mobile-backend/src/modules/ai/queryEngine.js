import fetch from 'node-fetch';
import { GoogleGenerativeAI } from '@google/generative-ai';
import OpenAI from 'openai';

const COLLECTION_METADATA = {
    inwards: ['_id', 'lotNo', 'lotName', 'fromParty', 'inwardDate', 'inTime', 'outTime', 'process', 'vehicleNo', 'partyDcNo', 'diaEntries', 'qualityStatus', 'complaintText'],
    outwards: ['_id', 'dcNo', 'lotNo', 'lotName', 'partyName', 'process', 'dateTime', 'inTime', 'outTime', 'vehicleNo', 'items'],
    cuttingorders: ['_id', 'planId', 'planName', 'planType', 'planPeriod', 'lotAllocations', 'status'],
    itemgroups: ['_id', 'groupName', 'itemNames', 'colours', 'gsm'],
    parties: ['_id', 'name', 'address', 'mobileNumber', 'process', 'email'],
    tasks: ['_id', 'title', 'status', 'priority', 'description', 'assignedTo', 'deadline'],
    categories: ['_id', 'name', 'values']
};

const MODELS = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-2.0-pro'
];

async function tryOpenAI(apiKey, question, today, historyText = '') {
  try {
    const schemaDescription = Object.entries(COLLECTION_METADATA)
      .map(([col, fields]) => `- ${col}(${fields.join(', ')})`)
      .join('\n');

    const promptTemplate = (q, date) => `You are a MongoDB expert for 'Om Vinayaka' Garments Inventory System.
  INWARDS: Records of materials received (lotNo, lotName, fromParty, process, inwardDate).
  OUTWARDS: Records of materials shipped (lotNo, lotName, partyName, dateTime).
  CUTTINGORDERS: Production plans (planName, status).
  CATEGORIES: MASTER LISTS for lots, colours, items, etc.

  Convert the user's natural language question (English or Tamil) into a MongoDB JSON query.
  Output ONLY a JSON object with:
  1. "collection": name of collection
  2. "type": "find" or "aggregate"
  3. "query": the query object or aggregation pipeline array

RULES:
- Use regex for all string searches: {"$regex": "...", "$options": "i"}
- "total outward", "how many outwards" -> type: "aggregate", query: [{"$count": "total_outwards"}] or calculations with $sum if they ask for weight/quantity.
- "available lots", "show all lots" -> collection: "categories", query: {"name": "lot name"}, sort by: {"updatedAt": -1}
- "list of parties" -> collection: "parties", query: {}, sort by: {"name": 1}
- "latest 5 inwards" -> type: "aggregate", query: [{"$sort": {"inwardDate": -1}}, {"$limit": 5}]
- Interpret "total" as a request for COUNT or SUM using aggregate pipelines.
- Interpret dates as DD/MM/YYYY. Today is: ${date}.

STRICT RULES:
- If greeting or conceptual garments question, return: {"strategy": "chat"}
- If completely OUTSIDE app scope, return: {"strategy": "out-of-scope"}
- NEVER guess data values. Use regex.

User: "${q}"
JSON:`;

    const prompt = promptTemplate(question, today);
    const openai = new OpenAI({ apiKey });

    const response = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.1,
    });

    const text = response.choices[0].message.content.trim();
    const jsonStr = text.replace(/```json|```/gi, '').trim();
    const mongoQuery = JSON.parse(jsonStr);

    if (mongoQuery.strategy === 'chat' || mongoQuery.strategy === 'out-of-scope') {
      return { strategy: mongoQuery.strategy };
    }

    return { mongoQuery, strategy: 'openai' };
  } catch (error) {
    console.error('OpenAI Error in tryOpenAI:', error.message);
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

    const promptTemplate = (q, date) => `You are a MongoDB expert for 'Om Vinayaka' Garments.
  Convert the user's natural language question (English or Tamil) into a MongoDB JSON query.
  - "total" questions MUST use aggregate pipelines with $count or $sum.
  - "list" questions MUST use sort.
  - Use regex for all string matching.

User: "${q}"
JSON:`;

    const prompt = promptTemplate(question, today);

    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const jsonStr = text.replace(/```json|```/gi, '').trim();
    const mongoQuery = JSON.parse(jsonStr);

    if (mongoQuery.strategy === 'chat' || mongoQuery.strategy === 'out-of-scope') {
      return { strategy: mongoQuery.strategy };
    }

    return { mongoQuery, strategy: 'gemini', modelUsed: modelName };
  } catch (error) {
    console.error('Gemini Error in tryGeminiWithModel:', error.message);
    return null;
  }
}

export async function generateSql(question, historyText = '') {
    const today = new Date().toISOString();

    // User requested to prioritize OpenAI
    const openAiKey = process.env.OPENAI_API_KEY;
    if (openAiKey) {
        const result = await tryOpenAI(openAiKey, question, today, historyText);
        if (result) return result;
    }

    const geminiApiKey = process.env.GEMINI_API_KEY;
    if (geminiApiKey) {
        for (const modelName of MODELS) {
            const result = await tryGeminiWithModel(geminiApiKey, modelName, question, historyText, today);
            if (result) return result;
        }
    }

    return { strategy: 'chat' };
}

