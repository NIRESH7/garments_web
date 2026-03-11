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

async function askAiAboutData(question, rows, language) {
    const dataStr = JSON.stringify(rows).substring(0, 2000);
    const prompt = `The user asked: "${question}". \nHere is the data found in the database: \n${dataStr}\n\nProvide a short, conversational summary of this data in ${language === 'ta' ? 'Tamil' : 'English'}. Be concise and helpful.`;

    if (process.env.OPENAI_API_KEY) {
        try {
            const response = await openai.chat.completions.create({
                model: "gpt-3.5-turbo",
                messages: [{ role: "user", content: prompt }],
                temperature: 0.4,
                max_tokens: 512,
            });
            return response.choices[0].message.content.trim();
        } catch (e) {
            console.error('OpenAI Error in askAiAboutData:', e.message);
        }
    }

    // Fallback if no OpenAPI Key or if it fails
    const geminiApiKey = process.env.GEMINI_API_KEY;
    if (geminiApiKey) {
        try {
            const genAI = new GoogleGenerativeAI(geminiApiKey);
            const model = genAI.getGenerativeModel({
                model: 'gemini-1.5-flash',
                generationConfig: { temperature: 0.4, maxOutputTokens: 512 }
            });
            const result = await model.generateContent(prompt);
            return result.response.text().trim();
        } catch (e) { }
    }
    return `I found ${rows.length} records matching your request.`;
}

async function askAiFreeForm(question, language) {
    const prompt = `You are the AI ERP assistant for 'Om Vinayaka' Garments. 
    The user asked: "${question}". 
    
    INSTRUCTIONS:
    - If the user said a greeting ("hi", "hello", "hii", "hey"), reply with a friendly, welcoming message. Introduce yourself as their Om Vinayaka ERP Assistant and ask how you can help them with their data today.
    - If they asked a general question about how you work, briefly explain you can search their inwards, outwards, lots, and parties.
    - If it seems they were searching for something specific but you didn't get any data, suggest they try asking about 'available lots', 'recent inwards', or 'list of parties'.
    
    Answer concisely in ${language === 'ta' ? 'Tamil' : 'English'}.`;

    if (process.env.OPENAI_API_KEY) {
        try {
            const response = await openai.chat.completions.create({
                model: "gpt-3.5-turbo",
                messages: [{ role: "user", content: prompt }],
                temperature: 0.6,
                max_tokens: 512,
            });
            return response.choices[0].message.content.trim();
        } catch (e) {
            console.error('OpenAI Error in askAiFreeForm:', e.message);
        }
    }

    const geminiApiKey = process.env.GEMINI_API_KEY;
    if (geminiApiKey) {
        try {
            const genAI = new GoogleGenerativeAI(geminiApiKey);
            const model = genAI.getGenerativeModel({
                model: 'gemini-1.5-flash',
                generationConfig: { temperature: 0.6, maxOutputTokens: 512 }
            });
            const result = await model.generateContent(prompt);
            return result.response.text().trim();
        } catch (e) { }
    }
    return "Hello! I am your Om Vinayaka AI Assistant. Ask me anything about your business data.";
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
    const { message, language = 'en' } = req.body;

    if (!message) {
        return res.status(400).json({ message: 'Please provide a message' });
    }

    try {
        // 1. AI Intent/Query Generation
        const aiResult = await generateSql(message).catch(() => ({ strategy: 'chat' }));

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
                    rows = await cursor.limit(50).toArray();
                } else if (type === 'aggregate') {
                    if (projection && Object.keys(projection).length > 0) {
                        finalQuery.push({ $project: projection });
                    }
                    rows = await db.collection(collection).aggregate(finalQuery).toArray();
                }
            } catch (e) {
                console.error('Data Exec Error:', e.message);
            }
        }

        // 2. Response Generation
        let responseText;
        if (rows.length > 0) {
            const aiSummary = await askAiAboutData(message, rows, language);
            responseText = `${aiSummary}\n\n${formatResults(rows)}`;
        } else {
            responseText = await askAiFreeForm(message, language);
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
