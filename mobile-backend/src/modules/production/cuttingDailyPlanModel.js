import mongoose from 'mongoose';

const planRowSchema = new mongoose.Schema({
  lotName: String,
  lotNo: String,
  dia: String,
  setNo: String,
  itemName: String,
  size: String,
  dozen: { type: Number, default: 0 },
  layLength: { type: Number, default: 0 },
  layPcs: { type: Number, default: 0 },
  timing: String,
  machineNo: String,
  approval: { type: Boolean, default: false },
  actualTimeTaken: String,
  diff: String,
  spreadingLayStatus: {
    type: String,
    enum: ['Pending', 'In Progress', 'Completed'],
    default: 'Pending',
  },
});

const cuttingDailyPlanSchema = new mongoose.Schema(
  {
    date: { type: Date, required: true },
    planRows: [planRowSchema],
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

const CuttingDailyPlan = mongoose.model('CuttingDailyPlan', cuttingDailyPlanSchema);
export default CuttingDailyPlan;
