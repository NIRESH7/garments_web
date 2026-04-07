import axios from 'axios';

const testChat = async (message) => {
    try {
        console.log(`Testing: "${message}"`);
        const response = await axios.post('http://13.220.94.83:5001/api/chat', { message });
        console.log('Response:', response.data.formatted);
        console.log('Strategy:', response.data.strategy);
        console.log('Row Count:', response.data.rowCount);
        console.log('-------------------');
    } catch (error) {
        console.error('Error:', error.message);
    }
};

const runTests = async () => {
    await testChat('Hello');
    await testChat('வணக்கம்');
    await testChat('What is an inward?');
    await testChat('Show me all lots');
    await testChat('Who is the president?');
};

runTests();
