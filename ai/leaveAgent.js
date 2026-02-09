import { GoogleGenerativeAI } from '@google/generative-ai';
import { query } from '../config/db.js';
import { formatResults } from '../utils/resultFormatter.js';

// Helper function to find student by name
async function findStudentByName(studentName) {
  try {
    const results = await query(
      'SELECT student_id, student_name, class, section FROM students WHERE student_name LIKE ? LIMIT 10;',
      [`%${studentName}%`]
    );
    return results || [];
  } catch (error) {
    console.error('Error finding student:', error);
    return [];
  }
}

// Helper function to find student by name and class
async function findStudentByNameAndClass(studentName, className) {
  try {
    const results = await query(
      'SELECT student_id, student_name, class, section FROM students WHERE student_name LIKE ? AND class = ? LIMIT 10;',
      [`%${studentName}%`, className]
    );
    return results || [];
  } catch (error) {
    console.error('Error finding student:', error);
    return [];
  }
}

// Helper function to check if leave record exists
async function checkLeaveRecordExists(studentId) {
  try {
    const results = await query(
      'SELECT leave_id, student_id, leave_type, leave_days FROM leave_records WHERE student_id = ? LIMIT 1;',
      [studentId]
    );
    return results && results.length > 0 ? results[0] : null;
  } catch (error) {
    console.error('Error checking leave record:', error);
    return null;
  }
}

// Generate SQL for leave updates using Gemini
async function generateLeaveSQL(userMessage, conversationHistory = '') {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const models = [
    'gemini-2.0-flash',
    'gemini-2.0-pro',
    'gemini-2.5-flash'
  ];

  let lastError = null;

  for (const modelName of models) {
    try {
      const model = genAI.getGenerativeModel({
        model: modelName,
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 512
        }
      });

      const schemaInfo = `
Database Schema:
- leave_records table: leave_id (INT, PRIMARY KEY), student_id (INT, FOREIGN KEY to students.student_id), leave_type (VARCHAR), leave_days (INT)
- students table: student_id (INT, PRIMARY KEY), student_name (VARCHAR), class (VARCHAR), section (VARCHAR)

Rules:
1. Use UPDATE for existing leave records
2. Use INSERT for new leave records if they don't exist
3. Always use student_id (not student name) in SQL
4. Use CURDATE() for today's date if needed
5. Only generate UPDATE or INSERT statements
6. Never use DELETE or DROP
7. For updating leave_type, use: UPDATE leave_records SET leave_type = 'new_type' WHERE student_id = X;
8. For updating leave_days, use: UPDATE leave_records SET leave_days = Y WHERE student_id = X;
9. For updating both, use: UPDATE leave_records SET leave_type = 'new_type', leave_days = Y WHERE student_id = X;
10. If record doesn't exist, use: INSERT INTO leave_records (student_id, leave_type, leave_days) VALUES (X, 'type', Y);
`;

      const prompt = `${schemaInfo}

Conversation History:
${conversationHistory || 'No previous context.'}

User Request: "${userMessage}"

Generate ONLY the SQL query (UPDATE or INSERT) to handle this leave record update request. 
Return ONLY the SQL statement, nothing else. No explanations, no markdown, just the SQL.

Examples:
- "Update leave type to personal for student 1" → UPDATE leave_records SET leave_type = 'Personal' WHERE student_id = 1;
- "Change leave days to 3 for student 5" → UPDATE leave_records SET leave_days = 3 WHERE student_id = 5;
- "Set leave type to medical and days to 5 for student 10" → UPDATE leave_records SET leave_type = 'Medical', leave_days = 5 WHERE student_id = 10;
- "Add leave record for student 20: medical, 2 days" → INSERT INTO leave_records (student_id, leave_type, leave_days) VALUES (20, 'Medical', 2);

SQL:`;

      const result = await model.generateContent(prompt);
      let sqlText = result.response.text().trim();

      // Clean up the SQL
      sqlText = sqlText.replace(/```sql/gi, '').replace(/```/g, '').trim();
      if (sqlText.startsWith('UPDATE') || sqlText.startsWith('INSERT')) {
        // Extract just the SQL statement
        const sqlMatch = sqlText.match(/(UPDATE|INSERT)[\s\S]*?;/);
        if (sqlMatch) {
          sqlText = sqlMatch[0];
        }
      }

      // Validate it's an UPDATE or INSERT
      if (!sqlText.toUpperCase().includes('UPDATE') && !sqlText.toUpperCase().includes('INSERT')) {
        throw new Error('Generated SQL does not contain UPDATE or INSERT statements');
      }

      console.log(`✓ Successfully used model: ${modelName}`);
      return sqlText;
    } catch (error) {
      lastError = error;
      if (error.message.includes('404') || error.message.includes('not found')) {
        console.warn(`Model "${modelName}" not available, trying next...`);
        continue;
      }
      throw error;
    }
  }

  throw new Error(`All Gemini models failed. Last error: ${lastError?.message || 'Unknown error'}`);
}

export async function handleLeaveRequest(userMessage, conversationHistory = '') {
  // Check if this is a leave-related update request
  const leaveKeywords = [
    'update leave', 'change leave', 'set leave', 'modify leave',
    'leave type', 'leave days', 'update leave type', 'change leave type',
    'set leave type', 'update leave days', 'change leave days'
  ];

  const lowerMessage = userMessage.toLowerCase();
  const isLeaveRequest = leaveKeywords.some(keyword => lowerMessage.includes(keyword)) &&
    (lowerMessage.includes('update') || lowerMessage.includes('change') || lowerMessage.includes('set') || lowerMessage.includes('modify'));

  if (!isLeaveRequest) {
    return null; // Not a leave update request
  }

  try {
    // Extract student ID or name
    const studentIdMatch = userMessage.match(/student\s+(?:id\s+)?(\d+)/i);
    const studentNameMatch = userMessage.match(/(?:student|for)\s+([A-Za-z\s]+?)(?:\s+(?:in|from|of)\s+class|\s+as|\s+to|$)/i);

    let studentId = null;
    let studentInfo = null;

    if (studentIdMatch) {
      studentId = parseInt(studentIdMatch[1]);
    } else if (studentNameMatch) {
      const studentName = studentNameMatch[1].trim();
      const classMatch = userMessage.match(/class\s+(\d+)/i);
      const className = classMatch ? classMatch[1] : null;

      if (className) {
        studentInfo = await findStudentByNameAndClass(studentName, className);
      } else {
        studentInfo = await findStudentByName(studentName);
      }

      if (!studentInfo || studentInfo.length === 0) {
        return {
          type: 'error',
          message: `Student "${studentName}"${className ? ` in class ${className}` : ''} not found. Please provide the correct student name or student_id.`,
          sql: null
        };
      }

      if (studentInfo.length > 1) {
        const options = studentInfo.map(s => `${s.student_name} (ID: ${s.student_id}, Class: ${s.class})`).join('\n');
        return {
          type: 'error',
          message: `Multiple students found. Please specify:\n${options}\n\nOr use student_id directly.`,
          sql: null
        };
      }

      studentId = studentInfo[0].student_id;
      // Replace name with student_id in message for SQL generation
      userMessage = userMessage.replace(new RegExp(studentName, 'gi'), `student ${studentId}`);
    } else {
      // Try to extract student ID from patterns like "for 1" or "student 1"
      const directIdMatch = userMessage.match(/\b(\d+)\b/);
      if (directIdMatch) {
        // Check if this number could be a student ID
        const potentialId = parseInt(directIdMatch[1]);
        if (potentialId > 0 && potentialId < 10000) {
          studentId = potentialId;
        }
      }
    }

    if (!studentId) {
      return {
        type: 'error',
        message: 'Please specify a student ID or student name. Example: "Update leave type to personal for student 1" or "Change leave type for Aarav Patel".',
        sql: null
      };
    }

    // Check if leave record exists
    const existingRecord = await checkLeaveRecordExists(studentId);

    // Generate SQL using Gemini
    let generatedSQL;
    try {
      generatedSQL = await generateLeaveSQL(userMessage, conversationHistory);
    } catch (error) {
      return {
        type: 'error',
        message: `Failed to generate leave SQL: ${error.message}\n\nPlease check:\n- Student ID is correct\n- Database connection is active`,
        sql: null
      };
    }

    // Execute the SQL
    try {
      await query(generatedSQL);

      // Fetch updated record
      const updatedRecord = await checkLeaveRecordExists(studentId);

      if (updatedRecord) {
        const formatted = formatResults([updatedRecord]);
        return {
          type: 'success',
          message: `✅ Leave record updated successfully.\n\n${formatted}`,
          sql: generatedSQL,
          data: [updatedRecord]
        };
      } else {
        return {
          type: 'success',
          message: `✅ Leave record updated successfully.`,
          sql: generatedSQL,
          data: []
        };
      }
    } catch (error) {
      return {
        type: 'error',
        message: `❌ Failed to update leave record: ${error.message}\n\nPlease check:\n- Student ID is correct\n- Leave type is valid (Sick Leave, Personal, Medical, Family Emergency)\n- Database connection is active`,
        sql: generatedSQL
      };
    }
  } catch (error) {
    return {
      type: 'error',
      message: `❌ Error processing leave request: ${error.message}`,
      sql: null
    };
  }
}

