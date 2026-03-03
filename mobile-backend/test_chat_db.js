import chatDbConnection from './src/config/chatDb.js';

async function testConnection() {
    console.log("Starting Chatbot DB Connection Test...");

    try {
        // Wait for connection to be ready
        if (chatDbConnection.readyState !== 1) {
            console.log("Waiting for connection...");
            await new Promise((resolve) => chatDbConnection.once('connected', resolve));
        }

        console.log("Connected Successfully!");

        const collections = await chatDbConnection.db.listCollections().toArray();
        console.log("Available Collections in garments_mobile:");
        collections.forEach(c => console.log(` - ${c.name}`));

        const inwardCount = await chatDbConnection.collection('inwards').countDocuments().catch(() => 0);
        const outwardCount = await chatDbConnection.collection('outwards').countDocuments().catch(() => 0);
        const partyCount = await chatDbConnection.collection('parties').countDocuments().catch(() => 0);

        console.log("\nRemote Data Summary:");
        console.log(` - Total Inwards: ${inwardCount}`);
        console.log(` - Total Outwards: ${outwardCount}`);
        console.log(` - Total Parties: ${partyCount}`);

        process.exit(0);
    } catch (err) {
        console.error("Test Failed:", err);
        process.exit(1);
    }
}

testConnection();
