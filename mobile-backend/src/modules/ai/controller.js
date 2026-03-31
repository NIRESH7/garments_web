import asyncHandler from 'express-async-handler';
import OpenAI from 'openai';
import { toFile } from 'openai/uploads';
import { File as NodeFile } from 'node:buffer';
import dotenv from 'dotenv';
import mongoose from 'mongoose';
import { generateSql } from './queryEngine.js';
import { formatResults } from '../../utils/resultFormatter.js';
import { GoogleGenerativeAI } from '@google/generative-ai';

dotenv.config();

function detectLanguage(text) {
    const tamilRegex = /[\u0B80-\u0BFF]/;
    return tamilRegex.test(text) ? 'ta' : 'en';
}

function castDates(obj) {
    if (Array.isArray(obj)) return obj.map(castDates);
    if (typeof obj !== 'object' || obj === null) return obj;
    
    const newObj = {};
    for (const [key, value] of Object.entries(obj)) {
        if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(value)) {
            newObj[key] = new Date(value);
        } else {
            newObj[key] = castDates(value);
        }
    }
    return newObj;
}

async function askAiAboutData(question, rows, language) {
    const dataStr = JSON.stringify(rows).substring(0, 4000);
    const prompt = `You are the ERP AI for 'Om Vinayaka' Garments.
    User Question (${language}): "${question}"
    DATA: ${dataStr}
    
    INSTRUCTIONS:
    1. Summarize the data in 1-2 clear sentences in ${language === 'ta' ? 'Tamil' : 'English'}.
    2. Be VERY concise.
    3. If there are many items, mention the most important ones.
    4. Do not mention technical IDs.`;

    const geminiApiKey = process.env.GEMINI_API_KEY;
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
        } catch (e) { console.error('OpenAI Summary Error:', e.message); }
    }

    if (geminiApiKey) {
        try {
            const genAI = new GoogleGenerativeAI(geminiApiKey);
            const model = genAI.getGenerativeModel({
                model: 'gemini-2.0-flash',
                generationConfig: { temperature: 0.1, maxOutputTokens: 256 }
            });
            const result = await model.generateContent(prompt);
            return result.response.text().trim();
        } catch (e) { }
    }
    return language === 'ta' ? `${rows.length} பதிவுகளைக் கண்டேன்.` : `I found ${rows.length} records.`;
}

async function askAiFreeForm(question, language, isOutOfScope = false) {
    if (isOutOfScope) {
        return language === 'ta'
            ? "மன்னிக்கவும், இந்த பயன்பாட்டுடன தொடர்புடைய தகவல்களை மட்டுமே என்னால் வழங்க முடியும்."
            : "I can only answer questions related to this application.";
    }

    const prompt = `You are the AI assistant for 'Om Vinayaka' Garments.
    Question: "${question}"
    Language: ${language === 'ta' ? 'Tamil' : 'English'}
    
    1. Greeting? Respond warmly.
    2. Concept? Explain briefly.
    3. Be concise and professional.`;

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
    return language === 'ta' ? "வணக்கம்! நான் உங்கள் ஓம் விநாயகா AI உதவியாளர்." : "Hello! I am your Om Vinayaka AI Assistant.";
}

// Compatibility fallback for Node 18 runtimes.
if (typeof globalThis.File === 'undefined') {
    globalThis.File = NodeFile;
}

const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY || 'dummy_key',
});

/**
 * @desc    Chat with AI about DB data
 * @route   POST /api/ai/chat
 * @access  Private
 */
export const chatWithAI = asyncHandler(async (req, res) => {
    const { message } = req.body;
    const language = detectLanguage(message);

    if (!message) {
        return res.status(400).json({ message: 'Please provide a message' });
    }

    try {
        const aiResult = await generateSql(message).catch(() => ({ strategy: 'chat' }));

        if (aiResult.strategy === 'out-of-scope') {
            const text = await askAiFreeForm(message, language, true);
            return res.json({ text, data: [], strategy: 'out-of-scope' });
        }

        let rows = [];
        if (aiResult.mongoQuery) {
            try {
                const { collection, type, query: mQuery, projection } = aiResult.mongoQuery;
                const db = mongoose.connection.db;
                const finalQuery = castDates(mQuery);

                if (type === 'find') {
                    let cursor = db.collection(collection).find(finalQuery);
                    if (projection && Object.keys(projection).length > 0) {
                        cursor = cursor.project(projection);
                    }
                    rows = await cursor.limit(20).toArray(); // LIMIT TO 20 ROWS
                } else if (type === 'aggregate') {
                    // Inject limit if not present in aggregation
                    const pipeline = Array.isArray(finalQuery) ? finalQuery : [finalQuery];
                    if (!pipeline.some(p => p.$limit)) {
                        pipeline.push({ $limit: 20 });
                    }
                    rows = await db.collection(collection).aggregate(pipeline).toArray();
                }
            } catch (e) { console.error('DB Exec Error:', e.message); }
        }

        let responseText;
        if (aiResult.strategy === 'chat') {
            responseText = await askAiFreeForm(message, language);
        } else if (rows.length > 0) {
            const aiSummary = await askAiAboutData(message, rows, language);
            const table = formatResults(rows);
            responseText = table ? `${aiSummary}\n\n${table}` : aiSummary;
        } else {
            responseText = language === 'ta'
                ? "மன்னிக்கவும், பயன்பாட்டில் தொடர்புடைய தகவல் கிடைக்கவில்லை."
                : "Sorry, I couldn't find relevant information in the app.";
        }

        res.json({ text: responseText, data: rows, strategy: aiResult.strategy });

    } catch (error) {
        console.error('AI Error:', error);
        res.status(500).json({ message: 'AI processing failed' });
    }
});

/**
 * @desc    Transcribe uploaded audio to text
 * @route   POST /api/ai/transcribe
 * @access  Private
 */
export const transcribeAudio = asyncHandler(async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ message: 'Audio file is required' });
    }

    if (!process.env.OPENAI_API_KEY || process.env.OPENAI_API_KEY === 'dummy_key') {
        return res.status(501).json({ message: 'Transcription service is not configured' });
    }

    try {
        const inputLang = (req.body?.language || '').toString().trim().toLowerCase();
        let whisperLang;
        if (inputLang.startsWith('en')) whisperLang = 'en';
        if (inputLang.startsWith('ta')) whisperLang = 'ta';

        const audioFile = await toFile(
            req.file.buffer,
            req.file.originalname || 'voice.m4a'
        );

        const transcript = await openai.audio.transcriptions.create({
            file: audioFile,
            model: 'whisper-1',
            ...(whisperLang ? { language: whisperLang } : {}),
        });

        return res.json({ text: transcript.text || '' });
    } catch (error) {
        console.error('Transcription Error:', error);
        return res.status(500).json({ message: 'Failed to transcribe audio' });
    }
});

// Transcription and other helpers remain as is...
