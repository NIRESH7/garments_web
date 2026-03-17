import mongoose from 'mongoose';

// Sub-schema: each row in Pattern Details section
const patternRowSchema = new mongoose.Schema({
    partyName: { type: String, default: '' },
    patternImage: { type: String, default: '' },
    patternMeasurement: { type: String, default: '' },
    finishingMeasurement: { type: String, default: '' },
}, { _id: true });

const cuttingMasterSchema = new mongoose.Schema(
    {
        user: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },

        // ─── Section 1: Item Details ───────────────────────────────────────
        itemName: { type: String, required: true },
        size: { type: String, required: true },
        itemImage: { type: String, default: '' },
        dozenWeight: { type: Number, default: 0 },
        // efficiencyPct is derived: 100 - wastePercentage (stored for query/display)
        efficiencyPct: { type: Number, default: 0 },
        layPcs: { type: Number, default: 0 },

        // ─── Section 2: Lot Details ────────────────────────────────────────
        lotName: { type: String, default: '' },
        diaName: { type: String, default: '' },     // The name selected from Dia category
        knittingDia: { type: String, default: '' }, // Specific knitting dia
        cuttingDia: { type: String, default: '' },  // Specific cutting dia
        efficiency: { type: Number, default: 0 },
        wastePercentage: { type: Number, default: 0 }, // auto: 100 - efficiency
        folding: { type: Number, default: 0 },
        layLengthMeter: { type: Number, default: 0 },
        timeToComplete: { type: String, default: '' },

        // ─── Section 3: Pattern Details ────────────────────────────────────
        patternDetails: { type: [patternRowSchema], default: [] },

        // ─── Section 4: CAD File ───────────────────────────────────────────
        cadFile: { type: String, default: '' },

        // ─── Section 5: Cutting Entry Instructions ─────────────────────────
        instructionAudio: { type: String, default: '' },
        instructionText: { type: String, default: '' },
        instructionDoc: { type: String, default: '' },
    },
    {
        timestamps: true,
    }
);

const CuttingMaster = mongoose.model('CuttingMaster', cuttingMasterSchema);

export default CuttingMaster;
