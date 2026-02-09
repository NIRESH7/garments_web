import { GoogleGenerativeAI } from '@google/generative-ai';
import { query } from '../config/db.js';

const TABLE_METADATA = {
  students: ['student_id', 'student_name', 'class', 'section', 'roll_no', 'gender'],
  attendance: ['attendance_id', 'student_id', 'total_days', 'present_days', 'absent_days']
};

async function findStudentByNameAndClass(studentName, className) {
  try {
    const students = await query(
      `SELECT student_id, student_name, class, section FROM students 
       WHERE student_name LIKE ? AND class = ? LIMIT 5`,
      [`%${studentName}%`, className]
    );
    return students;
  } catch (error) {
    return [];
  }
}

async function findStudentByName(studentName) {
  try {
    const students = await query(
      `SELECT student_id, student_name, class, section FROM students 
       WHERE student_name LIKE ? LIMIT 5`,
      [`%${studentName}%`]
    );
    return students;
  } catch (error) {
    return [];
  }
}

async function generateAttendanceSQL(userMessage, conversationHistory = '') {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  // Try models in order: gemini-1.5-flash, gemini-1.5-pro, gemini-2.0-flash, gemini-2.5-pro
  const modelsToTry = [
    'gemini-2.0-flash',
    'gemini-2.0-pro',
    'gemini-2.5-flash'
  ];

  const genAI = new GoogleGenerativeAI(apiKey);
  let lastError = null;

  for (const modelName of modelsToTry) {
    try {
      console.log(`Trying Gemini model for attendance: ${modelName}`);
      const model = genAI.getGenerativeModel({
        model: modelName,
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 800
        }
      });

      const schemaDescription = Object.entries(TABLE_METADATA)
        .map(([table, columns]) => `- ${table}(${columns.join(', ')})`)
        .join('\n');

      const prompt = `You are an AI Attendance Agent for a school database. Generate SQL to update attendance.

DATABASE SCHEMA:
${schemaDescription}

RELATIONSHIPS:
- attendance.student_id references students.student_id

IMPORTANT RULES:
1. For today's attendance: Always increment total_days by 1
2. If marking present: increment present_days by 1, recalculate absent_days = total_days - present_days
3. If marking absent: increment absent_days by 1, keep present_days same, recalculate total_days = present_days + absent_days
4. If attendance record doesn't exist for a student, INSERT it
5. If attendance record exists, UPDATE it
6. For class-level updates, handle all students in that class
7. For "Set class X attendance: Y present, Z absent" - you need to figure out which students are present/absent
8. Return ONLY valid SQL queries, one per line if multiple needed
9. Always end each SQL with semicolon

SQL PATTERNS:

For single student present:
UPDATE attendance SET total_days = total_days + 1, present_days = present_days + 1, absent_days = total_days - present_days WHERE student_id = ?;
INSERT INTO attendance (student_id, total_days, present_days, absent_days) SELECT ?, 1, 1, 0 WHERE NOT EXISTS (SELECT 1 FROM attendance WHERE student_id = ?);

For single student absent:
UPDATE attendance SET total_days = total_days + 1, absent_days = absent_days + 1 WHERE student_id = ?;
INSERT INTO attendance (student_id, total_days, present_days, absent_days) SELECT ?, 1, 0, 1 WHERE NOT EXISTS (SELECT 1 FROM attendance WHERE student_id = ?);

For class present:
UPDATE attendance a JOIN students s ON a.student_id = s.student_id SET a.total_days = a.total_days + 1, a.present_days = a.present_days + 1, a.absent_days = a.total_days - a.present_days WHERE s.class = ?;
INSERT INTO attendance (student_id, total_days, present_days, absent_days) SELECT s.student_id, 1, 1, 0 FROM students s WHERE s.class = ? AND NOT EXISTS (SELECT 1 FROM attendance a WHERE a.student_id = s.student_id);

${conversationHistory ? `\nCONVERSATION HISTORY:\n${conversationHistory}\n` : ''}

User request: "${userMessage}"

Generate the SQL query(s) needed. If student names are mentioned, use student_id. If class is mentioned, use class number.
Return ONLY the SQL, no explanations.`;

      const result = await model.generateContent(prompt);
      const sqlText = result.response.text().trim();

      // Extract SQL from markdown code blocks if present
      const codeBlock = sqlText.match(/```(?:sql)?\s*([\s\S]*?)```/i);
      let cleanSQL = (codeBlock ? codeBlock[1] : sqlText)
        .replace(/^SQL\s*:?\s*/i, '')
        .trim();

      // Split multiple SQL statements
      const sqlStatements = cleanSQL.split(';').filter(s => s.trim().length > 0);

      // Replace placeholders with actual values from the message
      const processedSQL = sqlStatements.map(stmt => {
        let processed = stmt.trim();

        // Extract student IDs from message (e.g., "1023, 1027, 1031" or "student 103")
        const studentIdMatches = userMessage.match(/\b(\d{3,})\b/g);
        if (studentIdMatches && processed.includes('?')) {
          // For multiple students, we'll handle in execution
          processed = processed.replace(/\?/g, studentIdMatches[0]);
        }

        // Extract class number (e.g., "class 5", "class 7")
        const classMatch = userMessage.match(/class\s+(\d+)/i);
        if (classMatch && processed.includes('?')) {
          processed = processed.replace(/\?/g, `'${classMatch[1]}'`);
        }

        return processed.endsWith(';') ? processed : `${processed};`;
      }).join('\n');

      if (!processedSQL.toLowerCase().includes('insert') && !processedSQL.toLowerCase().includes('update')) {
        throw new Error('Generated SQL does not contain INSERT or UPDATE statements');
      }

      console.log(`✓ Successfully used model: ${modelName}`);
      return processedSQL;
    } catch (error) {
      lastError = error;
      // If it's a 404, try next model
      if (error.message.includes('404') || error.message.includes('not found')) {
        console.warn(`Model "${modelName}" not available, trying next...`);
        continue;
      }
      // For other errors, throw immediately
      throw error;
    }
  }

  // If all models failed
  throw new Error(`All Gemini models failed. Last error: ${lastError?.message || 'Unknown error'}`);
}

export async function handleAttendanceRequest(userMessage, conversationHistory = '') {
  // Check if this is an attendance-related request
  const attendanceKeywords = [
    'mark', 'present', 'absent', 'attendance', 'update attendance',
    'mark student', 'mark class', 'set attendance', 'set class'
  ];

  const lowerMessage = userMessage.toLowerCase();
  const isAttendanceRequest = attendanceKeywords.some(keyword => lowerMessage.includes(keyword));

  if (!isAttendanceRequest) {
    return null; // Not an attendance request
  }

  try {
    // Check if this is "all students" request (skip name lookup)
    const allStudentsPattern = /(?:mark|set)\s+(?:all\s+)?students?\s+(?:in|from|of)\s+class/i;
    const isAllStudentsRequest = allStudentsPattern.test(userMessage);

    // Check if student name is mentioned (e.g., "Rahul from class 5") - but NOT "all students"
    let studentInfo = null;
    if (!isAllStudentsRequest) {
      const nameMatch = userMessage.match(/(?:mark|set)\s+([A-Za-z\s]+?)\s+(?:from|in|of)\s+class/i);
      const directNameMatch = userMessage.match(/^mark\s+([A-Za-z\s]+?)\s+(?:as|present|absent)/i);

      if (nameMatch || directNameMatch) {
        const studentName = (nameMatch ? nameMatch[1] : directNameMatch[1]).trim();

        // Skip if it's "all" or "all students"
        if (studentName.toLowerCase().includes('all')) {
          // This will be handled as class-level update
        } else {
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

          // Replace name with student_id in message for SQL generation
          userMessage = userMessage.replace(new RegExp(studentName, 'gi'), `student ${studentInfo[0].student_id}`);
        }
      }
    }

    // Check for multiple student IDs (e.g., "1023, 1027, 1031")
    const multipleIdsMatch = userMessage.match(/students?[:\s]+([\d,\s]+)/i);
    let studentIds = [];
    if (multipleIdsMatch) {
      studentIds = multipleIdsMatch[1].split(',').map(id => id.trim()).filter(id => /^\d+$/.test(id));
    }

    // Generate SQL for attendance update
    const sql = await generateAttendanceSQL(userMessage, conversationHistory);

    // Check if this is a risky operation (deleting/overwriting past attendance)
    const isRisky = sql.toLowerCase().includes('delete') ||
      (sql.toLowerCase().includes('truncate') || sql.toLowerCase().includes('drop'));

    if (isRisky) {
      return {
        type: 'confirmation_required',
        message: '⚠️ This operation will modify or delete attendance records. Are you sure you want to proceed? (This requires confirmation - not yet implemented in UI)',
        sql: sql
      };
    }

    // Execute the SQL statements
    const sqlStatements = sql.split(';').filter(s => s.trim().length > 0);
    for (const stmt of sqlStatements) {
      if (stmt.trim()) {
        await query(stmt.trim() + ';');
      }
    }

    // Build success message with updated data
    let resultMessage = '✅ Attendance updated successfully.\n\n';

    // Extract information to show results
    const studentIdMatch = sql.match(/student_id\s*=\s*(\d+)/i) || sql.match(/student_id,\s*(\d+)/i) ||
      (studentInfo && studentInfo[0] ? studentInfo[0].student_id : null);
    const classMatch = sql.match(/class\s*=\s*['"]?(\d+)['"]?/i) || userMessage.match(/class\s+(\d+)/i);

    if (studentIds.length > 0) {
      // Multiple students
      const placeholders = studentIds.map(() => '?').join(',');
      const attendance = await query(
        `SELECT a.*, s.student_name, s.class, s.section 
         FROM attendance a 
         JOIN students s ON s.student_id = a.student_id 
         WHERE a.student_id IN (${placeholders}) 
         ORDER BY a.student_id`,
        studentIds
      );
      if (attendance && attendance.length > 0) {
        resultMessage += 'Updated attendance:\n';
        attendance.forEach(att => {
          resultMessage += `• ${att.student_name} (ID: ${att.student_id}): Present: ${att.present_days}, Absent: ${att.absent_days}, Total: ${att.total_days}\n`;
        });
      }
    } else if (studentIdMatch || studentInfo) {
      const studentId = studentIdMatch || (studentInfo && studentInfo[0].student_id);
      const attendance = await query(
        'SELECT a.*, s.student_name, s.class, s.section FROM attendance a JOIN students s ON s.student_id = a.student_id WHERE a.student_id = ? ORDER BY a.created_at DESC LIMIT 1',
        [studentId]
      );
      if (attendance && attendance.length > 0) {
        resultMessage += `Updated attendance for ${attendance[0].student_name} (ID: ${studentId}):\n`;
        resultMessage += `• Total Days: ${attendance[0].total_days}\n`;
        resultMessage += `• Present: ${attendance[0].present_days}\n`;
        resultMessage += `• Absent: ${attendance[0].absent_days}\n`;
      }
    } else if (classMatch) {
      const className = classMatch[1];
      const attendance = await query(
        `SELECT COUNT(*) as total, SUM(a.present_days) as total_present, SUM(a.absent_days) as total_absent
         FROM attendance a 
         JOIN students s ON s.student_id = a.student_id 
         WHERE s.class = ?`,
        [className]
      );
      if (attendance && attendance.length > 0) {
        resultMessage += `Updated attendance for Class ${className}:\n`;
        resultMessage += `• Total Students: ${attendance[0].total}\n`;
        if (attendance[0].total_present) {
          resultMessage += `• Total Present Days: ${attendance[0].total_present}\n`;
        }
        if (attendance[0].total_absent) {
          resultMessage += `• Total Absent Days: ${attendance[0].total_absent}\n`;
        }
      }
    }

    return {
      type: 'success',
      message: resultMessage.trim(),
      sql: sql
    };
  } catch (error) {
    return {
      type: 'error',
      message: `❌ Failed to update attendance: ${error.message}\n\nPlease check:\n- Student ID or name is correct\n- Class number is valid\n- Database connection is active`,
      sql: null
    };
  }
}
