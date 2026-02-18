import mongoose from 'mongoose';

const cuttingEntrySchema = mongoose.Schema({
    itemName: { type: String, required: true },
    sizeQuantities: {
        '75': { type: Number, default: 0 },
        '80': { type: Number, default: 0 },
        '85': { type: Number, default: 0 },
        '90': { type: Number, default: 0 },
        '95': { type: Number, default: 0 },
        '100': { type: Number, default: 0 },
        '105': { type: Number, default: 0 },
        '110': { type: Number, default: 0 },
    },
    total: { type: Number, default: 0 },
});

const lotRequirementSchema = mongoose.Schema({
    itemName: { type: String },
    size: { type: String },
    dozen: { type: Number },
    dia: { type: String },
    dozenWt: { type: Number },
    totalWt: { type: Number },
    roll: { type: Number },
    set: { type: Number },
    lotNumber: { type: String },
    lotName: { type: String },
    setNumber: { type: String },
    rackName: { type: String },
    palletNo: { type: String },
});

const cuttingOrderSchema = mongoose.Schema(
    {
        user: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },
        date: {
            type: Date,
            required: true,
            default: Date.now,
        },
        cuttingEntries: [cuttingEntrySchema],
        lotRequirements: [lotRequirementSchema],
    },
    {
        timestamps: true,
    }
);

const CuttingOrder = mongoose.model('CuttingOrder', cuttingOrderSchema);

export default CuttingOrder;
