import asyncHandler from 'express-async-handler';
import OpenAI from 'openai';
import Inward from '../inventory/inwardModel.js';
import Outward from '../inventory/outwardModel.js';
import ProductionOrder from '../production/cuttingOrderModel.js';
import ItemGroup from '../master/itemGroupModel.js';
import Party from '../master/partyModel.js';
import dotenv from 'dotenv';

dotenv.config();

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

    if (!process.env.OPENAI_API_KEY) {
        return await handleRuleBasedChat(message, res, language);
    }

    try {
        // Get context info for the AI
        const context = await getDBContext();

        const prompt = `
            You are a helpful assistant for a Garments ERP system called 'Om Vinayaka'.
            Current Database Context:
            ${JSON.stringify(context)}

            User asked: "${message}"
            Language: ${language === 'ta' ? 'Tamil' : 'English'}

            Answer the user's question based ONLY on the context provided. 
            If the information is not in the context, say "I don't have that information in my database right now." or the Tamil equivalent.
            Keep the answer short and professional.
            If language is Tamil ('ta'), respond in Tamil script.
        `;

        const response = await openai.chat.completions.create({
            model: "gpt-3.5-turbo",
            messages: [{ role: "user", content: prompt }],
            max_tokens: 500,
        });

        const aiMessage = response.choices[0].message.content;
        res.json({ text: aiMessage });

    } catch (error) {
        console.error('AI Error:', error);
        await handleRuleBasedChat(message, res, language);
    }
});

async function getDBContext() {
    // Fetch summary stats
    const totalInwards = await Inward.countDocuments();
    const totalOutwards = await Outward.countDocuments();
    const totalOrders = await ProductionOrder.countDocuments();
    const totalParties = await Party.countDocuments();

    // Get item names and group names from ItemGroup
    const itemGroups = await ItemGroup.find({}, 'groupName itemNames colours');

    // Get party names
    const parties = await Party.find({}, 'name mobileNumber process');

    // Get today's activity
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayInwards = await Inward.countDocuments({ createdAt: { $gte: today } });
    const todayOutwards = await Outward.countDocuments({ createdAt: { $gte: today } });

    return {
        counts: {
            total_inwards: totalInwards,
            total_outwards: totalOutwards,
            total_production_orders: totalOrders,
            total_parties: totalParties,
            inwards_today: todayInwards,
            outwards_today: todayOutwards
        },
        inventory_items: itemGroups.map(g => ({
            group: g.groupName,
            items: g.itemNames,
            available_colours: g.colours
        })),
        clients_parties: parties.map(p => ({
            name: p.name,
            contact: p.mobileNumber,
            type: p.process
        })),
        app_name: "Om Vinayaka Garments"
    };
}

async function handleRuleBasedChat(message, res, language) {
    const lowerMsg = message.toLowerCase();
    let responseText = "";

    if (language === 'ta') {
        if (lowerMsg.includes('வணக்கம்') || lowerMsg.includes('hi') || lowerMsg.includes('hello')) {
            responseText = "வணக்கம்! நான் உங்கள் உதவியாளர். நான் உங்களுக்கு எப்படி உதவ முடியும்?";
        } else if (lowerMsg.includes('inward') || lowerMsg.includes('இன்வர்ட்')) {
            const count = await Inward.countDocuments();
            responseText = `மொத்த இன்வர்ட் எண்ணிக்கை: ${count}.`;
        } else if (lowerMsg.includes('item') || lowerMsg.includes('பொருள்')) {
            const items = await ItemGroup.find({}, 'groupName');
            const names = items.map(i => i.groupName).join(", ");
            responseText = `கிடைக்கக்கூடிய பொருட்கள்: ${names}.`;
        } else {
            responseText = "மன்னிக்கவும், எனக்குப் புரியவில்லை. தயவுசெய்து இன்வர்ட் அல்லது பொருட்கள் பற்றி கேளுங்கள்.";
        }
    } else {
        if (lowerMsg.includes('hi') || lowerMsg.includes('hello')) {
            responseText = "Hello! I am your ERP assistant. How can I help you today?";
        } else if (lowerMsg.includes('inward')) {
            const count = await Inward.countDocuments();
            responseText = `Total Inwards: ${count}.`;
        } else if (lowerMsg.includes('item') || lowerMsg.includes('items')) {
            const items = await ItemGroup.find({}, 'groupName');
            const names = items.map(i => i.groupName).join(", ");
            responseText = `Available Item Groups: ${names}.`;
        } else {
            responseText = "I am currently in basic mode. Try asking about Inwards or Items.";
        }
    }

    res.json({ text: responseText, note: "Rule-based fallback used." });
}
