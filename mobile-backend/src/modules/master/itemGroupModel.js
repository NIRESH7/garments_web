import mongoose from 'mongoose';

const itemGroupSchema = mongoose.Schema(
    {
        groupName: {
            type: String,
            required: true,
        },
        itemNames: [
            {
                type: String,
            },
        ],
        gsm: {
            type: String,
            required: true,
        },
        colours: [
            {
                type: String,
            },
        ],
        rate: {
            type: Number,
            default: 0,
        },
    },
    {
        timestamps: true,
    }
);

const ItemGroup = mongoose.model('ItemGroup', itemGroupSchema);

export default ItemGroup;
