import mongoose from 'mongoose';

const ironPackingDcSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ['outward', 'inward'],
      default: 'outward',
    },
    packingDcNo: { type: String, unique: true },
    date: { type: Date, default: Date.now },
    itemName: String,
    size: String,
    cutNo: String,
    party: String,
    process: String,
    rate: { type: Number, default: 0 },
    value: { type: Number, default: 0 },
    colourRows: [
      {
        colour: String,
        totalPcs: { type: Number, default: 0 },
      },
    ],
    accessories: [
      {
        accessoriesName: String,
        size: String,
        reqQty: { type: Number, default: 0 },
        dcQty: { type: Number, default: 0 },
      },
    ],
    remarks: String,
    // Inward (GRN) fields
    partyDcNo: String,
    dcQty: { type: Number, default: 0 },
    box: { type: Number, default: 0 },
    loosePcs: { type: Number, default: 0 },
    goodPcs: { type: Number, default: 0 },
    packingMistake: { type: Number, default: 0 },
    sm: { type: Number, default: 0 },
    cm: { type: Number, default: 0 },
    shortage: { type: Number, default: 0 },
    receivedPcs: { type: Number, default: 0 },
    approval: { type: Boolean, default: false },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

ironPackingDcSchema.pre('save', async function () {
  if (!this.packingDcNo) {
    const count = await mongoose.model('IronPackingDc').countDocuments();
    const now = new Date();
    const yr = String(now.getFullYear()).slice(2);
    const nyr = String(now.getFullYear() + 1).slice(2);
    this.packingDcNo = `PKG-${yr}${nyr}/${String(count + 1).padStart(5, '0')}`;
  }
});

const IronPackingDc = mongoose.model('IronPackingDc', ironPackingDcSchema);
export default IronPackingDc;
