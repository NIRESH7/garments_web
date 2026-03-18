import mongoose from 'mongoose';

const colourRowSchema = new mongoose.Schema({
  colour: String,
  dcPcs: { type: Number, default: 0 },
  dinom: String,
  fullCutQty: { type: Number, default: 0 },
  loosePcs: { type: Number, default: 0 },
  goodPcs: { type: Number, default: 0 },
  sm: { type: Number, default: 0 },
  cm: { type: Number, default: 0 },
  shortage: { type: Number, default: 0 },
  total: { type: Number, default: 0 },
  // For approval: cut batches from weight machine
  cut1: { type: Number, default: 0 },
  cut2: { type: Number, default: 0 },
  cut3: { type: Number, default: 0 },
  cut4: { type: Number, default: 0 },
  cut5: { type: Number, default: 0 },
  cut6: { type: Number, default: 0 },
  approved: { type: Boolean, default: false },
});

const stitchingGrnSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ['delivery', 'grn', 'approval'],
      default: 'delivery',
    },
    date: { type: Date, default: Date.now },
    party: String,
    dcNo: String,
    partyDcNo: String,
    itemName: String,
    size: String,
    process: String,
    rate: { type: Number, default: 0 },
    value: { type: Number, default: 0 },
    stitchingInstruction: String,
    colourRows: [colourRowSchema],
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

const StitchingGrn = mongoose.model('StitchingGrn', stitchingGrnSchema);
export default StitchingGrn;
