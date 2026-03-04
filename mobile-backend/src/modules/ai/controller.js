import asyncHandler from 'express-async-handler';
import OpenAI from 'openai';
import { toFile } from 'openai/uploads';
import { File as NodeFile } from 'node:buffer';
import Inward from '../inventory/inwardModel.js';
import Outward from '../inventory/outwardModel.js';
import ProductionOrder from '../production/cuttingOrderModel.js';
import ItemGroup from '../master/itemGroupModel.js';
import Party from '../master/partyModel.js';
import Task from '../task/taskModel.js';
import CuttingOrder from '../production/cuttingOrderModel.js';
import dotenv from 'dotenv';

dotenv.config();

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

    if (!process.env.OPENAI_API_KEY || process.env.OPENAI_API_KEY === 'dummy_key') {
        return await handleRuleBasedChat(message, res, language);
    }

    try {
        // Get context info for the AI - PASS MESSAGE for keyword search
        const context = await getDBContext(message);

        const prompt = `
            You are a highly intelligent ERP Assistant for 'Om Vinayaka' Garments. 
            
            CRITICAL SEARCH INSTRUCTIONS:
            1. The user will ask questions about their business data. You MUST search the DATABASE CONTEXT below thoroughly to find the answer.
            2. Handle spelling mistakes gracefully (e.g., 'availabel' -> 'available', 'qiuestion' -> 'question', 'srecah' -> 'search').
            3. Search through 'found_specific_data' first if the user asked about a specific Lot, DC, or Party.
            4. If the user asks for:
               - "Plans": Search in 'cutting_plans'.
               - "Tasks": Search in 'active_tasks'.
               - "Racks": Search in 'available_racks'.
               - "Parties/Clients": Search in 'party_list'.
               - "Inwards/Lots": Search in 'recent_inwards' and 'counts'.
            5. Provide a friendly, detailed answer based ONLY on the data below. Be extremely precise.
            
            DATABASE CONTEXT:
            ${JSON.stringify(context)}

            USER MESSAGE: "${message}"
            RESPONSE LANGUAGE: ${language === 'ta' ? 'Tamil' : 'English'}
        `;

        const response = await openai.chat.completions.create({
            model: "gpt-3.5-turbo",
            messages: [{ role: "user", content: prompt }],
            max_tokens: 800,
        });

        const aiMessage = response.choices[0].message.content;
        res.json({ text: aiMessage });

    } catch (error) {
        console.error('AI Error:', error);
        await handleRuleBasedChat(message, res, language);
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
        const audioFile = await toFile(
            req.file.buffer,
            req.file.originalname || 'voice.m4a'
        );

        const transcript = await openai.audio.transcriptions.create({
            file: audioFile,
            model: 'whisper-1',
        });

        return res.json({ text: transcript.text || '' });
    } catch (error) {
        console.error('Transcription Error:', error);
        return res.status(500).json({ message: 'Failed to transcribe audio' });
    }
});

async function getDBContext(userMessage = "") {
    try {
        // Fetch summary stats
        const [totalInwards, totalOutwards, totalOrders, totalParties, totalTasks] = await Promise.all([
            Inward.countDocuments(),
            Outward.countDocuments(),
            ProductionOrder.countDocuments(),
            Party.countDocuments(),
            Task.countDocuments()
        ]);

        // Smart Search: Look for specific keywords in message
        let foundSpecificData = {};
        const upperMsg = userMessage.toUpperCase();

        // 1. Search for Lot Numbers (e.g. LOT-201)
        const lotMatch = upperMsg.match(/LOT-[\w-]+/);
        if (lotMatch) {
            const lotNo = lotMatch[0];
            const foundInward = await Inward.findOne({ lotNo: { $regex: lotNo, $options: 'i' } });
            if (foundInward) foundSpecificData.lot_details = foundInward;
        }

        // 2. Search for DC Numbers (e.g. DC-201)
        const dcMatch = upperMsg.match(/DC-[\w-]+/);
        if (dcMatch) {
            const foundOutward = await Outward.findOne({ dcNo: { $regex: dcMatch[0], $options: 'i' } });
            if (foundOutward) foundSpecificData.dc_details = foundOutward;
        }

        // 3. Search for parties
        const parties = await Party.find({}, 'name process mobileNumber');
        for (const p of parties) {
            if (upperMsg.includes(p.name.toUpperCase())) {
                foundSpecificData.mentioned_party = p;
                break;
            }
        }

        // Get Master Data
        const itemGroups = await ItemGroup.find({}, 'groupName itemNames colours gsm');

        // Get Plans/Orders
        const cuttingPlans = await CuttingOrder.find({}, 'planId planName planType planPeriod lotAllocations').limit(10);

        // Extract unique rack names from plans
        const rackNames = new Set();
        cuttingPlans.forEach(plan => {
            plan.lotAllocations.forEach(alloc => {
                if (alloc.rackName) rackNames.add(alloc.rackName);
            });
        });

        // Get Tasks
        const tasks = await Task.find({}, 'title status priority description assignedTo').limit(10);

        // Get recent activity
        const recentInwards = await Inward.find({}).sort({ createdAt: -1 }).limit(5);

        return {
            system: "Om Vinayaka ERP",
            counts: {
                inwards: totalInwards,
                outwards: totalOutwards,
                production_plans: totalOrders,
                parties: totalParties,
                pending_tasks: totalTasks
            },
            found_specific_data: foundSpecificData,
            available_racks: Array.from(rackNames),
            cutting_plans: cuttingPlans.map(p => ({
                id: p.planId,
                name: p.planName,
                type: p.planType,
                period: p.planPeriod,
                racks_used: p.lotAllocations.map(a => a.rackName).filter(Boolean)
            })),
            active_tasks: tasks.map(t => ({
                name: t.title,
                status: t.status,
                priority: t.priority
            })),
            inventory_summary: itemGroups.map(g => ({
                category: g.groupName,
                colors: g.colours,
                gsm: g.gsm
            })),
            party_list: parties.map(p => p.name + ' (' + p.process + ')'),
            recent_inwards: recentInwards.map(i => i.lotNo + ' from ' + i.fromParty)
        };
    } catch (err) {
        console.error('Context Fetch Error:', err);
        return { error: "Could not fetch detailed context" };
    }
}

async function handleRuleBasedChat(message, res, language) {
    const lowerMsg = message.toLowerCase();
    let responseText = "";

    const inwardCount = await Inward.countDocuments().catch(() => 0);

    if (language === 'ta') {
        if (lowerMsg.includes('வணக்கம்') || lowerMsg.includes('hi') || lowerMsg.includes('hello')) {
            responseText = "வணக்கம்! நான் உங்கள் ERP உதவியாளர். உங்களுக்கு எப்படி உதவ முடியும்?";
        } else if (lowerMsg.includes('inward') || lowerMsg.includes('இன்வர்ட்')) {
            responseText = `மொத்த இன்வர்ட் எண்ணிக்கை: ${inwardCount}.`;
        } else {
            responseText = "மன்னிக்கவும், AI சேவை வரம்புக்குட்பட்டது. இன்வர்ட் பற்றி கேளுங்கள்.";
        }
    } else {
        if (lowerMsg.includes('hi') || lowerMsg.includes('hello')) {
            responseText = "Hello! I am your ERP assistant. How can I help you today?";
        } else if (lowerMsg.includes('inward')) {
            responseText = `Total Inwards: ${inwardCount}.`;
        } else {
            responseText = "Basic mode active. Try asking 'total inwards'.";
        }
    }

    res.json({ text: responseText, note: "Rule-based fallback." });
}
