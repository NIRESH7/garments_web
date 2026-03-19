import mongoose from 'mongoose';

const MOCK_USER_ID = new mongoose.Types.ObjectId();
const FINAL_ENTRY_ID = new mongoose.Types.ObjectId();

// Basic Schemas
const colourRowSchema = new mongoose.Schema({
  colour: String,
  freshLayer: Number,
  miniLay: Number,
  miniMarkingPcs: Number,
  totalPcs: Number,
  doz: Number,
  balancePcs: Number,
  rollMtr: Number,
  actualRollMtr: Number,
  rollWT: Number,
  foldReq: Number,
  actualFolding: Number,
  foldDiff: Number,
  actRollWt: Number,
  dozWeight: Number,
  costingWeight: Number,
  weightDifference: Number,
  endBit: Number,
  mistake: Number,
  cutterWaste: Number,
  offWaste: Number,
  totalWaste: Number,
  cutWt: Number,
  finalBal: Number,
  differ: Number,
  cadEff: Number,
  actualEff: Number,
  effDifference: Number,
});

const cuttingEntrySchema = new mongoose.Schema({
    cutNo: String, trnNo: String, dyedDcNos: [String],
    itemName: String, size: String, lotNo: String, lotName: String,
    dia: String, actualDia: String, setNo: String,
    layLength: Number, miniLayLength: Number, layMarkingPcs: Number, miniMarkingPcs: Number,
    fixedGSM: Number, foldWtPerDoz: Number, colourRows: [colourRowSchema],
    stickerNo: String, status: String,
});

const page2Schema = new mongoose.Schema({
    cuttingEntryId: mongoose.Schema.Types.ObjectId,
    totalRollWeight: Number, totalFoldingWT: Number, totalDozenWT: Number,
    noOfDoz: Number, dozenPerWT: Number, endBit: Number, adas: Number,
    layWeight: Number, totalPcs: Number, cutterWasteWT: Number,
    offPatternWaste: Number, totalWasteWT: Number, wastePercent: Number,
    cutWeight: Number, cadWastePercent: Number, difference: Number,
});

const Outward = mongoose.model('OutwardFinal', new mongoose.Schema({ dcNo: String, items: Array, lotName: String, lotNo: String, dia: String }));
const CuttingEntry = mongoose.model('CuttingEntryFinal', cuttingEntrySchema);
const Page2 = mongoose.model('Page2Final', page2Schema);

async function deploy() {
    try {
        await mongoose.connect('mongodb://localhost:27017/garments_local');
        console.log('Deploying Final Test Case...');

        // 1. Create Outward DC-FINAL-46
        await Outward.deleteMany({ dcNo: 'DC-FINAL-46' });
        const outward = new Outward({
            dcNo: 'DC-FINAL-46',
            lotName: 'FINAL-AUDIT-FABRIC',
            lotNo: 'LOT-F-99',
            dia: '24',
            items: [
                {
                    set_no: 'SET-F',
                    colours: [{ colour: 'EMERALD GREEN', weight: 100, no_of_rolls: 10, roll_weight: 10 }]
                }
            ]
        });
        await outward.save();

        // 2. Create Cutting Entry (Page 1)
        await CuttingEntry.deleteMany({ lotName: 'LOT-FINAL-46' });
        const entry = new CuttingEntry({
            _id: FINAL_ENTRY_ID,
            cutNo: 'FINAL/2026/01',
            trnNo: 'TRN/FINAL/01',
            dyedDcNos: ['DC-FINAL-46'],
            itemName: 'FINAL AUDIT ITEM',
            size: '95',
            lotNo: 'LOT-F-99',
            lotName: 'LOT-FINAL-46',
            dia: '24',
            actualDia: '24.5',
            setNo: 'SET-F',
            layLength: 5.0,
            miniLayLength: 2.0,
            layMarkingPcs: 12,
            miniMarkingPcs: 4,
            fixedGSM: 180,
            foldWtPerDoz: 0.15,
            status: 'Completed',
            stickerNo: 'STK/FINAL/01',
            colourRows: [{
                colour: 'EMERALD GREEN',
                freshLayer: 10,
                miniLay: 5,
                miniMarkingPcs: 4,
                totalPcs: 140, 
                doz: 11, 
                balancePcs: 8,
                rollWT: 100.0,
                actualFolding: 5.0,
                foldReq: 1.65,
                foldDiff: 3.35,
                actRollWt: 95.0,
                dozWeight: 8.636,
                costingWeight: 8.8,
                weightDifference: 0.164,
                endBit: 1.0,
                mistake: 0.5,
                cutterWaste: 0.2,
                offWaste: 0.1,
                totalWaste: 0.3,
                cutWt: 93.0,
                finalBal: 93.2,
                differ: 0.2,
                cadEff: 97.0,
                actualEff: 96.8,
                effDifference: 0.2
            }]
        });
        await entry.save();

        // 3. Create Page 2
        await Page2.deleteMany({ cuttingEntryId: FINAL_ENTRY_ID });
        const p2 = new Page2({
            cuttingEntryId: FINAL_ENTRY_ID,
            totalRollWeight: 100.0,
            totalFoldingWT: 5.0,
            totalDozenWT: 95.0,
            noOfDoz: 11,
            dozenPerWT: 8.636,
            endBit: 1.0,
            adas: 0.5,
            layWeight: 93.5,
            totalPcs: 140,
            cutterWasteWT: 0.2,
            offPatternWaste: 0.1,
            totalWasteWT: 0.3,
            wastePercent: 0.32,
            cutWeight: 93.0,
            cadWastePercent: 3.0,
            difference: 2.68
        });
        await p2.save();

        console.log('SUCCESS: DC-FINAL-46 and associated entries deployed.');
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

deploy();
