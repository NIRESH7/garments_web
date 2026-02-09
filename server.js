// AI MongoDB Chatbot Server - v2
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import chatRouter from './routes/chat.js';
import uploadRouter from './routes/upload.js';
import connectMongo from './config/mongo.js';

dotenv.config();

// Connect to MongoDB
connectMongo();

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json({ limit: '50mb' })); // Increase limit for file uploads

const publicDir = path.resolve('public');
app.use(express.static(publicDir));

app.use('/api/chat', chatRouter);
// app.use('/api/upload', uploadRouter);

app.get('*', (_req, res) => {
  res.sendFile(path.join(publicDir, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`AI MongoDB Chatbot listening on http://localhost:${PORT}`);
});

