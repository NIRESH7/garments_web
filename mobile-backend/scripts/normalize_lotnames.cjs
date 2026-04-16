/**
 * Migration Script: Normalize all lotName fields to UPPERCASE
 * Fixes: Inward, Outward, and StockLimit collections
 * Run: node scripts/normalize_lotnames.cjs
 */
const mongoose = require('mongoose');
require('dotenv').config();

const MONGODB_URI = process.env.MONGODB_URI;
if (!MONGODB_URI) {
  console.error('❌ MONGODB_URI not found in .env');
  process.exit(1);
}

async function run() {
  await mongoose.connect(MONGODB_URI);
  console.log('✅ Connected to MongoDB');
  const db = mongoose.connection.db;

  // --- Fix Inward collection ---
  const inwards = await db.collection('inwards').find({ lotName: { $exists: true } }).toArray();
  let inwardFixed = 0;
  for (const doc of inwards) {
    const upper = doc.lotName?.trim().toUpperCase();
    if (upper && upper !== doc.lotName) {
      await db.collection('inwards').updateOne({ _id: doc._id }, { $set: { lotName: upper } });
      inwardFixed++;
    }
  }
  console.log(`✅ Inwards: fixed ${inwardFixed} / ${inwards.length} records`);

  // --- Fix Outward collection ---
  const outwards = await db.collection('outwards').find({ lotName: { $exists: true } }).toArray();
  let outwardFixed = 0;
  for (const doc of outwards) {
    const upper = doc.lotName?.trim().toUpperCase();
    if (upper && upper !== doc.lotName) {
      await db.collection('outwards').updateOne({ _id: doc._id }, { $set: { lotName: upper } });
      outwardFixed++;
    }
  }
  console.log(`✅ Outwards: fixed ${outwardFixed} / ${outwards.length} records`);

  // --- Fix StockLimit collection ---
  const limits = await db.collection('stocklimits').find({ lotName: { $exists: true } }).toArray();
  let limitsFixed = 0;
  for (const doc of limits) {
    const upper = doc.lotName?.trim().toUpperCase();
    if (upper && upper !== doc.lotName) {
      await db.collection('stocklimits').updateOne({ _id: doc._id }, { $set: { lotName: upper } });
      limitsFixed++;
    }
  }
  console.log(`✅ StockLimits: fixed ${limitsFixed} / ${limits.length} records`);

  console.log('\n🎉 Migration complete! All lotNames are now UPPERCASE.');
  await mongoose.disconnect();
  process.exit(0);
}

run().catch((err) => {
  console.error('❌ Migration failed:', err);
  process.exit(1);
});
