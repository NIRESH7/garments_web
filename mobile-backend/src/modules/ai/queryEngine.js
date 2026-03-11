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
        const openai = new OpenAI({ apiKey });

        const schemaDescription = Object.entries(COLLECTION_METADATA)
            .map(([col, fields]) => `- ${col}(${fields.join(', ')})`)
            .join('\n');

        const prompt = `You are a MongoDB expert for 'Om Vinayaka' Garments Inventory System.
  INWARDS: Records of materials received.
  OUTWARDS: Records of materials shipped/dispatched.
  CUTTINGORDERS: Production plans and lot allocations.
  PARTIES: Supplier and customer details.
  TASKS: System/Workflow tasks.
  CATEGORIES: Master lists for lots, processes, etc.

  Convert the user's natural language question into a MongoDB JSON query.
  Output ONLY a JSON object with:
  1. "collection": name of collection (from the list below)
  2. "type": "find" or "aggregate"
  3. "query": the query object or aggregation pipeline array
  4. "projection": ALWAYS include a MongoDB projection object (e.g. {"name": 1, "_id": 0}) to retrieve ONLY the exact fields the user asked for. Do not return unnecessary fields. If they ask for "all details", leave projection as {}.

COLLECTIONS:
${schemaDescription}

RULES:
- Handle typos and misspellings smoothly (e.g. "vaaoilable colour" -> "available colours", "hiio" -> "hello", "tek" -> "tell").
- "last", "latest", "recent" -> ALWAYS use a query with {"$sort": {"createdAt": -1}} or date field, and {"$limit": 5} (or 1 if they asked for just 'last').
- "lot names", "available lots", "inward lots" -> collection: "categories", query: {"name": "lot name"}
- "party names", "available parties", "tell me ll party name" -> collection: "parties"
- "processes", "available processes" -> collection: "categories", query: {"name": "Process"}
- "colours", "colors", "available colours" -> collection: "itemgroups", query: {}
- "complaints" or "issues" -> map to "complaintText" in inwards.
- "quality status" -> map to "qualityStatus" in inwards.
- "date" for inwards refers to "inwardDate", for outwards refers to "dateTime".
- Today's Date is: ${today}.
- For single day queries, use a range: {"$gte": "YYYY-MM-DDT00:00:00Z", "$lt": "YYYY-MM-(D+1)DT00:00:00Z"}.

CRITICAL INTENT RULES:
- ONLY return {"strategy": "chat"} if the user is strictly saying a greeting ("hi", "hello", "what's up", "good morning") OR an off-topic question ("how are you").
- If the text is a fragmented phrase like "available colour", "lot names", "party name" etc, this IS a database query. Assume they want to list those items and generate a valid MongoDB query object.
- Do NOT return {"strategy": "chat"} for anything referring to records, inventory, names, lots, processes, colours, or inwards/outwards.

User: "${question}"
JSON:`;

        const response = await openai.chat.completions.create({
            model: "gpt-3.5-turbo",
            messages: [{ role: "user", content: prompt }],
            temperature: 0.1,
        });

        const text = response.choices[0].message.content.trim();
        const jsonStr = text.replace(/```json|```/gi, '').trim();
        const mongoQuery = JSON.parse(jsonStr);

        if (mongoQuery.strategy === 'chat') return { strategy: 'chat' };

        return { mongoQuery, strategy: 'openai' };
    } catch (error) {
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

        const prompt = `You are a MongoDB expert for 'Om Vinayaka' Garments.
  Convert the user's question to a MongoDB JSON query.
  COLLECTIONS:
${schemaDescription}

  RULES:
  - Handle spelling mistakes gracefully (e.g. "vaaoilable" -> "available").
  - "last", "latest", "recent" -> ALWAYS use an aggregate pipeline with $sort and $limit. Follow strict MongoDB syntax.
  - "colours" -> collection: "itemgroups"
  - "lot names" -> collection: "categories", query: {"name": "lot name"}
  - "parties" -> collection: "parties"
  
  CRITICAL: 
  - ONLY return {"strategy": "chat"} if the user is literally just saying a greeting ("hi", "hello", "good morning") OR an off-topic question.
  - If the user types a fragmented phrase like "available colour", "lot names", "party name", this IS a database query. Generate a query to fetch them.
  - Output ONLY a JSON object with: {"collection": "...", "type": "find/aggregate", "query": ..., "projection": {...}}
  - You MUST include a "projection" object to return ONLY the specific fields requested by the user (exclude _id if not needed).
  
  Today's Date is: ${today}.
  
  User: "${question}"
  JSON:`;

        const result = await model.generateContent(prompt);
        const text = result.response.text().trim();
        const jsonStr = text.replace(/```json|```/gi, '').trim();
        const mongoQuery = JSON.parse(jsonStr);

        if (mongoQuery.strategy === 'chat') return { strategy: 'chat' };

        return { mongoQuery, strategy: 'gemini', modelUsed: modelName };
    } catch (error) {
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

