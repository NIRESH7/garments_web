import mongoose from 'mongoose';

const stitchingDeliverySchema = new mongoose.Schema(
  {
    dcNo: { type: String, unique: true },
    dcDate: { type: Date, default: Date.now },
    cutNo: { type: String },
    itemName: { type: String },
    size: { type: String },
    lotNo: { type: String },
    hsnCode: { type: String },
    dia: { type: String },
    vehicleNo: { type: String },
    ratePerKg: { type: Number, default: 0 },
    process: { type: String },
    totalValue: { type: Number, default: 0 },
    foldingReqPerDozen: { type: Number, default: 0 },
    colourRows: [
      {
        colour: String,
        pcs: { type: Number, default: 0 },
        foldingReqWt: { type: Number, default: 0 },
        foldingActualWt: { type: Number, default: 0 },
        elasticReqPcs: { type: Number, default: 0 },
        elasticReqMtr: { type: Number, default: 0 },
      },
    ],
    cutDetails: [
      {
        partName: String,
        noOfBundles: { type: Number, default: 0 },
        weight: { type: Number, default: 0 },
      },
    ],
    partWiseDetail: [
      {
        partName: String,
        rows: [
          {
            noOfPunches: { type: Number, default: 0 },
            weight: { type: Number, default: 0 },
            noOfPcs: { type: Number, default: 0 },
          },
        ],
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
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

stitchingDeliverySchema.pre('save', async function () {
  if (!this.dcNo) {
    const count = await mongoose.model('StitchingDelivery').countDocuments();
    const now = new Date();
    const yr = String(now.getFullYear()).slice(2);
    const nyr = String(now.getFullYear() + 1).slice(2);
    this.dcNo = `${yr}${nyr}/${String(count + 1).padStart(5, '0')}`;
  }
});

const StitchingDelivery = mongoose.model(
  'StitchingDelivery',
  stitchingDeliverySchema
);
export default StitchingDelivery;
