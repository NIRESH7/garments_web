import { Router } from 'express';
import { query } from '../config/db.js';
import { parseUploadedFile, mapCSVColumnsToDB, validateStudentData } from '../utils/fileParser.js';

const router = Router();

/**
 * Upload and import students from CSV/Excel file
 * Query parameter: ?update=true to update existing students instead of skipping
 */
router.post('/students', async (req, res) => {
  try {
    const updateExisting = req.query.update === 'true';
    
    // Check if file was uploaded
    if (!req.body.fileData || !req.body.filename) {
      return res.status(400).json({ 
        error: 'No file provided',
        message: 'Please upload a CSV file with student data'
      });
    }

    const { fileData, filename, mimeType } = req.body;

    // Parse the file
    let parsedData;
    try {
      const fileBuffer = Buffer.from(fileData, 'base64');
      parsedData = await parseUploadedFile(fileBuffer, filename, mimeType);
    } catch (parseError) {
      return res.status(400).json({
        error: 'File parsing failed',
        message: parseError.message
      });
    }

    if (!parsedData || parsedData.length === 0) {
      return res.status(400).json({
        error: 'Empty file',
        message: 'The uploaded file contains no data'
      });
    }

    // Process and validate each row
    const results = {
      total: parsedData.length,
      success: [],
      errors: [],
      skipped: []
    };

    for (let i = 0; i < parsedData.length; i++) {
      const row = parsedData[i];
      const rowNumber = i + 2; // +2 because row 1 is header, and arrays are 0-indexed

      try {
        // Map CSV columns to database columns
        const mappedData = mapCSVColumnsToDB(row);

        // Validate the data
        const validation = validateStudentData(mappedData);

        if (!validation.isValid) {
          results.errors.push({
            row: rowNumber,
            data: mappedData,
            errors: validation.errors
          });
          continue;
        }

        const student = validation.normalized;

        // Check if student already exists (by class + section + roll_no)
        // Roll numbers are unique within a class+section, but can repeat across classes
        // Example: Roll 1 in Class 10A is different from Roll 1 in Class 11A
        const existing = await query(
          `SELECT student_id, student_name FROM students 
           WHERE class = ? AND section = ? AND roll_no = ?`,
          [student.class, student.section, student.roll_no]
        );

        if (existing && existing.length > 0) {
          if (updateExisting) {
            // Update existing student
            const studentId = existing[0].student_id;
            await query(
              `UPDATE students 
               SET student_name = ?, class = ?, section = ?, roll_no = ?, gender = ?
               WHERE student_id = ?`,
              [
                student.student_name,
                student.class,
                student.section,
                student.roll_no,
                student.gender,
                studentId
              ]
            );

            results.success.push({
              row: rowNumber,
              student_id: studentId,
              data: student,
              action: 'updated'
            });
            continue;
          } else {
            // Skip existing student (roll number already exists in this class+section)
            results.skipped.push({
              row: rowNumber,
              data: student,
              existing_student_id: existing[0].student_id,
              existing_student_name: existing[0].student_name,
              reason: `Roll number ${student.roll_no} already exists in Class ${student.class} Section ${student.section} (Student: ${existing[0].student_name})`
            });
            continue;
          }
        }

        // Insert student
        const insertResult = await query(
          `INSERT INTO students (student_name, class, section, roll_no, gender) 
           VALUES (?, ?, ?, ?, ?)`,
          [
            student.student_name,
            student.class,
            student.section,
            student.roll_no,
            student.gender
          ]
        );

        const studentId = insertResult.insertId;

        // Create default attendance record
        try {
          await query(
            `INSERT INTO attendance (student_id, total_days, present_days, absent_days) 
             VALUES (?, 0, 0, 0)`,
            [studentId]
          );
        } catch (attError) {
          console.warn(`Failed to create attendance record for student ${studentId}:`, attError.message);
        }

        // Create default fees record
        try {
          await query(
            `INSERT INTO fees (student_id, total_fee, paid_fee, due_fee) 
             VALUES (?, 0, 0, 0)`,
            [studentId]
          );
        } catch (feeError) {
          console.warn(`Failed to create fees record for student ${studentId}:`, feeError.message);
        }

        results.success.push({
          row: rowNumber,
          student_id: studentId,
          data: student,
          action: 'created'
        });

      } catch (error) {
        results.errors.push({
          row: rowNumber,
          data: row,
          errors: [error.message]
        });
      }
    }

    // Prepare response
    const response = {
      success: true,
      summary: {
        total: results.total,
        imported: results.success.length,
        errors: results.errors.length,
        skipped: results.skipped.length
      },
      details: {
        successful: results.success,
        errors: results.errors,
        skipped: results.skipped
      }
    };

    res.json(response);

  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({
      error: 'Upload failed',
      message: error.message
    });
  }
});

/**
 * Get sample CSV template
 */
router.get('/template', (_req, res) => {
  const template = `student_name,class,section,roll_no,gender
Aarav Patel,10,A,1,Male
Aanya Sharma,10,A,2,Female
Aditya Kumar,10,A,3,Male
Ananya Singh,10,A,4,Female
Arjun Verma,10,A,5,Male`;

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename="student_template.csv"');
  res.send(template);
});

export default router;

