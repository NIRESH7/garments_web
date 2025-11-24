# Customizing for Your Existing Database

This guide shows you how to adapt the chatbot to work with your existing database schema.

## Step 1: Discover Your Database Schema

Run the schema discovery script to see your tables and columns:

```bash
node utils/discoverSchema.js
```

This will:
- List all tables in your database
- Show all columns for each table
- Generate the `TABLE_METADATA` object you need to copy

## Step 2: Update Table Metadata

1. **Open `ai/queryEngine.js`**
2. **Find the `TABLE_METADATA` object** (around line 4-9)
3. **Replace it with your schema** from the discovery script output

Example:
```javascript
const TABLE_METADATA = {
  students: ['id', 'name', 'email', 'grade', 'enrollment_date'],
  courses: ['id', 'course_name', 'instructor', 'credits'],
  enrollments: ['id', 'student_id', 'course_id', 'enrollment_date', 'grade'],
  search_history: ['id', 'question', 'generated_sql', 'created_at']
};
```

## Step 3: Update Relationships (Optional but Recommended)

In the Gemini prompt section (around line 140), update the RELATIONSHIPS section:

```javascript
RELATIONSHIPS:
- enrollments.student_id references students.id
- enrollments.course_id references courses.id
```

## Step 4: Update Rules (Optional)

If you want to add custom rules for common queries, update the `RULES` array in `ai/queryEngine.js`.

For example, if you have a `students` table:
```javascript
{
  name: 'all students',
  match: q => q.includes('student') && !q.includes('course'),
  build: () => ({
    sql: 'SELECT id, name, email, grade FROM students ORDER BY name ASC;',
    explanation: 'Listing all students.'
  })
}
```

## Step 5: Update .env File

Make sure your `.env` file points to your database:

```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=your_database_name
DB_PORT=3306
```

## Step 6: Create search_history Table (Required)

The chatbot needs a `search_history` table to store queries. Run this SQL:

```sql
USE your_database_name;

CREATE TABLE IF NOT EXISTS search_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question TEXT NOT NULL,
  generated_sql TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Step 7: Test

1. Restart your server: `npm start`
2. Open http://localhost:4000
3. Ask questions about your database!

## Example Questions to Try

Based on your schema, try:
- "Show all [table_name]"
- "Count total [table_name]"
- "[Table1] with [condition]"
- "Join [table1] and [table2]"

## Troubleshooting

**Error: Table doesn't exist**
- Check your `DB_NAME` in `.env`
- Verify table names match exactly (case-sensitive in some systems)

**Error: Column doesn't exist**
- Run the discovery script again
- Make sure `TABLE_METADATA` matches your actual schema

**Gemini generates wrong SQL**
- Update the RELATIONSHIPS section with correct foreign keys
- Add more examples in the prompt if needed

## Need Help?

Check your database schema:
```bash
mysql -u root -p your_database_name -e "SHOW TABLES;"
mysql -u root -p your_database_name -e "DESCRIBE table_name;"
```

