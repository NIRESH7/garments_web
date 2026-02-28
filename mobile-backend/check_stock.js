import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

await mongoose.connect(process.env.MONGODB_URI);

const db = mongoose.connection.db;

// 1. Inward stock with positive balance
console.log('\n=== INWARD STOCK (balance > 0) ===');
const inwards = await db.collection('inwards').find(
  { balance: { $gt: 0 } },
  { projection: { lotName:1, lotNo:1, dia:1, itemName:1, size:1, balance:1, rackName:1, palletNumber:1 } }
).limit(30).toArray();

if(inwards.length === 0) {
  const all = await db.collection('inwards').find({}, { projection: { lotName:1, lotNo:1, dia:1, itemName:1, size:1, balance:1 }}).limit(10).toArray();
  console.log('No inwards with balance>0. Sample inwards:', JSON.stringify(all, null, 2));
} else {
  inwards.forEach(r => console.log(`  lotName=${r.lotName} | lotNo=${r.lotNo} | dia=${r.dia} | itemName=${r.itemName} | size=${r.size} | balance=${r.balance} | rack=${r.rackName} | pallet=${r.palletNumber}`));
}

// 2. Cutting orders (plans)
console.log('\n=== CUTTING ORDERS / PLANS ===');
const plans = await db.collection('cuttingorders').find({}, { projection: { planId:1, planName:1, planType:1, planPeriod:1, 'cuttingEntries.itemName':1, 'cuttingEntries.sizeQuantities':1 }}).limit(5).toArray();
plans.forEach(p => {
  console.log(`  planId=${p.planId} | name=${p.planName} | type=${p.planType}`);
  (p.cuttingEntries||[]).forEach(e => console.log(`    item=${e.itemName} | sizes=${JSON.stringify(e.sizeQuantities)}`));
});

// 3. Assignments
console.log('\n=== ASSIGNMENTS ===');
const assigns = await db.collection('assignments').find({},{projection:{fabricItem:1,size:1,dia:1,dozenWeight:1}}).limit(10).toArray();
assigns.forEach(a => console.log(`  item=${a.fabricItem} | size=${a.size} | dia=${a.dia} | dozenWeight=${a.dozenWeight}`));

await mongoose.disconnect();
process.exit(0);
