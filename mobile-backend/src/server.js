import app from './app.js';
import fs from 'fs';
import path from 'path';
import connectDB from './config/db.js';

const PORT = process.env.PORT || 5001;

// Ensure uploads directory exists
const uploadsDir = path.join(path.resolve(), 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

const startServer = async () => {
    try {
        // Wait for database connection before starting the server
        await connectDB();
        
        app.listen(PORT, '0.0.0.0', () => {
          console.log(`Server running on port ${PORT}`);
        });
    } catch (error) {
        console.error('Failed to start server due to database connection failure');
        console.log('Retrying in 5 seconds...');
        setTimeout(startServer, 5000);
    }
};

startServer();