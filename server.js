import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import chatRouter from './routes/chat.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

const publicDir = path.resolve('public');
app.use(express.static(publicDir));

app.use('/api/chat', chatRouter);

app.get('*', (_req, res) => {
  res.sendFile(path.join(publicDir, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`AI SQL Chatbot listening on http://localhost:${PORT}`);
});

