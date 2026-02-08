import mongoose from 'mongoose';

const assignmentSchema = mongoose.Schema(
    {
        user: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },
        fabricItem: {
            type: String,
            required: true,
        },
        size: {
            type: String,
            required: true,
        },
        dia: {
            type: String,
            required: true,
        },
        efficiency: {
            type: Number,
            required: true,
        },
        dozenWeight: {
            type: Number,
            required: true,
            default: 0.0,
        },
    },
    {
        timestamps: true,
    }
);

const Assignment = mongoose.model('Assignment', assignmentSchema);

export default Assignment;
