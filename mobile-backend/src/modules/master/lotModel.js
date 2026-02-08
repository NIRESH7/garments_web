import mongoose from 'mongoose';

const lotSchema = mongoose.Schema(
    {
        lotNumber: { type: String, required: true, unique: true },
        partyName: { type: String, required: true },
        process: { type: String, required: true },
        remarks: { type: String },
    },
    {
        timestamps: true,
    }
);

const Lot = mongoose.model('Lot', lotSchema);

export default Lot;
