# Gemini API Setup Guide

## Quick Setup Steps

1. **Get your free Gemini API key:**
   - Visit: https://aistudio.google.com/
   - Sign in with your Google account
   - Click "Get API key" → "Create API key"
   - Copy the API key

2. **Create `.env` file in the project root:**
   ```bash
   # Database Configuration
   DB_HOST=localhost
   DB_USER=root
   DB_PASSWORD=your_mysql_password
   DB_NAME=chatbot_db
   DB_PORT=3306

   # Gemini AI Configuration (REQUIRED for dynamic queries)
   GEMINI_API_KEY=paste_your_key_here
   GEMINI_MODEL=gemini-pro

   # Server Port
   PORT=4000
   ```

3. **Restart the server:**
   ```bash
   npm start
   ```

4. **Test in the chat UI:**
   - Open http://localhost:4000
   - Ask any question like:
     - "Total orders"
     - "Show me products above $50"
     - "Customers in New York"
     - "Revenue by product"
   - The chatbot will use Gemini to generate SQL and fetch data from your database!

## How It Works

- **Gemini AI** converts your natural language question → SQL query
- **MySQL** executes the query on your database
- **Results** are displayed in the chat interface
- **History** is saved in the `search_history` table

The chatbot is now fully dynamic - ask any question and it will generate the appropriate SQL query!

