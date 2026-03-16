import mongoose from 'mongoose';

const groupSetupSchema = new mongoose.Schema({
  date: { type: Date, default: Date.now },
  group: { type: String, required: true },
  accessory: { type: String, required: true },
  hsnCode: { type: String },
  unit: { type: String },
  tax: { type: String },
  rate: { type: Number },
  usedIn: { type: String, enum: ['stiching', 'cutting', 'othetrs'] },
  maxStock: { type: Number },
  minStock: { type: Number },
  supplier: { type: String },
  productSpec: { type: String },
  colors: [String] // For when group is 'elastic'
});

const itemAssignmentSchema = new mongoose.Schema({
  itemName: { type: String, required: true },
  group: { type: String, required: true },
  accessoryName: { type: String, required: true },
  size: { type: String },
  qtyPerPiece: { type: Number },
  sizeWiseQuantities: {
    '75': { type: Number, default: 0 },
    '80': { type: Number, default: 0 },
    '85': { type: Number, default: 0 },
    '90': { type: Number, default: 0 },
    '95': { type: Number, default: 0 },
    '100': { type: Number, default: 0 },
    '105': { type: Number, default: 0 },
    '110': { type: Number, default: 0 }
  }
});

const accessoriesMasterSchema = new mongoose.Schema({
  groupSetup: [groupSetupSchema],
  itemAssignment: [itemAssignmentSchema],
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
}, { timestamps: true });

const AccessoriesMaster = mongoose.model('AccessoriesMaster', accessoriesMasterSchema);

export default AccessoriesMaster;
