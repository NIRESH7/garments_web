import { Router } from 'express';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { generateSql, describeTables } from '../ai/queryEngine.js';
import { handleAttendanceRequest } from '../ai/attendanceAgent.js';
import { handleLeaveRequest } from '../ai/leaveAgent.js';
import { query } from '../config/db.js';
import { formatResults } from '../utils/resultFormatter.js';
import { toCSV, toJSON, toExcel } from '../utils/exportData.js';
import { generatePDF } from '../utils/pdfGenerator.js';

const router = Router();

async function askGeminiFreeForm(question) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return null;
  }

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const modelName = process.env.GEMINI_FREEFORM_MODEL || 'gemini-2.0-flash';
    const model = genAI.getGenerativeModel({
      model: modelName,
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 512
      }
    });

    const prompt = [
      'You are an assistant helping a user query a school management database.',
      'The database returned NO ROWS for the SQL query that was generated.',
      'Explain clearly that there was no matching data, then give a helpful answer or suggestions',
      'based on general knowledge. Keep the answer short and easy to read.',
      '',
      `User question: "${question}"`
    ].join('\n');

    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    return text || null;
  } catch (error) {
    console.warn('Gemini free-form fallback failed:', error.message);
    return null;
  }
}

async function ensureChatMessagesTable() {
  await query(`CREATE TABLE IF NOT EXISTS chat_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_message TEXT NOT NULL,
    ai_response TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );`);
}

router.get('/health', (_req, res) => {
  res.json({ status: 'ok', tables: describeTables() });
});

router.get('/history', async (_req, res) => {
  try {
    const rows = await query(
      'SELECT question, generated_sql, created_at FROM search_history ORDER BY created_at DESC LIMIT 10;'
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch history', details: error.message });
  }
});

router.get('/messages', async (_req, res) => {
  try {
    await ensureChatMessagesTable();
    const rows = await query(
      'SELECT user_message, ai_response, created_at FROM chat_messages ORDER BY created_at ASC LIMIT 100;'
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch chat messages', details: error.message });
  }
});

// Export endpoint for downloading query results
router.post('/export', async (req, res) => {
  try {
    const { data, format, filename } = req.body;
    
    if (!data || !Array.isArray(data) || data.length === 0) {
      return res.status(400).json({ error: 'No data to export' });
    }

    const exportFormat = format || 'csv';
    const baseFilename = filename || 'export';
    
    let content, mimeType, fileExtension;

    switch (exportFormat.toLowerCase()) {
      case 'csv':
        const csvResult = toCSV(data, `${baseFilename}.csv`);
        content = csvResult.content;
        mimeType = 'text/csv';
        fileExtension = 'csv';
        break;
      case 'json':
        const jsonResult = toJSON(data, `${baseFilename}.json`);
        content = jsonResult.content;
        mimeType = 'application/json';
        fileExtension = 'json';
        break;
      case 'excel':
      case 'xlsx':
        const excelResult = toExcel(data, `${baseFilename}.xlsx`);
        content = excelResult.content;
        mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        fileExtension = 'csv'; // Excel can open CSV
        break;
      case 'pdf':
        try {
          const pdfBuffer = await generatePDF(data, baseFilename);
          const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
          const finalFilename = `${baseFilename}_${timestamp}.pdf`;
          
          res.setHeader('Content-Type', 'application/pdf');
          res.setHeader('Content-Disposition', `attachment; filename="${finalFilename}"`);
          return res.send(pdfBuffer);
        } catch (pdfError) {
          return res.status(500).json({ error: 'Failed to generate PDF', details: pdfError.message });
        }
      default:
        return res.status(400).json({ error: 'Invalid format. Use csv, json, excel, or pdf' });
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
    const finalFilename = `${baseFilename}_${timestamp}.${fileExtension}`;

    res.setHeader('Content-Type', mimeType);
    res.setHeader('Content-Disposition', `attachment; filename="${finalFilename}"`);
    res.send(content);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ error: 'Failed to export data', details: error.message });
  }
});

router.post('/', async (req, res) => {
  const { message } = req.body || {};
  if (!message || !message.trim()) {
    return res.status(400).json({ error: 'Message is required.' });
  }

  try {
    // Build lightweight conversation context from previous messages so the
    // model can understand follow-ups like "which state is she in?"
    let historyText = '';
    try {
      await ensureChatMessagesTable();
      const recent = await query(
        'SELECT user_message, ai_response FROM chat_messages ORDER BY created_at DESC LIMIT 6;'
      );
      if (Array.isArray(recent) && recent.length > 0) {
        // Reverse so oldest is first
        const ordered = [...recent].reverse();
        historyText = ordered
          .map(
            m =>
              `User: ${m.user_message ?? ''}\nAssistant: ${m.ai_response ?? ''}`
          )
          .join('\n\n');
      }
    } catch (e) {
      console.warn('Unable to load chat history for context:', e.message);
    }

    // Check if this is a leave update request (before attendance, as leave is more specific)
    const leaveResult = await handleLeaveRequest(message.trim(), historyText);
    
    if (leaveResult) {
      // Handle leave request
      if (leaveResult.type === 'success') {
        await query('INSERT INTO search_history(question, generated_sql) VALUES (?, ?);', [
          message.trim(),
          leaveResult.sql || 'Leave update'
        ]);
        
        await ensureChatMessagesTable();
        await query(
          'INSERT INTO chat_messages(user_message, ai_response) VALUES (?, ?);',
          [message.trim(), leaveResult.message]
        );
        
        return res.json({
          sql: leaveResult.sql,
          strategy: 'leave-agent',
          explanation: 'Leave record updated successfully.',
          data: [],
          formatted: leaveResult.message
        });
      } else if (leaveResult.type === 'error') {
        await ensureChatMessagesTable();
        await query(
          'INSERT INTO chat_messages(user_message, ai_response) VALUES (?, ?);',
          [message.trim(), leaveResult.message]
        );
        
        return res.json({
          sql: leaveResult.sql,
          strategy: 'leave-agent-error',
          explanation: leaveResult.message,
          data: [],
          formatted: leaveResult.message
        });
      }
    }

    // Check if this is an attendance update request
    const attendanceResult = await handleAttendanceRequest(message.trim(), historyText);
    
    if (attendanceResult) {
      // Handle attendance request
      if (attendanceResult.type === 'confirmation_required') {
        // For now, we'll proceed but in future can add confirmation UI
        // For risky operations, we'll still execute but log it
        await ensureChatMessagesTable();
        await query(
          'INSERT INTO chat_messages(user_message, ai_response) VALUES (?, ?);',
          [message.trim(), attendanceResult.message]
        );
        
        return res.json({
          sql: attendanceResult.sql,
          strategy: 'attendance-agent-confirmation',
          explanation: attendanceResult.message,
          data: [],
          formatted: attendanceResult.message
        });
      } else if (attendanceResult.type === 'success') {
        await query('INSERT INTO search_history(question, generated_sql) VALUES (?, ?);', [
          message.trim(),
          attendanceResult.sql || 'Attendance update'
        ]);
        
        await ensureChatMessagesTable();
        await query(
          'INSERT INTO chat_messages(user_message, ai_response) VALUES (?, ?);',
          [message.trim(), attendanceResult.message]
        );
        
        return res.json({
          sql: attendanceResult.sql,
          strategy: 'attendance-agent',
          explanation: 'Attendance updated successfully.',
          data: attendanceResult.data || [],
          formatted: attendanceResult.message,
          hasData: attendanceResult.data && attendanceResult.data.length > 0,
          rowCount: attendanceResult.data ? attendanceResult.data.length : 0
        });
      } else if (attendanceResult.type === 'error') {
        await ensureChatMessagesTable();
        await query(
          'INSERT INTO chat_messages(user_message, ai_response) VALUES (?, ?);',
          [message.trim(), attendanceResult.message]
        );
        
        return res.json({
          sql: attendanceResult.sql,
          strategy: 'attendance-agent-error',
          explanation: attendanceResult.message,
          data: [],
          formatted: attendanceResult.message
        });
      }
    }

    // Regular query handling
    const aiResult = await generateSql(message, historyText);
    const rows = await query(aiResult.sql);
    await query('INSERT INTO search_history(question, generated_sql) VALUES (?, ?);', [
      message.trim(),
      aiResult.sql
    ]);

    if (!rows || rows.length === 0) {
      // First try a smart natural-language explanation using Gemini, if configured
      const fallbackText = await askGeminiFreeForm(message.trim());

      if (fallbackText) {
        await ensureChatMessagesTable();
        await query(
          'INSERT INTO chat_messages(user_message, ai_response) VALUES (?, ?);',
          [message.trim(), fallbackText]
        );

        return res.json({
          sql: aiResult.sql,
          strategy: `${aiResult.strategy}-no-data-gemini`,
          explanation: 'No matching database records; answered using Gemini instead.',
          data: [],
          formatted: fallbackText
        });
      }

      // Safe, rule-based suggestions if Gemini is not available
      const suggestions =
        'No matching records were found.\n\n' +
        'You can try questions like:\n' +
        '- "Show all students"\n' +
        '- "Total students in class 10"\n' +
        '- "Students with fee due"\n' +
        '- "Top students by marks"\n' +
        '- "Attendance summary for class 10"';

      await ensureChatMessagesTable();
      await query(
        'INSERT INTO chat_messages(user_message, ai_response) VALUES (?, ?);',
        [message.trim(), suggestions]
      );

      return res.json({
        sql: aiResult.sql,
        strategy: `${aiResult.strategy}-no-data`,
        explanation: 'No matching database records.',
        data: [],
        formatted: suggestions
      });
    }

    const formatted = formatResults(rows);
    await ensureChatMessagesTable();
    await query(
      'INSERT INTO chat_messages(user_message, ai_response) VALUES (?, ?);',
      [message.trim(), formatted]
    );

    res.json({
      sql: aiResult.sql,
      strategy: aiResult.strategy,
      explanation: aiResult.explanation,
      data: rows,
      formatted,
      hasData: rows && rows.length > 0,
      rowCount: rows ? rows.length : 0
    });
  } catch (error) {
    console.error('Chat route error:', error);
    res.status(500).json({
      error: 'Unable to answer the question.',
      details: error.message
    });
  }
});

export default router;

