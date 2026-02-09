import mongoose from 'mongoose';

const chatMessageSchema = new mongoose.Schema({
    user_message: { type: String, required: true },
    ai_response: { type: String, required: true },
    created_at: { type: Date, default: Date.now }
});

const searchHistorySchema = new mongoose.Schema({
    question: { type: String, required: true },
    generated_query: { type: Object },
    created_at: { type: Date, default: Date.now }
});

export const ChatMessage = mongoose.model('ChatMessage', chatMessageSchema);
export const SearchLog = mongoose.model('SearchLog', searchHistorySchema);
