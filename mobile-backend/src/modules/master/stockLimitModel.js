import mongoose from 'mongoose';

const stockLimitSchema = mongoose.Schema(
    {
        lotName: { type: String, required: true },
        dia: { type: String, required: true },
        minWeight: { type: Number, default: 0 },
        maxWeight: { type: Number, default: 0 },
        minRolls: { type: Number, default: 0 },
        maxRolls: { type: Number, default: 0 },
        manualAdjustment: { type: Number, default: 0 }, // Outside Input (Manual)
    },
    {
        timestamps: true,
    }
);

// Unique combination of lotName and dia
stockLimitSchema.index({ lotName: 1, dia: 1 }, { unique: true });

const StockLimit = mongoose.model('StockLimit', stockLimitSchema);

export default StockLimit;
