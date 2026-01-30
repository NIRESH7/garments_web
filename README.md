<<<<<<< HEAD
# garments

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# garments
=======
## AI SQL Chatbot

Natural-language chatbot that answers questions about your MySQL data. It converts user prompts into SQL (rule-based with optional Ollama) and returns formatted answers in a chat-style UI.

### Features

- Express + MySQL backend with connection pooling
- Rule-based NL → SQL engine plus optional Ollama integration
- Gemini fallback for richer NL → SQL (set `GEMINI_API_KEY`)
- Query execution with human-readable summaries
- Search history stored in MySQL
- Modern web chat UI with loading animation

### Project Structure

- `server.js` – Express entrypoint
- `config/db.js` – MySQL pool helper
- `ai/queryEngine.js` – NL → SQL logic (rule-based + Ollama fallback)
  - Order: Gemini → Ollama → heuristics, ensuring every prompt is answered.
- `routes/chat.js` – API endpoints (`POST /api/chat`, `GET /api/chat/history`)
- `utils/resultFormatter.js` – Formats SQL results for chat
- `public/` – Static chat frontend
- `database/schema.sql` – Tables + dummy data

### Prerequisites

- Node.js 18+
- MySQL 8 (or 5.7+)
- (Optional) [Ollama](https://ollama.ai) running locally with a SQL-capable model

### Setup

1. **Install dependencies**
   ```bash
   npm install
   ```
2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env and add:
   # - Your MySQL credentials (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME)
   # - Your Gemini API key (GEMINI_API_KEY) - Get free key from https://aistudio.google.com/
   ```
3. **Provision database**
   ```bash
   mysql -u root -p < database/schema.sql
   ```
4. **Start server**
   ```bash
   npm start
   ```
5. **Open UI**
   Visit `http://localhost:4000` (or configured port).

### API

- `POST /api/chat` – `{ message }` → `{ sql, strategy, explanation, data, formatted }`
- `GET /api/chat/history` – returns last 10 queries and SQL.

### Gemini AI Setup (Recommended - Primary Method)

1. Get a free API key from [Google AI Studio](https://aistudio.google.com/)
2. Add to `.env`: `GEMINI_API_KEY=your_key_here`
3. The chatbot will use Gemini to convert natural language to SQL queries
4. Gemini handles any question dynamically - no static rules needed!

### Optional Ollama (Fallback)

1. `ollama pull sqlcoder` (or your preferred model)
2. Set `OLLAMA_MODEL=sqlcoder` in `.env`
3. Chatbot will use Ollama if Gemini is unavailable, then fallback to built-in rules.

### Testing Prompts

- `Show today sales`
- `Low stock products`
- `Orders for customer Alice`
- `Customers in Chicago`

### Notes

- Customize `RULES` inside `ai/queryEngine.js` for domain-specific intents.
- Improve formatting via `utils/resultFormatter.js`.
- Protect database credentials before deploying publicly.
- To enable Gemini, add `GEMINI_API_KEY` (from Google AI Studio) and optional `GEMINI_MODEL` to `.env`. The server will prefer Gemini, then Ollama, then the rule set.

# custom_chat_bot
>>>>>>> 718bc0563775714a2f33e273a03899f9f8bcdd42
