import mongoose from 'mongoose';
import Inward from '../src/modules/inventory/inwardModel.js';
import Outward from '../src/modules/inventory/outwardModel.js';
import dotenv from 'dotenv';
dotenv.config();

async function checkBalance() {
    try {
        const uri = "mongodb+srv://deepaks24062000_db_user:deepak%4024@cluster0.ffresp2.mongodb.net/garments_mobile";
        await mongoose.connect(uri);
        
        const lotNo = '2526/00140';
        const dia = '32';
        
        console.log(`\n--- SEARCHING FOR: Lot: ${lotNo}, DIA: ${dia} ---`);
        
        const inwards = await Inward.find({ 
            lotNo: new RegExp(lotNo.replace('/', '\\/'), 'i')
        });
        
        console.log(`Inwards found: ${inwards.length}`);
        
        const inWeights = {};
        inwards.forEach(inw => {
            console.log(`Found Inward: ${inw.lotNo}`);
            inw.storageDetails?.forEach(sd => {
                if (sd.dia === dia || sd.dia == parseInt(dia)) {
                    sd.rows?.forEach(row => {
                        row.setWeights?.forEach((w, idx) => {
                            const weight = parseFloat(w) || 0;
                            if (weight > 0) {
                                const key = `Set ${idx + 1}`;
                                inWeights[key] = (inWeights[key] || 0) + weight;
                            }
                        });
                    });
                }
            });
        });
        
        console.log('Inward Sets:', inWeights);
        
        const outwards = await Outward.find({ 
            lotNo: new RegExp(lotNo.replace('/', '\\/'), 'i'),
            dia: new RegExp(dia, 'i')
        });
        console.log(`Outwards found: ${outwards.length}`);
        
        const outWeights = {};
        outwards.forEach(out => {
            console.log(`  Outward DC: ${out.dcNo}`);
            out.items?.forEach(item => {
                let sVal = item.set_no.toString().toLowerCase().replace('set', '').trim();
                const key = `Set ${parseInt(sVal, 10)}`;
                const weight = parseFloat(item.total_weight) || 0;
                outWeights[key] = (outWeights[key] || 0) + weight;
                console.log(`    Item: ${key}, Weight: ${weight}`);
            });
        });
        
        console.log('Outward Sets:', outWeights);
        
        console.log('\n--- FINAL BALANCE ---');
        const allSets = new Set([...Object.keys(inWeights), ...Object.keys(outWeights)]);
        Array.from(allSets).sort((a,b) => {
           const na = parseInt(a.replace('Set ', ''));
           const nb = parseInt(b.replace('Set ', ''));
           return na - nb;
        }).forEach(set => {
            const inW = inWeights[set] || 0;
            const outW = outWeights[set] || 0;
            console.log(`${set}: In=${inW.toFixed(2)}, Out=${outW.toFixed(2)}, Balance=${(inW - outW).toFixed(2)}`);
        });

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

checkBalance();
