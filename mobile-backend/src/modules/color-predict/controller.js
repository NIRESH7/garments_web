import asyncHandler from 'express-async-handler';
import OpenAI from 'openai';

const SYSTEM_PROMPT = `You are a garment dyeing expert with 20+ years experience in textile dyeing.

Based on the given dye recipe details, estimate the resulting garment color.
Do NOT give theory or explanations.
Return ONLY valid JSON, nothing else.

OUTPUT FORMAT (STRICT JSON):
{
  "colorName": "<practical garment industry color name>",
  "shadeLevel": "light | medium | dark",
  "tone": "warm | cool | neutral",
  "hexColor": "#RRGGBB",
  "rgb": "rgb(R, G, B)",
  "confidence": "low | medium",
  "note": "Approximate result. Actual shade may vary."
}

Rules:
- Return ONLY the JSON object, no markdown, no explanation
- Use practical garment industry color names (e.g., "Navy Blue", "Olive Green", "Dusty Rose")
- hexColor must be a valid 6-digit hex color code
- rgb must match the hexColor values
- Consider dye percentage for shade depth (low % = lighter, high % = darker)
- Consider fabric type effect (cotton absorbs more, polyester is brighter)
- Consider chemical effects (high salt = deeper shade, acetic acid = slightly washed)
- Consider GSM (higher GSM = deeper absorption)`;

// Simple local fallback prediction
function localPredict({ fabricType, fabricGSM, dyeType, dyePercentage, dyeNames, saltPercentage }) {
    const dyeColorMap = {
        'red': { r: 200, g: 30, b: 30, name: 'Red', tone: 'warm' },
        'blue': { r: 20, g: 50, b: 180, name: 'Royal Blue', tone: 'cool' },
        'yellow': { r: 240, g: 200, b: 20, name: 'Golden Yellow', tone: 'warm' },
        'black': { r: 25, g: 25, b: 25, name: 'Jet Black', tone: 'neutral' },
        'green': { r: 30, g: 140, b: 50, name: 'Forest Green', tone: 'cool' },
        'orange': { r: 240, g: 120, b: 20, name: 'Orange', tone: 'warm' },
        'brown': { r: 140, g: 80, b: 30, name: 'Chocolate Brown', tone: 'warm' },
        'navy': { r: 10, g: 20, b: 80, name: 'Navy Blue', tone: 'cool' },
        'pink': { r: 230, g: 80, b: 130, name: 'Hot Pink', tone: 'warm' },
        'violet': { r: 120, g: 30, b: 140, name: 'Violet', tone: 'cool' },
        'maroon': { r: 100, g: 15, b: 25, name: 'Maroon', tone: 'warm' },
        'grey': { r: 120, g: 120, b: 120, name: 'Grey', tone: 'neutral' },
        'white': { r: 250, g: 250, b: 250, name: 'White', tone: 'neutral' },
    };

    const lowerNames = dyeNames.toLowerCase();
    let match = null;
    for (const [key, val] of Object.entries(dyeColorMap)) {
        if (lowerNames.includes(key)) {
            match = val;
            break;
        }
    }

    if (!match) {
        match = { r: 128, g: 128, b: 128, name: 'Unknown Blend', tone: 'neutral' };
    }

    let shadeLevel = 'medium';
    if (dyePercentage <= 1.0) shadeLevel = 'light';
    else if (dyePercentage >= 3.0) shadeLevel = 'dark';

    const depthFactor = Math.min(dyePercentage / 5.0, 1.0);
    let r = Math.round(match.r + (255 - match.r) * (1 - depthFactor));
    let g = Math.round(match.g + (255 - match.g) * (1 - depthFactor));
    let b = Math.round(match.b + (255 - match.b) * (1 - depthFactor));

    r = Math.max(0, Math.min(255, r));
    g = Math.max(0, Math.min(255, g));
    b = Math.max(0, Math.min(255, b));

    const hex = `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`.toUpperCase();

    return {
        colorName: `${shadeLevel === 'light' ? 'Light ' : shadeLevel === 'dark' ? 'Dark ' : ''}${match.name}`,
        shadeLevel,
        tone: match.tone,
        hexColor: hex,
        rgb: `rgb(${r}, ${g}, ${b})`,
        confidence: 'low',
        note: 'Approximate result from fallback. Actual shade may vary.',
        source: 'fallback',
    };
}

// @desc    Predict garment color from dye recipe using AI
// @route   POST /api/color-predict
// @access  Private
const predictColor = asyncHandler(async (req, res) => {
    const {
        fabricType,
        fabricGSM,
        dyeType,
        dyePercentage,
        dyeNames,
        saltPercentage,
        sodaAshPercentage,
        aceticAcidPercentage,
        otherChemicals
    } = req.body;

    if (!dyeNames || (Array.isArray(dyeNames) && dyeNames.length === 0)) {
        res.status(400);
        throw new Error('dyeNames is required');
    }

    const dyeNamesList = Array.isArray(dyeNames) ? dyeNames.join(', ') : dyeNames;

    const userPrompt = `INPUT:
FabricType: ${fabricType || 'cotton'}
FabricGSM: ${fabricGSM || 160}
DyeType: ${dyeType || 'reactive'}
DyePercentage: ${dyePercentage || 2.0}%
DyeNames: ${dyeNamesList}
Chemicals:
- Salt: ${saltPercentage || 0}%
- SodaAsh: ${sodaAshPercentage || 0}%
- AceticAcid: ${aceticAcidPercentage || 0}%
- Others: ${otherChemicals && otherChemicals.length > 0 ? otherChemicals.join(', ') : 'none'}`;

    // Try OpenAI
    const openAiKey = process.env.OPENAI_API_KEY;
    if (openAiKey) {
        try {
            const openai = new OpenAI({ apiKey: openAiKey });
            const response = await openai.chat.completions.create({
                model: 'gpt-4o-mini',
                messages: [
                    { role: 'system', content: SYSTEM_PROMPT },
                    { role: 'user', content: userPrompt }
                ],
                temperature: 0.3,
                max_tokens: 300,
            });

            let content = response.choices[0].message.content.trim();

            // Strip markdown code fence if present
            if (content.startsWith('```')) {
                content = content.replace(/^```(?:json)?\s*\n?/, '').replace(/\n?```\s*$/, '');
            }

            const parsed = JSON.parse(content);

            const requiredFields = ['colorName', 'shadeLevel', 'tone', 'hexColor', 'rgb', 'confidence'];
            const hasAll = requiredFields.every(f => parsed[f] !== undefined);

            if (hasAll) {
                if (!parsed.note) {
                    parsed.note = 'Approximate result. Actual shade may vary.';
                }
                parsed.source = 'ai';
                res.json(parsed);
                return;
            }
        } catch (error) {
            console.error('OpenAI Color Prediction Error:', error.message);
        }
    }

    // Fallback to local prediction
    const fallback = localPredict({
        fabricType: fabricType || 'cotton',
        fabricGSM: fabricGSM || 160,
        dyeType: dyeType || 'reactive',
        dyePercentage: dyePercentage || 2.0,
        dyeNames: dyeNamesList,
        saltPercentage: saltPercentage || 0,
    });

    res.json(fallback);
});

// @desc    Detect color from image using AI Vision
// @route   POST /api/color-predict/from-image
// @access  Private
const detectColorFromImage = asyncHandler(async (req, res) => {
    const { imageBase64, existingColors } = req.body;

    if (!imageBase64) {
        res.status(400);
        throw new Error('imageBase64 is required');
    }

    const openAiKey = process.env.OPENAI_API_KEY;
    if (!openAiKey) {
        res.status(500);
        throw new Error('OpenAI API key not configured');
    }

    try {
        const openai = new OpenAI({ apiKey: openAiKey });

        // Ensure proper data URI format
        let imageUrl = imageBase64;
        if (!imageBase64.startsWith('data:')) {
            imageUrl = `data:image/jpeg;base64,${imageBase64}`;
        }

        // Build dynamic prompt with existing colors
        const colorsList = Array.isArray(existingColors) && existingColors.length > 0
            ? existingColors.join(', ')
            : null;

        let promptText = `You are a textile/garment color expert. Look at this image and identify the dominant fabric/garment color.

Return ONLY valid JSON, no markdown, no explanation:
{
  "colorName": "<color name>",
  "hexColor": "#RRGGBB",
  "confidence": "low | medium | high"
}`;

        if (colorsList) {
            promptText += `

IMPORTANT: The user already has these colors in their system: [${colorsList}]
- If the image color closely matches ANY of these existing colors, you MUST return that EXACT existing color name.
- Only create a new color name if none of the existing colors match the image.
- Use practical garment industry color names (e.g., "Golden Yellow", "Navy Blue", "Dusty Rose").`;
        } else {
            promptText += `

Rules:
- Use practical garment industry color names (e.g., "Golden Yellow", "Navy Blue", "Dusty Rose")
- Be specific but standard — avoid overly creative names`;
        }

        promptText += `
- hexColor must be a valid 6-digit hex color code
- Return ONLY the JSON object, nothing else`;

        const response = await openai.chat.completions.create({
            model: 'gpt-4o',
            messages: [
                {
                    role: 'user',
                    content: [
                        { type: 'text', text: promptText },
                        {
                            type: 'image_url',
                            image_url: {
                                url: imageUrl,
                                detail: 'low',
                            },
                        },
                    ],
                },
            ],
            temperature: 0.1,
            max_tokens: 200,
        });

        let content = response.choices[0].message.content.trim();

        // Strip markdown code fence if present
        if (content.startsWith('```')) {
            content = content.replace(/^```(?:json)?\s*\n?/, '').replace(/\n?```\s*$/, '');
        }

        const parsed = JSON.parse(content);

        if (parsed.colorName && parsed.hexColor) {
            res.json({
                colorName: parsed.colorName,
                hexColor: parsed.hexColor,
                confidence: parsed.confidence || 'medium',
                source: 'ai-vision',
            });
            return;
        }

        res.status(500);
        throw new Error('Invalid response from AI');
    } catch (error) {
        console.error('Image Color Detection Error:', error.message);
        if (!res.headersSent) {
            res.status(500);
            throw new Error('Failed to detect color from image: ' + error.message);
        }
    }
});

export { predictColor, detectColorFromImage };
