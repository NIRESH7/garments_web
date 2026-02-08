import mongoose from 'mongoose';

const diaEntrySchema = mongoose.Schema({
    dia: { type: String, required: true },
    roll: { type: Number, default: 0 },
    sets: { type: Number, default: 0 },
    delivWt: { type: Number, default: 0 },
    recRoll: { type: Number, default: 0 },
    recWt: { type: Number, default: 0 },
});

const inwardSchema = mongoose.Schema(
    {
        user: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },
        inwardDate: { type: Date, required: true },
        inTime: { type: String, required: true },
        outTime: { type: String },
        lotName: { type: String, required: true },
        lotNo: { type: String, required: true },
        fromParty: { type: String, required: true },
        process: { type: String },
        vehicleNo: { type: String },
        partyDcNo: { type: String },
        diaEntries: [diaEntrySchema],
        storageDetails: {
            type: Object, // Placeholder for the second page of the form
        },
    },
    {
        timestamps: true,
    }
);

const Inward = mongoose.model('Inward', inwardSchema);

export default Inward;
