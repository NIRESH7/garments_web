import mongoose from 'mongoose';

const partSchema = new mongoose.Schema({
  partName: String,
  noOfPunches: { type: Number, default: 0 },
  rows: [
    {
      weight: { type: Number, default: 0 },
      noOfPcs: { type: Number, default: 0 },
    },
  ],
  totalWeight: { type: Number, default: 0 },
  noOfCuts: { type: Number, default: 0 },
  avgDozWt: { type: Number, default: 0 },
});

const layBalanceSchema = new mongoose.Schema({
  noOfPunches: { type: Number, default: 0 },
  weight: { type: Number, default: 0 },
});

const cuttingEntryPage2Schema = new mongoose.Schema(
  {
    cuttingEntryId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CuttingEntry',
      required: true,
      unique: true,
    },
    totalRollWeight: { type: Number, default: 0 },
    totalFoldingWT: { type: Number, default: 0 },
    layBalanceWT: { type: Number, default: 0 },
    totalDozenWT: { type: Number, default: 0 },
    noOfDoz: { type: Number, default: 0 },
    dozenPerWT: { type: Number, default: 0 },
    endBit: { type: Number, default: 0 },
    adas: { type: Number, default: 0 },
    layWeight: { type: Number, default: 0 },
    cutWeight: { type: Number, default: 0 },
    cutterWasteWT: { type: Number, default: 0 },
    offPatternWaste: { type: Number, default: 0 },
    totalWasteWT: { type: Number, default: 0 },
    wastePercent: { type: Number, default: 0 },
    cadWastePercent: { type: Number, default: 0 },
    difference: { type: Number, default: 0 },
    parts: [partSchema],
    layBalance: [layBalanceSchema],
    partsTotal: { type: Number, default: 0 },
    layBalanceTotal: { type: Number, default: 0 },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

const CuttingEntryPage2 = mongoose.model(
  'CuttingEntryPage2',
  cuttingEntryPage2Schema
);
export default CuttingEntryPage2;
