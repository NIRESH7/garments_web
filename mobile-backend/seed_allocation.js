/**
 * SEED FULL ALLOCATION — Creates a complete lot allocation for Monday
 * using NIRESH (TEST-001, TEST-002) and MSD (TEST-010) inward stock.
 * Run: node seed_allocation.js
 */
import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

await mongoose.connect(process.env.MONGODB_URI);
const db = mongoose.connection.db;

// ── Find the plan ─────────────────────────────────────────────────────────────
const plan = await db.collection('cuttingorders').findOne({ planId: 'PLN-202602-001' });
if (!plan) { console.error('❌ Plan PLN-202602-001 not found'); process.exit(1); }
console.log(`✅ Found plan: ${plan.planId} (${plan._id})`);

// ── Build lot allocation rows (what FIFO would produce) ───────────────────────
// NIRESH | size=67 | dia=67 | dozenWeight=56 | 5 dozen
// requiredWeight = 5 × 56 = 280 kg
// TEST-001: 168 kg → covers sets 1,2,3 (33 rolls, 3 sets)
// TEST-002: 112 kg remaining → covers sets 4,5 (partial)

const today = '2026-02-28';

const allocations = [
  // NIRESH — Monday — from TEST-001 (3 sets)
  { lotName:'NIRESH', lotNo:'TEST-001', dia:'67', setNo:1, rolls:11, setWeight:56.00, rackName:'A, B', palletNumber:'1, 2', lotBalance:0,
    day:'Monday', date: today, itemName:'NIRESH', size:'67', dozen:5, neededWeight:280, outwardPosted:false },
  { lotName:'NIRESH', lotNo:'TEST-001', dia:'67', setNo:2, rolls:11, setWeight:56.00, rackName:'A, B', palletNumber:'1, 2', lotBalance:0,
    day:'Monday', date: today, itemName:'NIRESH', size:'67', dozen:5, neededWeight:280, outwardPosted:false },
  { lotName:'NIRESH', lotNo:'TEST-001', dia:'67', setNo:3, rolls:11, setWeight:56.00, rackName:'A, B', palletNumber:'1, 2', lotBalance:0,
    day:'Monday', date: today, itemName:'NIRESH', size:'67', dozen:5, neededWeight:280, outwardPosted:false },
  // NIRESH — Monday — from TEST-002 (2 sets)
  { lotName:'NIRESH', lotNo:'TEST-002', dia:'67', setNo:4, rolls:11, setWeight:56.00, rackName:'C', palletNumber:'3', lotBalance:56,
    day:'Monday', date: today, itemName:'NIRESH', size:'67', dozen:5, neededWeight:280, outwardPosted:false },
  { lotName:'NIRESH', lotNo:'TEST-002', dia:'67', setNo:5, rolls: 6, setWeight:30.55, rackName:'C', palletNumber:'3', lotBalance:25,
    day:'Monday', date: today, itemName:'NIRESH', size:'67', dozen:5, neededWeight:280, outwardPosted:false },

  // MSD — Wednesday — from TEST-010 (4 sets)
  { lotName:'MSD', lotNo:'TEST-010', dia:'85', setNo:1, rolls:11, setWeight:60.00, rackName:'E', palletNumber:'1', lotBalance:0,
    day:'Wednesday', date: today, itemName:'msd', size:'85', dozen:4, neededWeight:240, outwardPosted:false },
  { lotName:'MSD', lotNo:'TEST-010', dia:'85', setNo:2, rolls:11, setWeight:60.00, rackName:'E', palletNumber:'2', lotBalance:0,
    day:'Wednesday', date: today, itemName:'msd', size:'85', dozen:4, neededWeight:240, outwardPosted:false },
  { lotName:'MSD', lotNo:'TEST-010', dia:'85', setNo:3, rolls:11, setWeight:60.00, rackName:'F', palletNumber:'2', lotBalance:0,
    day:'Wednesday', date: today, itemName:'msd', size:'85', dozen:4, neededWeight:240, outwardPosted:false },
  { lotName:'MSD', lotNo:'TEST-010', dia:'85', setNo:4, rolls:11, setWeight:60.00, rackName:'F', palletNumber:'3', lotBalance:0,
    day:'Wednesday', date: today, itemName:'msd', size:'85', dozen:4, neededWeight:240, outwardPosted:false },
];

// ── Clear any previous test allocations and push new ones ─────────────────────
await db.collection('cuttingorders').updateOne(
  { _id: plan._id },
  { $pull: { lotAllocations: { lotNo: { $in: ['TEST-001','TEST-002','TEST-010','TEST-011'] } } } }
);

await db.collection('cuttingorders').updateOne(
  { _id: plan._id },
  { $push: { lotAllocations: { $each: allocations } } }
);

console.log(`✅ Pushed ${allocations.length} allocation rows into plan ${plan.planId}`);
console.log(`
╔══════════════════════════════════════════════════════════╗
║              ALLOCATION SUMMARY                         ║
╠══════════════════════════════════════════════════════════╣
║  MONDAY  → NIRESH | size=67 | 5 dozen | 5 sets          ║
║           TEST-001: Sets 1,2,3 → racks A,B | 168 kg     ║
║           TEST-002: Sets 4,5   → rack  C   | 86.55 kg   ║
║                                                          ║
║  WEDNESDAY → msd | size=85 | 4 dozen | 4 sets           ║
║           TEST-010: Sets 1-4   → racks E,F | 240 kg     ║
╠══════════════════════════════════════════════════════════╣
║  NOW GO TO APP:                                          ║
║  REPORT tab → Select PLN-202602-001 → LOAD REPORT       ║
╚══════════════════════════════════════════════════════════╝
`);

await mongoose.disconnect();
process.exit(0);
