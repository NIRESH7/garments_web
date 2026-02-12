import mongoose from 'mongoose';

const diaEntrySchema = mongoose.Schema({
    dia: { type: String, required: true },
    roll: { type: Number, default: 0 },
    sets: { type: Number, default: 0 },
    delivWt: { type: Number, default: 0 },
    recRoll: { type: Number, default: 0 },
    recWt: { type: Number, default: 0 },
    rate: { type: Number, required: true },
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
        inwardNo: { type: String }, // Auto-generated ID e.g. INW-20231027-001
        qualityStatus: { type: String, default: 'OK' }, // OK or Not OK
        qualityImage: { type: String },
        complaintText: { type: String },
        complaintImage: { type: String },
        balanceImage: { type: String },
        gsmStatus: { type: String, default: 'OK' },
        gsmImage: { type: String },
        shadeStatus: { type: String, default: 'OK' },
        shadeImage: { type: String },
        washingStatus: { type: String, default: 'OK' },
        washingImage: { type: String },
        lotInchargeSignature: { type: String },
        authorizedSignature: { type: String },
        mdSignature: { type: String },

        fromParty: { type: String, required: true },
        process: { type: String },
        rate: { type: Number },
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
