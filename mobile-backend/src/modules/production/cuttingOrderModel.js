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
    totalDozens: { type: Number, default: 0 },
});

const lotAllocationSchema = mongoose.Schema({
    itemName: { type: String, required: true },
    size: { type: String, required: true },
    dozen: { type: Number, required: true },
    // Fields from FIFO logic
    lotName: { type: String },
    lotNo: { type: String },
    dia: { type: String },
    rackName: { type: String },
    palletNumber: { type: String },
    allocationId: { type: String }, // For tracking
    day: { type: String },
    date: { type: String },
    time: { type: String },
    setNum: { type: String },
});

const cuttingOrderSchema = mongoose.Schema(
    {
        user: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },
        planId: {
            type: String,
            required: true,
            unique: true,
        },
        planType: {
            type: String,
            enum: ['Monthly', 'Yearly'],
            required: true,
        },
        planPeriod: {
            type: String, // e.g., "2026-02" or "2026"
            required: true,
        },
        date: {
            type: Date,
            required: true,
            default: Date.now,
        },
        startDate: {
            type: Date,
        },
        endDate: {
            type: Date,
        },
        cuttingEntries: [cuttingEntrySchema],
        lotAllocations: [lotAllocationSchema],
    },
    {
        timestamps: true,
    }
);

const CuttingOrder = mongoose.model('CuttingOrder', cuttingOrderSchema);

export default CuttingOrder;

