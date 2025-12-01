/**
 * File parser utilities for CSV and Excel files
 */

/**
 * Parse CSV text into array of objects
 */
export function parseCSV(csvText) {
  const lines = csvText.trim().split('\n');
  if (lines.length < 2) {
    throw new Error('CSV file must have at least a header row and one data row');
  }

  // Parse header row
  const headers = parseCSVLine(lines[0]);
  
  // Parse data rows
  const data = [];
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim()) {
      const values = parseCSVLine(lines[i]);
      const row = {};
      headers.forEach((header, index) => {
        row[header.trim()] = values[index] ? values[index].trim() : '';
      });
      data.push(row);
    }
  }

  return data;
}

/**
 * Parse a single CSV line, handling quoted fields
 */
function parseCSVLine(line) {
  const values = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    const nextChar = line[i + 1];

    if (char === '"') {
      if (inQuotes && nextChar === '"') {
        // Escaped quote
        current += '"';
        i++; // Skip next quote
      } else {
        // Toggle quote state
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      // End of field
      values.push(current);
      current = '';
    } else {
      current += char;
    }
  }
  
  // Add last field
  values.push(current);
  
  return values;
}

/**
 * Map CSV column names to database column names
 * Supports various naming conventions
 */
export function mapCSVColumnsToDB(csvRow) {
  const columnMap = {
    // Student name variations
    'name': 'student_name',
    'student name': 'student_name',
    'student_name': 'student_name',
    'full name': 'student_name',
    'fullname': 'student_name',
    
    // Class variations
    'class': 'class',
    'grade': 'class',
    'standard': 'class',
    
    // Section variations
    'section': 'section',
    'sec': 'section',
    
    // Roll number variations
    'roll': 'roll_no',
    'roll no': 'roll_no',
    'roll_no': 'roll_no',
    'roll number': 'roll_no',
    'rollnumber': 'roll_no',
    'rollnum': 'roll_no',
    
    // Gender variations
    'gender': 'gender',
    'sex': 'gender',
    
    // Student ID (optional, will be auto-generated if not provided)
    'id': 'student_id',
    'student id': 'student_id',
    'student_id': 'student_id',
    'studentid': 'student_id'
  };

  const mapped = {};
  const csvKeys = Object.keys(csvRow);
  
  csvKeys.forEach(csvKey => {
    const normalizedKey = csvKey.toLowerCase().trim();
    const dbColumn = columnMap[normalizedKey];
    
    if (dbColumn) {
      mapped[dbColumn] = csvRow[csvKey];
    }
  });

  return mapped;
}

/**
 * Validate student data
 */
export function validateStudentData(student) {
  const errors = [];

  // Required fields
  if (!student.student_name || student.student_name.trim() === '') {
    errors.push('Student name is required');
  }

  if (!student.class || student.class.toString().trim() === '') {
    errors.push('Class is required');
  }

  if (!student.section || student.section.trim() === '') {
    errors.push('Section is required');
  }

  if (!student.roll_no || student.roll_no.toString().trim() === '') {
    errors.push('Roll number is required');
  }

  // Validate class (should be numeric or valid grade)
  const classValue = student.class.toString().trim();
  if (!/^\d+$/.test(classValue) && !/^[A-Za-z]+\s*\d+$/.test(classValue)) {
    errors.push(`Invalid class format: ${classValue}`);
  }

  // Validate section (should be single letter or short string)
  const sectionValue = student.section.toString().trim().toUpperCase();
  if (sectionValue.length > 5) {
    errors.push(`Section should be 1-5 characters: ${sectionValue}`);
  }

  // Validate roll number (should be numeric)
  const rollNo = student.roll_no.toString().trim();
  if (!/^\d+$/.test(rollNo)) {
    errors.push(`Roll number must be numeric: ${rollNo}`);
  }

  // Validate gender (optional, but if provided should be valid)
  if (student.gender) {
    const genderValue = student.gender.toString().trim();
    const validGenders = ['male', 'female', 'm', 'f', 'M', 'F', 'Male', 'Female'];
    if (!validGenders.includes(genderValue)) {
      errors.push(`Invalid gender value: ${genderValue}. Use Male/Female or M/F`);
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    normalized: {
      student_name: student.student_name ? student.student_name.trim() : '',
      class: classValue,
      section: sectionValue,
      roll_no: parseInt(rollNo),
      gender: student.gender ? normalizeGender(student.gender.toString().trim()) : null
    }
  };
}

/**
 * Normalize gender value
 */
function normalizeGender(gender) {
  const normalized = gender.toLowerCase();
  if (normalized === 'm' || normalized === 'male') {
    return 'Male';
  }
  if (normalized === 'f' || normalized === 'female') {
    return 'Female';
  }
  return gender; // Return as-is if already in correct format
}

/**
 * Parse uploaded file based on content type
 */
export async function parseUploadedFile(fileBuffer, filename, mimeType) {
  const text = fileBuffer.toString('utf-8');
  
  // Check file extension
  const extension = filename.split('.').pop().toLowerCase();
  
  if (extension === 'csv' || mimeType === 'text/csv' || mimeType === 'application/vnd.ms-excel') {
    return parseCSV(text);
  } else if (extension === 'txt' && text.includes(',')) {
    // Treat as CSV if it has commas
    return parseCSV(text);
  } else {
    throw new Error(`Unsupported file type: ${extension}. Please upload a CSV file.`);
  }
}

