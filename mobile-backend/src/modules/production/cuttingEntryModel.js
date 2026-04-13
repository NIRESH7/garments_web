import mongoose from 'mongoose';

const colourRowSchema = new mongoose.Schema({
  colour: String,
  colourImage: String,
  freshLayer: { type: Number, default: 0 },
  miniLay: { type: Number, default: 0 },
  totalPcs: { type: Number, default: 0 },
  doz: { type: Number, default: 0 },
  balancePcs: { type: Number, default: 0 },
  complaintInRoll: { type: String, default: '' }, // Changed to string for Manual/Audio/Image info
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
  dozWeight: { type: Number, default: 0 },
  costingWeight: { type: Number, default: 0 },
  weightDifference: { type: Number, default: 0 },
  cadEff: { type: Number, default: 0 },
  actualEff: { type: Number, default: 0 },
  effDifference: { type: Number, default: 0 },
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
    lotName: { type: String },
    slipCheckedBy: { type: String },
    enteredBy: { type: String },
    enteredDate: { type: Date },
    authorizedSign: { type: String },
    inchargeSign: { type: String },
    stickerNo: { type: String },
    cutterWasteWT: { type: Number, default: 0 },
    offPatternWaste: { type: Number, default: 0 },
    totalWasteWT: { type: Number, default: 0 },
    wastePercent: { type: Number, default: 0 },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

// Auto-generate cutNo, trnNo, and stickerNo before saving
cuttingEntrySchema.pre('save', async function () {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  
  const shortYear = String(year).slice(2);
  const nextYearValue = String(year + 1).slice(2);
  const currentFiscal = `${shortYear}-${nextYearValue}`;

  if (!this.cutNo || this.cutNo.trim() === '') {
    // Count for current month
    const monthStart = new Date(year, now.getMonth(), 1);
    const monthEnd = new Date(year, now.getMonth() + 1, 0);
    const count = await mongoose.model('CuttingEntry').countDocuments({ 
      cuttingDate: { $gte: monthStart, $lte: monthEnd } 
    });
    this.cutNo = `${year}/${month}/${count + 1}`;
    this.fiscalYear = currentFiscal;
  }

  if (!this.trnNo || this.trnNo.trim() === '') {
    const count = await mongoose.model('CuttingEntry').countDocuments({ 
      trnNo: { $regex: `^TRN/${year}/` } 
    });
    this.trnNo = `TRN/${year}/${count + 1}`;
  }

  if (!this.stickerNo) {
    const count = await mongoose.model('CuttingEntry').countDocuments({ 
      stickerNo: { $regex: `^STK/${year}/` } 
    });
    this.stickerNo = `STK/${year}/${count + 1}`;
  }
});

const CuttingEntry = mongoose.model('CuttingEntry', cuttingEntrySchema);
export default CuttingEntry;
