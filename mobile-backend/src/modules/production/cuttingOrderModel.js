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
    // Item info
    itemName: { type: String, required: true },
    size: { type: String, required: true },
    dozen: { type: Number, default: 0 },
    neededWeight: { type: Number, default: 0 },
    // Per-set FIFO output
    lotName: { type: String },
    lotNo: { type: String },
    dia: { type: String },
    setNo: { type: Number },        // sequential global set number
    rolls: { type: Number, default: 0 },
    setWeight: { type: Number, default: 0 }, // weight for this specific set
    rackName: { type: String },
    palletNumber: { type: String },
    // Day planning
    day: { type: String },
    date: { type: String },
    // Outward tracking
    outwardId: { type: mongoose.Schema.Types.ObjectId, ref: 'Outward' },
    outwardPosted: { type: Boolean, default: false },
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
        planName: {
            type: String,
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

