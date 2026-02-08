import mongoose from 'mongoose';

const supportTicketSchema = mongoose.Schema(
    {
        user: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },
        subject: { type: String, required: true },
        description: { type: String, required: true },
        status: {
            type: String,
            enum: ['open', 'in-progress', 'closed'],
            default: 'open',
        },
        messages: [
            {
                sender: { type: String, enum: ['user', 'agent'] },
                message: { type: String },
                timestamp: { type: Date, default: Date.now },
            },
        ],
    },
    {
        timestamps: true,
    }
);

const SupportTicket = mongoose.model('SupportTicket', supportTicketSchema);

export default SupportTicket;
