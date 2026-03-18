import mongoose from 'mongoose';

const accessoriesItemAssignSchema = new mongoose.Schema(
  {
    itemName: { type: String, required: true },
    accessories: [
      {
        accessoriesGroup: String,
        accessoriesName: String,
        sizeWiseQty: [
          {
            size: String,
            qtyPerPcs: { type: Number, default: 0 },
          },
        ],
      },
    ],
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

const AccessoriesItemAssign = mongoose.model(
  'AccessoriesItemAssign',
  accessoriesItemAssignSchema
);
export default AccessoriesItemAssign;
