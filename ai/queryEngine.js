import fetch from 'node-fetch';
import { GoogleGenerativeAI } from '@google/generative-ai';

const TABLE_METADATA = {
  attendance: ['attendance_id', 'student_id', 'total_days', 'present_days', 'absent_days'],
  class_summary: ['summary_id', 'class', 'section', 'total_students'],
  exams: ['exam_id', 'exam_name', 'class'],
  fees: ['fee_id', 'student_id', 'total_fee', 'paid_fee', 'due_fee'],
  leave_records: ['leave_id', 'student_id', 'leave_type', 'leave_days'],
  marks: ['mark_id', 'student_id', 'exam_id', 'total_marks', 'obtained_marks'],
  rankings: ['rank_id', 'student_id', 'class_rank'],
  students: ['student_id', 'student_name', 'class', 'section', 'roll_no', 'gender'],
  subjects: ['subject_id', 'subject_name'],
  teachers: ['teacher_id', 'teacher_name', 'SUBJECT'],
  search_history: ['id', 'question', 'generated_sql', 'created_at']
};

// Try these models in order: gemini-1.5-flash (fastest), gemini-1.5-pro (more capable), gemini-2.0-flash (latest)
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-1.5-flash';
const GEMINI_FALLBACK_MODELS = ['gemini-1.5-pro', 'gemini-2.0-flash', 'gemini-2.5-pro'];

const RULES = [
  {
    name: 'today sales total',
    match: q => q.includes('today') && q.includes('sale'),
    build: () => ({
      sql: 'SELECT IFNULL(SUM(total_price), 0) AS total_sales FROM orders WHERE DATE(order_date) = CURDATE();',
      explanation: 'Summing today’s total_price from orders filtered by current date.'
    })
  },
  {
    name: 'low stock products',
    match: q => q.includes('low stock') || (q.includes('stock') && (q.includes('low') || q.includes('less') || q.includes('below'))),
    build: q => {
      const thresholdMatch = q.match(/(?:below|under|less than)\s+(\d+)/);
      const threshold = thresholdMatch ? Number(thresholdMatch[1]) : 10;
      return {
        sql: `SELECT id, name, price, stock FROM products WHERE stock < ${threshold};`,
        explanation: `Retrieving products whose stock is below ${threshold}.`
      };
    }
  },
  {
    name: 'orders by customer name',
    match: q => q.includes('order') && q.includes('customer'),
    build: q => {
      const nameMatch = q.match(/customer\s+([a-zA-Z\s]+)/);
      const name = nameMatch ? nameMatch[1].trim() : '';
      const where = name ? `WHERE c.name LIKE '%${name.replace(/'/g, "''")}%'` : '';
      return {
        sql: `SELECT o.id, c.name AS customer, o.product, o.quantity, o.total_price, o.order_date
FROM orders o
JOIN customers c ON c.id = o.customer_id
${where}
ORDER BY o.order_date DESC
LIMIT 50;`,
        explanation: 'Joining orders with customers to list recent orders for the requested customer.'
      };
    }
  },
  {
    name: 'customers by city',
    match: q => q.includes('customer') && q.includes('city'),
    build: q => {
      const cityMatch = q.match(/city\s+([a-zA-Z\s]+)/);
      const city = cityMatch ? cityMatch[1].trim() : '';
      const where = city ? `WHERE city LIKE '%${city.replace(/'/g, "''")}%'` : '';
      return {
        sql: `SELECT id, name, phone, city FROM customers ${where} ORDER BY name ASC;`,
        explanation: 'Listing customers filtered by city.'
      };
    }
  },
  {
    name: 'top products by revenue',
    match: q => q.includes('top') && q.includes('product'),
    build: q => {
      const limitMatch = q.match(/top\s+(\d+)/);
      const limit = limitMatch ? Number(limitMatch[1]) : 5;
      return {
        sql: `SELECT o.product, SUM(o.total_price) AS revenue, SUM(o.quantity) AS units
FROM orders o
GROUP BY o.product
ORDER BY revenue DESC
LIMIT ${limit};`,
        explanation: `Aggregating order revenue per product and returning the top ${limit}.`
      };
    }
  },
  {
    name: 'all products',
    match: q => q.includes('product'),
    build: () => ({
      sql: 'SELECT id, name, price, stock FROM products ORDER BY name ASC;',
      explanation: 'Listing all products with pricing and stock.'
    })
  },
  {
    name: 'all customers',
    match: q => q.includes('customer'),
    build: () => ({
      sql: 'SELECT id, name, phone, city FROM customers ORDER BY name ASC;',
      explanation: 'Listing all customers.'
    })
  },
  {
    name: 'all orders',
    match: q => q.includes('order'),
    build: () => ({
      sql: `SELECT o.id, c.name AS customer, o.product, o.quantity, o.total_price, o.order_date
FROM orders o
JOIN customers c ON c.id = o.customer_id
ORDER BY o.order_date DESC
LIMIT 50;`,
      explanation: 'Retrieving recent orders with customer names.'
    })
  }
];

function extractSqlCandidate(text) {
  if (!text) return null;
  const codeBlock = text.match(/```(?:sql)?\s*([\s\S]*?)```/i);
  const candidate = (codeBlock ? codeBlock[1] : text).trim();
  const normalized = candidate.replace(/^SQL\s*:?\s*/i, '').trim();
  return normalized;
}

async function tryGeminiWithModel(apiKey, modelName, question) {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ 
    model: modelName, 
    generationConfig: { 
      temperature: 0.1,
      maxOutputTokens: 500
    } 
  });

  const schemaDescription = Object.entries(TABLE_METADATA)
    .map(([table, columns]) => `- ${table}(${columns.join(', ')})`)
    .join('\n');

  const prompt = `You are a SQL expert assistant. Convert the user's natural language question into a MySQL SELECT query.

DATABASE SCHEMA:
${schemaDescription}

RELATIONSHIPS:
- attendance.student_id references students.student_id
- fees.student_id references students.student_id
- leave_records.student_id references students.student_id
- marks.student_id references students.student_id
- marks.exam_id references exams.exam_id
- rankings.student_id references students.student_id

EXAMPLES:
Question: "Show all students"
SQL: SELECT student_id, student_name, class, section, roll_no, gender FROM students ORDER BY student_name ASC;

Question: "Total students"
SQL: SELECT COUNT(*) AS total_students FROM students;

Question: "Students in class 10"
SQL: SELECT student_id, student_name, class, section, roll_no FROM students WHERE class = '10' ORDER BY roll_no ASC;

Question: "Student marks for exam"
SQL: SELECT s.student_name, m.obtained_marks, m.total_marks, e.exam_name FROM marks m JOIN students s ON s.student_id = m.student_id JOIN exams e ON e.exam_id = m.exam_id ORDER BY m.obtained_marks DESC;

Question: "Attendance summary"
SQL: SELECT s.student_name, a.present_days, a.absent_days, a.total_days FROM attendance a JOIN students s ON s.student_id = a.student_id;

Question: "Fee due students"
SQL: SELECT s.student_name, f.total_fee, f.paid_fee, f.due_fee FROM fees f JOIN students s ON s.student_id = f.student_id WHERE f.due_fee > 0 ORDER BY f.due_fee DESC;

IMPORTANT RULES:
1. Return ONLY the SQL query, no explanations or markdown
2. Always end with a semicolon
3. Use proper JOINs when accessing related tables
4. Use CURDATE() for today's date
5. Use DATE() function for date comparisons
6. Handle aggregations (SUM, COUNT, AVG) when asked for totals/counts/averages
7. Use LIKE for partial name matches
8. Only use SELECT queries (no INSERT, UPDATE, DELETE)

Question: "${question}"
SQL:`;

  const result = await model.generateContent(prompt);
  const responseText = result.response.text();
  const text = extractSqlCandidate(responseText);
  
  if (!text) {
    return null;
  }

  const sqlText = text.trim();
  const lowerSql = sqlText.toLowerCase();
  
  // Validate it's a SELECT query
  if (!lowerSql.startsWith('select') && !lowerSql.startsWith('with')) {
    return null;
  }

  // Ensure it ends with semicolon
  const finalSql = sqlText.endsWith(';') ? sqlText : `${sqlText};`;

  return {
    sql: finalSql,
    explanation: `Generated by Gemini AI (${modelName}) from natural language question.`,
    strategy: 'gemini',
    modelUsed: modelName
  };
}

async function tryGemini(question) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.warn('GEMINI_API_KEY not set. Skipping Gemini generation.');
    return null;
  }

  // Try primary model first, then fallbacks
  const modelsToTry = [GEMINI_MODEL, ...GEMINI_FALLBACK_MODELS];
  
  for (const modelName of modelsToTry) {
    try {
      console.log(`Trying Gemini model: ${modelName}`);
      const result = await tryGeminiWithModel(apiKey, modelName, question);
      if (result) {
        console.log(`✓ Successfully used model: ${modelName}`);
        return result;
      }
    } catch (error) {
      // If it's a 404, try next model
      if (error.message.includes('404') || error.message.includes('not found')) {
        console.warn(`Model "${modelName}" not available, trying next...`);
        continue;
      }
      // For other errors (API key, rate limit, etc.), log and return
      console.error(`Gemini error with ${modelName}:`, error.message);
      if (error.message.includes('API_KEY') || error.message.includes('401')) {
        console.error('Please check your GEMINI_API_KEY in .env file');
        return null;
      }
      // Continue to next model for 404 errors
      continue;
    }
  }

  console.error('All Gemini models failed. Falling back to rule-based generation.');
  return null;
}

async function tryOllama(question) {
  const model = process.env.OLLAMA_MODEL;
  if (!model) return null;

  const prompt = [
    'You are a SQL expert. Convert the user question into a single MySQL query.',
    'Use only the tables provided:',
    JSON.stringify(TABLE_METADATA, null, 2),
    'Return ONLY the SQL query and terminate with a semicolon.',
    `Question: ${question}`
  ].join('\n');

  try {
    const response = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt,
        stream: false
      }),
      timeout: 10_000
    });

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    const text = (data.response || '').trim();
    if (!text.toLowerCase().startsWith('select') && !text.toLowerCase().startsWith('with')) {
      return null;
    }

    return {
      sql: text.endsWith(';') ? text : `${text};`,
      explanation: 'Generated by local Ollama model.',
      strategy: 'ollama'
    };
  } catch (error) {
    console.warn('Ollama generation failed:', error.message);
    return null;
  }
}

function applyRule(question) {
  const normalized = question.toLowerCase();
  for (const rule of RULES) {
    if (rule.match(normalized)) {
      const { sql, explanation } = rule.build(question);
      return {
        sql,
        explanation,
        strategy: 'rule-based'
      };
    }
  }

  return {
    sql: 'SELECT student_id, student_name, class, section FROM students LIMIT 10;',
    explanation: 'Fallback query: listing sample students.',
    strategy: 'fallback'
  };
}

export async function generateSql(question) {
  if (!question || !question.trim()) {
    throw new Error('Question is required');
  }
  const trimmed = question.trim();

  const geminiResult = await tryGemini(trimmed);
  if (geminiResult) {
    return geminiResult;
  }

  const ollamaResult = await tryOllama(trimmed);
  if (ollamaResult) {
    return ollamaResult;
  }

  return applyRule(trimmed);
}

export function describeTables() {
  return TABLE_METADATA;
}

