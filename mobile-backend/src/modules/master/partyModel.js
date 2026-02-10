import mongoose from 'mongoose';

const partySchema = mongoose.Schema(
    {
        name: {
            type: String,
            required: true,
        },
        address: {
            type: String,
            required: true,
        },
        mobileNumber: {
            type: String,
            required: true,
        },
        process: {
            type: String,
            required: true,
        },
        gstIn: {
            type: String,
        },
        rate: {
            type: Number,
            required: true,
        },
    },
    {
        timestamps: true,
    }
);

const Party = mongoose.model('Party', partySchema);

export default Party;
