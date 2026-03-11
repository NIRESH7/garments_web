import dotenv from 'dotenv';
import mongoose from 'mongoose';
import dns from 'dns';
import { generateSql } from './src/modules/ai/queryEngine.js';
import { formatResults } from './src/utils/resultFormatter.js';

dotenv.config();
dns.setServers(['8.8.8.8', '8.8.4.4']);

async function testChatLogic() {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;

    const questions = process.argv[2] ? [process.argv[2]] : [
        "What is the last inward?",
        "Show me recent inwards with complaints"
    ];

    for (const q of questions) {
        console.log('\n--- Question:', q);
        const aiResult = await generateSql(q);
        console.log('AI Generated Strategy:', aiResult.strategy);

        if (aiResult.mongoQuery) {
            console.log('Generated Query:', JSON.stringify(aiResult.mongoQuery.query));
            if (aiResult.mongoQuery.projection) console.log('Generated Projection:', JSON.stringify(aiResult.mongoQuery.projection));

            const { collection, type, query: mQuery, projection } = aiResult.mongoQuery;
            let rows = [];
            if (type === 'find') {
                let cursor = db.collection(collection).find(mQuery);
                if (projection && Object.keys(projection).length > 0) {
                    cursor = cursor.project(projection);
                }
                rows = await cursor.limit(5).toArray();
            } else if (type === 'aggregate') {
                if (projection && Object.keys(projection).length > 0) {
                    mQuery.push({ $project: projection });
                }
                rows = await db.collection(collection).aggregate(mQuery).toArray();
            }
            console.log('Rows found:', rows.length);
            console.log('Formatted results preview:\n', formatResults(rows).substring(0, 500));
        }
    }

    await mongoose.disconnect();
    process.exit(0);
}

testChatLogic();
