import mongoose from 'mongoose';

const outwardColourSchema = mongoose.Schema({
    colour: { type: String, required: true },
    weight: { type: Number, required: true },
    no_of_rolls: { type: Number, default: 0 },
    roll_weight: { type: Number, default: 0 },
});

const outwardItemSchema = mongoose.Schema({
    set_no: { type: String, required: true },
    colours: [outwardColourSchema],
    total_weight: { type: Number, required: true },
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
