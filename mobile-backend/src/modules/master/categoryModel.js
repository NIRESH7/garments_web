import mongoose from 'mongoose';

const categorySchema = mongoose.Schema(
    {
        name: {
            type: String,
            required: true,
            unique: true,
        },
        values: [
            {
                name: { type: String, required: true },
                photo: { type: String },
                gsm: { type: String },
            },
        ],
    },
    {
        timestamps: true,
    }
);

const Category = mongoose.model('Category', categorySchema);

export default Category;
