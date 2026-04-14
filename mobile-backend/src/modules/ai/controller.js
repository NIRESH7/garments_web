import asyncHandler from 'express-async-handler';
import OpenAI from 'openai';
import { toFile } from 'openai/uploads';
import { File as NodeFile } from 'node:buffer';
import dotenv from 'dotenv';
import mongoose from 'mongoose';
import { generateSql } from './queryEngine.js';
import { formatResults } from '../../utils/resultFormatter.js';
import { GoogleGenerativeAI } from '@google/generative-ai';
import Product from '../product/model.js';

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

async function askAiFreeForm(question, language, productsContext = '', isOutOfScope = false) {
    if (isOutOfScope) {
        return language === 'ta'
            ? "மன்னிக்கவும், இந்த பயன்பாட்டுடன தொடர்புடைய தகவல்களை மட்டுமே என்னால் வழங்க முடியும்."
            : "I can only answer questions related to this application.";
    }

    const prompt = `You are the AI assistant for 'Om Vinayaka' Garments.
    
    PRODUCT DATABASE CONTEXT:
    ${productsContext || 'No specific product data available.'}

    QUESTION: "${question}"
    LANGUAGE: ${language === 'ta' ? 'Tamil' : 'English'}
    
    INSTRUCTIONS:
    1. Answer primarily using the PRODUCT DATABASE CONTEXT if the question is about products.
    2. If the user asks for "shirt", "pant", etc., list them from context.
    3. If they ask for "price", show products with their prices.
    4. If it's a greeting, respond warmly.
    5. Be concise, professional, and helpful.`;

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
        } catch (e) { console.error('AI Error:', e.message); }
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
        // 1. Fetch Product Data for Context (as requested)
        const products = await Product.find().lean();
        const productsContext = products.map(p => 
            `- ${p.name}: ₹${p.price} (${p.category}) - ${p.description}`
        ).join('\n');

        // 2. Try the advanced Query Engine first for structured data
        const aiResult = await generateSql(message).catch(() => ({ strategy: 'chat' }));

        if (aiResult.strategy === 'out-of-scope') {
            const text = await askAiFreeForm(message, language, productsContext, true);
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
                    rows = await cursor.limit(20).toArray();
                } else if (type === 'aggregate') {
                    const pipeline = Array.isArray(finalQuery) ? finalQuery : [finalQuery];
                    if (!pipeline.some(p => p.$limit)) pipeline.push({ $limit: 20 });
                    rows = await db.collection(collection).aggregate(pipeline).toArray();
                }
            } catch (e) { console.error('DB Exec Error:', e.message); }
        }

        let responseText;
        if (aiResult.strategy === 'chat' || (rows.length === 0 && aiResult.strategy === 'openai')) {
            // Use the FreeForm logic with Product context
            responseText = await askAiFreeForm(message, language, productsContext);
        } else if (rows.length > 0) {
            const aiSummary = await askAiAboutData(message, rows, language);
            const table = formatResults(rows);
            responseText = table ? `${aiSummary}\n\n${table}` : aiSummary;
        } else {
            responseText = await askAiFreeForm(message, language, productsContext);
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
