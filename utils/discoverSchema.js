import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config();

async function discoverSchema() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'chatbot_db',
    port: Number(process.env.DB_PORT) || 3306,
  });

  try {
    console.log(`\n📊 Discovering schema for database: ${process.env.DB_NAME || 'chatbot_db'}\n`);

    // Get all tables
    const [tables] = await connection.execute('SHOW TABLES');
    const tableNameKey = `Tables_in_${process.env.DB_NAME || 'chatbot_db'}`;

    const schema = {};

    for (const tableRow of tables) {
      const tableName = tableRow[tableNameKey];
      
      // Get columns for each table
      const [columns] = await connection.execute(`DESCRIBE ${tableName}`);
      const columnNames = columns.map(col => col.Field);
      
      schema[tableName] = columnNames;
      
      console.log(`✅ Table: ${tableName}`);
      console.log(`   Columns: ${columnNames.join(', ')}\n`);
    }

    // Generate the TABLE_METADATA object
    console.log('\n📝 Copy this to ai/queryEngine.js:\n');
    console.log('const TABLE_METADATA = {');
    for (const [table, columns] of Object.entries(schema)) {
      console.log(`  ${table}: [${columns.map(c => `'${c}'`).join(', ')}],`);
    }
    console.log('};\n');

    // Generate relationships info
    console.log('\n📋 Table Relationships (check manually):\n');
    for (const [table, columns] of Object.entries(schema)) {
      const foreignKeys = columns.filter(col => col.includes('_id') || col.toLowerCase().includes('id'));
      if (foreignKeys.length > 0) {
        console.log(`  ${table}: ${foreignKeys.join(', ')}`);
      }
    }

    await connection.end();
  } catch (error) {
    console.error('❌ Error:', error.message);
    await connection.end();
    process.exit(1);
  }
}

discoverSchema();

