# 📤 Student Upload Guide

## How to Upload Students from CSV File

### Step 1: Download Template
1. Click the **"📥 Download Template"** link in the sidebar
2. This downloads a sample CSV file with the correct format

### Step 2: Prepare Your CSV File

Your CSV file should have the following columns (in any order):

**Required Columns:**
- `student_name` (or `name`, `full name`, `fullname`)
- `class` (or `grade`, `standard`)
- `section` (or `sec`)
- `roll_no` (or `roll`, `roll number`, `rollnumber`)

**Optional Columns:**
- `gender` (or `sex`) - Use: `Male`, `Female`, `M`, or `F`

### Step 3: CSV Format Example

```csv
student_name,class,section,roll_no,gender
Aarav Patel,10,A,1,Male
Aanya Sharma,10,A,2,Female
Aditya Kumar,10,A,3,Male
Ananya Singh,10,A,4,Female
Arjun Verma,10,A,5,Male
```

### Step 4: Upload File

1. Click the **"📤 Upload CSV File"** button in the sidebar
2. Select your CSV file
3. Wait for processing
4. Review the results

## 📋 Column Name Variations Supported

The system automatically recognizes these column name variations:

### Student Name
- `student_name`, `name`, `student name`, `full name`, `fullname`

### Class
- `class`, `grade`, `standard`

### Section
- `section`, `sec`

### Roll Number
- `roll_no`, `roll`, `roll no`, `roll number`, `rollnumber`, `rollnum`

### Gender
- `gender`, `sex`

## ✅ Validation Rules

### Student Name
- **Required**: Yes
- **Format**: Any text

### Class
- **Required**: Yes
- **Format**: Numeric (e.g., `10`, `9`, `12`) or alphanumeric (e.g., `Grade 10`)

### Section
- **Required**: Yes
- **Format**: 1-5 characters (e.g., `A`, `B`, `C`)

### Roll Number
- **Required**: Yes
- **Format**: Numeric only (e.g., `1`, `25`, `100`)

### Gender
- **Required**: No
- **Format**: `Male`, `Female`, `M`, or `F` (case-insensitive)

## 🔄 What Happens During Upload

1. **File Parsing**: CSV file is parsed and validated
2. **Data Mapping**: Column names are mapped to database fields
3. **Validation**: Each row is validated for required fields and formats
4. **Duplicate Check**: System checks if student already exists (by name + class + section + roll_no)
5. **Insertion**: Valid students are inserted into database
6. **Auto-Creation**: Attendance and fees records are automatically created

## 📊 Upload Results

After upload, you'll see:

- **✅ Imported**: Successfully added students
- **⚠️ Skipped**: Students that already exist (duplicates)
- **❌ Errors**: Rows with validation errors

### Error Messages

Common errors and how to fix them:

- **"Student name is required"**: Add a name in the student_name column
- **"Class is required"**: Add a class value
- **"Section is required"**: Add a section value
- **"Roll number must be numeric"**: Use numbers only (e.g., `1` not `one`)
- **"Invalid gender value"**: Use `Male`, `Female`, `M`, or `F`
- **"Student already exists"**: Student with same name, class, section, and roll_no already in database

## 💡 Tips

1. **Use the Template**: Always start with the template to ensure correct format
2. **Check for Duplicates**: The system automatically skips existing students
3. **Validate Before Upload**: Make sure all required fields are filled
4. **Use Consistent Format**: Keep class and section formats consistent
5. **Save as CSV**: Make sure your file is saved as `.csv` or `.txt` format

## 🎯 Example CSV Files

### Basic Example
```csv
student_name,class,section,roll_no
John Doe,10,A,1
Jane Smith,10,A,2
```

### With Gender
```csv
student_name,class,section,roll_no,gender
John Doe,10,A,1,Male
Jane Smith,10,A,2,Female
```

### Multiple Classes
```csv
student_name,class,section,roll_no,gender
John Doe,10,A,1,Male
Jane Smith,10,A,2,Female
Bob Johnson,9,B,1,Male
Alice Brown,9,B,2,Female
```

## 🚀 After Upload

Once students are uploaded:
- They appear in all student queries
- Attendance records are created (initialized to 0)
- Fees records are created (initialized to 0)
- You can query them immediately: "Show all students"

## ❓ Troubleshooting

**File not uploading?**
- Check file format is `.csv` or `.txt`
- Ensure file size is reasonable (< 10MB)
- Check browser console for errors

**Students not appearing?**
- Check upload results for errors
- Verify data format matches requirements
- Try querying: "Show all students"

**Duplicate errors?**
- System automatically skips duplicates
- Check if student already exists in database
- Use different roll numbers for same class/section

