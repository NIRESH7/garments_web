/**
 * SEED SCRIPT — Inserts test inward stock for FIFO testing
 * Run: node seed_inward_stock.js
 *
 * Matches:
 *  - Assignment:  NIRESH | size=67 | dia=67 | dozenWeight=56
 *  - Plan:        PLN-202602-001 | item=msd | sizes 75=122, 85=2222, 90=333
 *
 * Inserts 3 inward lots for dia=67 (NIRESH) and 2 lots for dia=85 (msd)
 */
import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

await mongoose.connect(process.env.MONGODB_URI);
console.log('✅ Connected to:', process.env.MONGODB_URI);

const db = mongoose.connection.db;

// ── Get a real User ID ────────────────────────────────────────────────────────
const user = await db.collection('users').findOne({});
if (!user) { console.error('❌ No users found. Create a user first.'); process.exit(1); }
const userId = user._id;
console.log(`✅ Using user: ${user.name || user.email} (${userId})`);

// ── Clean old test inwards to avoid duplication ───────────────────────────────
await db.collection('inwards').deleteMany({ lotNo: { $in: ['TEST-001','TEST-002','TEST-003','TEST-010','TEST-011'] } });
console.log('🧹 Cleaned old test inwards');

// ── Helper ────────────────────────────────────────────────────────────────────
function makeInward({ lotName, lotNo, dia, recRoll, recWt, racks, pallets, date }) {
  return {
    user: userId,
    inwardDate: new Date(date),
    inTime: '09:00',
    lotName,
    lotNo,
    inwardNo: `INW-${lotNo}`,
    fromParty: 'Test Supplier',
    qualityStatus: 'OK',
    gsmStatus: 'OK',
    shadeStatus: 'OK',
    washingStatus: 'OK',
    diaEntries: [{
      dia,
      roll: recRoll,
      sets: Math.floor(recRoll / 11),
      delivWt: recWt,
      recRoll,
      recWt,
      rate: 100,
    }],
    storageDetails: [{
      dia,
      racks,
      pallets,
    }],
    createdAt: new Date(date),
    updatedAt: new Date(date),
  };
}

// ── Seed Lots for NIRESH (dia=67, dozenWeight=56) ─────────────────────────────
// 11 rolls = 1 set. Each lot has 33 rolls = 3 sets.
// recWt = 33 rolls × (56 kg/set ÷ 11 rolls) = 33 × 5.09 ≈ 168 kg per lot
const nireshLots = [
  makeInward({ lotName:'NIRESH', lotNo:'TEST-001', dia:'67', recRoll:33, recWt:168, racks:['A','B'], pallets:['1','2'], date:'2025-01-10' }),
  makeInward({ lotName:'NIRESH', lotNo:'TEST-002', dia:'67', recRoll:33, recWt:168, racks:['C'],    pallets:['3'],     date:'2025-02-05' }),
  makeInward({ lotName:'NIRESH', lotNo:'TEST-003', dia:'67', recRoll:22, recWt:112, racks:['D'],    pallets:['4'],     date:'2025-03-01' }),
];

// ── Seed Lots for msd (dia=85, dozenWeight assumed 60 for msd) ────────────────
// See plan PLN-202602-001 → msd, size 85 → 2222 dozens
const msdLots = [
  makeInward({ lotName:'MSD', lotNo:'TEST-010', dia:'85', recRoll:44, recWt:240, racks:['E','F'], pallets:['1','2','3'], date:'2025-01-15' }),
  makeInward({ lotName:'MSD', lotNo:'TEST-011', dia:'85', recRoll:33, recWt:180, racks:['G'],     pallets:['4'],          date:'2025-02-20' }),
];

const allLots = [...nireshLots, ...msdLots];
const result = await db.collection('inwards').insertMany(allLots);
console.log(`\n✅ Inserted ${result.insertedCount} inward lots:\n`);

// ── Print a summary ───────────────────────────────────────────────────────────
const inserted = await db.collection('inwards').find(
  { lotNo: { $in: ['TEST-001','TEST-002','TEST-003','TEST-010','TEST-011'] } },
  { projection: { lotName:1, lotNo:1, diaEntries:1, storageDetails:1 } }
).toArray();

inserted.forEach(r => {
  const de = r.diaEntries?.[0];
  const sd = r.storageDetails?.[0];
  console.log(`  📦 ${r.lotName} / ${r.lotNo} | dia=${de?.dia} | rolls=${de?.recRoll} | weight=${de?.recWt}kg | racks=${sd?.racks?.join(',')} | pallets=${sd?.pallets?.join(',')}`);
});

console.log(`
╔══════════════════════════════════════════════════════════════════╗
║               HOW TO TEST IN THE APP                            ║
╠══════════════════════════════════════════════════════════════════╣
║  For ITEM: NIRESH                                               ║
║   • Select Plan  → any plan with NIRESH item                   ║
║   • Select Item  → NIRESH                                       ║
║   • Size        → 67  (from assignment)                         ║
║   • Dia         → 67  (auto-filled)                             ║
║   • Dozen Weight→ 56  (auto-filled)                             ║
║   • Dozen       → enter 3 to 8 (test FIFO across 3 lots)       ║
║                                                                  ║
║  For ITEM: msd                                                   ║
║   • Select Plan  → PLN-202602-001                               ║
║   • Select Item  → msd                                           ║
║   • Size        → 85                                             ║
║   • Dia         → 85  (add an assignment for msd if needed)     ║
║   • Dozen Weight→ enter manually e.g. 60                        ║
║   • Dozen       → enter 5                                        ║
║                                                                  ║
║  Then click: AUTO FIFO ALLOCATE                                  ║
╚══════════════════════════════════════════════════════════════════╝
`);

await mongoose.disconnect();
process.exit(0);
