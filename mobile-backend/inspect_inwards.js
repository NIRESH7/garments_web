
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Inward from './src/modules/inventory/inwardModel.js';

dotenv.config();

const inspect = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to DB');

        const inwards = await Inward.find({});
        console.log(`Total Inwards: ${inwards.length}`);

        const complaints = inwards.filter(i =>
            (i.complaintText && i.complaintText !== '') ||
            (i.complaintResolution && i.complaintResolution !== '') ||
            (i.complaintReply && i.complaintReply !== '') ||
            i.qualityStatus === 'Not OK'
        );

        console.log(`Inwards with Complaints/Resolution: ${complaints.length}`);
        complaints.forEach(c => {
            console.log(JSON.stringify({
                lotNo: c.lotNo,
                lotName: c.lotName,
                qStatus: c.qualityStatus,
                compText: c.complaintText,
                compRes: c.complaintResolution,
                compRep: c.complaintReply,
                isCleared: c.isComplaintCleared
            }, null, 2));
        });

        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
};

inspect();
