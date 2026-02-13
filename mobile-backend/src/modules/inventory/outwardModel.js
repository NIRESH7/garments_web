import mongoose from 'mongoose';

const outwardItemSchema = mongoose.Schema({
    colour: { type: String, required: false },
    selected_weight: { type: Number, required: true },
    set_no: { type: String, required: true },
    roll_weight: { type: Number },
    no_of_rolls: { type: Number },
});

const outwardSchema = mongoose.Schema(
    {
        user: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },
        dcNo: {
            type: String,
            required: true,
            unique: true
        },
        lotName: { type: String, required: true },
        dateTime: { type: Date, required: true },
        dia: { type: String, required: true },
        lotNo: { type: String, required: true },
        partyName: { type: String, required: true },
        process: { type: String },
        address: { type: String },
        vehicleNo: { type: String },
        inTime: { type: String },
        outTime: { type: String },
        items: [outwardItemSchema],
    },
    {
        timestamps: true,
    }
);

const Outward = mongoose.model('Outward', outwardSchema);

export default Outward;
