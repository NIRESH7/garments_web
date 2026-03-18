import mongoose from 'mongoose';

const colourRowSchema = new mongoose.Schema({
  colour: String,
  colourImage: String,
  freshLayer: { type: Number, default: 0 },
  miniLay: { type: Number, default: 0 },
  totalPcs: { type: Number, default: 0 },
  doz: { type: Number, default: 0 },
  balancePcs: { type: Number, default: 0 },
  complaintInRoll: { type: Number, default: 0 },
  complaintAudio: String,
  complaintImage: String,
  returnWT: { type: Number, default: 0 },
  rollMtr: { type: Number, default: 0 },
  actualRollMtr: { type: Number, default: 0 },
  rollMtrDiff: { type: Number, default: 0 },
  rollWT: { type: Number, default: 0 },
  foldReq: { type: Number, default: 0 },
  actualFolding: { type: Number, default: 0 },
  foldDiff: { type: Number, default: 0 },
  actRollWt: { type: Number, default: 0 },
  endBit: { type: Number, default: 0 },
  mistake: { type: Number, default: 0 },
  layBal: { type: Number, default: 0 },
  cutterWaste: { type: Number, default: 0 },
  offWaste: { type: Number, default: 0 },
  totalWaste: { type: Number, default: 0 },
  cutWt: { type: Number, default: 0 },
  finalBal: { type: Number, default: 0 },
  differ: { type: Number, default: 0 },
});

const cuttingEntrySchema = new mongoose.Schema(
  {
    serialNo: { type: String },
    cutNo: { type: String, unique: true },
    fiscalYear: { type: String },
    dyedDcNos: [{ type: String }],
    cuttingDate: { type: Date, default: Date.now },
    weightDate: { type: Date },
    lotNo: { type: String },
    dia: { type: String },
    actualDia: { type: String },
    setNo: { type: String },
    trnNo: { type: String },
    itemName: { type: String, required: true },
    size: { type: String },
    cutterStartTime: { type: String },
    cutterEndTime: { type: String },
    rackName: { type: String },
    palletNo: { type: String },
    layMasterName: { type: String },
    layLength: { type: Number, default: 0 },
    miniLayLength: { type: Number, default: 0 },
    layMarkingPcs: { type: Number, default: 0 },
    miniMarkingPcs: { type: Number, default: 0 },
    fixedTimeToFinishLay: { type: String },
    fixedGSM: { type: Number, default: 0 },
    foldWtPerDoz: { type: Number, default: 0 },
    colourRows: [colourRowSchema],
    remarks: { type: String },
    status: {
      type: String,
      enum: ['Pending', 'In Progress', 'Completed'],
      default: 'Pending',
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

// Auto-generate cutNo before saving
cuttingEntrySchema.pre('save', async function () {
  if (!this.cutNo) {
    const count = await mongoose.model('CuttingEntry').countDocuments();
    const year = new Date().getFullYear();
    const shortYear = String(year).slice(2);
    const nextYear = String(year + 1).slice(2);
    this.fiscalYear = `${shortYear}-${nextYear}`;
    this.cutNo = String(count + 1).padStart(4, '0');
  }
});

const CuttingEntry = mongoose.model('CuttingEntry', cuttingEntrySchema);
export default CuttingEntry;
