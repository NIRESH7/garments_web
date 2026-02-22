import mongoose from 'mongoose';

const replySchema = mongoose.Schema({
    workerName: { type: String, required: true },
    replyText: { type: String },
    voiceReplyUrl: { type: String },
    submittedAt: { type: Date, default: Date.now },
    type: { type: String, enum: ['Progress', 'Client', 'Completion'], default: 'Progress' },
});

const taskSchema = mongoose.Schema(
    {
        admin: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },
        title: { type: String, required: true },
        description: { type: String },
        voiceDescriptionUrl: { type: String },
        assignedTo: { type: String, default: 'All' }, // Could be a specific role or user
        priority: { type: String, enum: ['Low', 'Medium', 'High'], default: 'Medium' },
        status: { type: String, enum: ['To Do', 'In Progress', 'Completed'], default: 'To Do' },
        deadline: { type: Date },
        attachmentUrl: { type: String },
        replies: [replySchema],
    },
    {
        timestamps: true,
    }
);

const Task = mongoose.model('Task', taskSchema);

export default Task;
