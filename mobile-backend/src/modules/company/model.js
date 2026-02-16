import mongoose from 'mongoose';

const companySchema = mongoose.Schema(
    {
        name: {
            type: String,
            required: true,
            default: 'My Company',
        },
        address: { type: String },
        mobileNumber: { type: String },
        email: { type: String },
        headerText: { type: String },
        logo: { type: String }, // Path to uploaded logo
    },
    {
        timestamps: true,
    }
);

const Company = mongoose.model('Company', companySchema);

export default Company;
