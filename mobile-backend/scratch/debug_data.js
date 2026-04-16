import mongoose from 'mongoose';
import Outward from '../src/modules/inventory/outwardModel.js';
import Inward from '../src/modules/inventory/inwardModel.js';
import dotenv from 'dotenv';
dotenv.config();

async function debugData() {
    try {
        const uri = "mongodb+srv://deepaks24062000_db_user:deepak%4024@cluster0.ffresp2.mongodb.net/garments_mobile";
        await mongoose.connect(uri);
        
        const lotNo = "2526/00140";
        const dia = "32";
        
        const inws = await Inward.find({ lotNo: new RegExp(lotNo.replace('/', '\\/'), 'i') });
        console.log(`Inwards: ${inws.length}`);
        inws.forEach(i => {
            i.storageDetails?.forEach(sd => {
                if (sd.dia === dia) {
                    sd.rows?.forEach(r => console.log(`Inward Set Weights:`, r.setWeights));
                }
            });
        });

        const outs = await Outward.find({ lotNo: new RegExp(lotNo.replace('/', '\\/'), 'i') });
        console.log(`Outwards (any DIA): ${outs.length}`);
        outs.forEach(o => {
            console.log(`DC: ${o.dcNo}, DIA: [${o.dia}], Items:`, JSON.stringify(o.items.map(it => ({ set: it.set_no, wt: it.total_weight }))));
        });

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}
debugData();
