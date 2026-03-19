import mongoose from 'mongoose';

const colourRowSchema = new mongoose.Schema({ colour: String });
const cuttingEntrySchema = new mongoose.Schema({
    cutNo: String,
    trnNo: String,
    stickerNo: String,
    itemName: String,
    cuttingDate: { type: Date, default: Date.now },
});

// PRE-SAVE HOOK (Copy-pasted from model for standalone test)
cuttingEntrySchema.pre('save', async function (next) {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  
  if (!this.cutNo) {
    const monthStart = new Date(year, now.getMonth(), 1);
    const monthEnd = new Date(year, now.getMonth() + 1, 0);
    const count = await mongoose.model('CuttingEntryTest').countDocuments({ 
      cuttingDate: { $gte: monthStart, $lte: monthEnd } 
    });
    this.cutNo = `${year}/${month}/${count + 1}`;
  }

  if (!this.trnNo) {
    const count = await mongoose.model('CuttingEntryTest').countDocuments({ 
      trnNo: { $regex: `^TRN/${year}/` } 
    });
    this.trnNo = `TRN/${year}/${count + 1}`;
  }

  if (!this.stickerNo) {
    const count = await mongoose.model('CuttingEntryTest').countDocuments({ 
      stickerNo: { $regex: `^STK/${year}/` } 
    });
    this.stickerNo = `STK/${year}/${count + 1}`;
  }
  next();
});

const CuttingEntry = mongoose.model('CuttingEntryTest', cuttingEntrySchema);

async function run() {
    try {
        await mongoose.connect('mongodb://localhost:27017/garments_local');
        
        console.log('Testing Auto-Gen with EMPTY strings...');
        const entry1 = new CuttingEntry({ itemName: 'TEST 1', cutNo: '', trnNo: '', stickerNo: '' });
        await entry1.save();
        console.log('Result 1 - Cut No:', entry1.cutNo, 'TRN No:', entry1.trnNo, 'STK No:', entry1.stickerNo);

        console.log('Testing Auto-Gen with UNDEFINED fields...');
        const entry2 = new CuttingEntry({ itemName: 'TEST 2' });
        await entry2.save();
        console.log('Result 2 - Cut No:', entry2.cutNo, 'TRN No:', entry2.trnNo, 'STK No:', entry2.stickerNo);

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

run();
