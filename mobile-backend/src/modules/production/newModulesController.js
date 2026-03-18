import asyncHandler from 'express-async-handler';
import StitchingDelivery from './stitchingDeliveryModel.js';
import CuttingDailyPlan from './cuttingDailyPlanModel.js';
import StitchingGrn from './stitchingGrnModel.js';
import IronPackingDc from './ironPackingDcModel.js';
import AccessoriesItemAssign from './accessoriesItemAssignModel.js';

// ─── Helper to parse JSON fields from body ───────────────────────────────────
const parseJsonFields = (data, fields) => {
  for (const field of fields) {
    if (data[field] && typeof data[field] === 'string') {
      try {
        data[field] = JSON.parse(data[field]);
      } catch (_) {}
    }
  }
  return data;
};

// ═══════════════════════════════════════════════════════
// STITCHING DELIVERY
// ═══════════════════════════════════════════════════════
export const createStitchingDelivery = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, [
    'colourRows', 'cutDetails', 'partWiseDetail', 'accessories',
  ]);
  data.createdBy = req.user._id;
  const doc = new StitchingDelivery(data);
  const saved = await doc.save();
  res.status(201).json(saved);
});

export const getStitchingDeliveries = asyncHandler(async (req, res) => {
  const { startDate, endDate, itemName, size, cutNo } = req.query;
  const filter = {};
  if (cutNo) filter.cutNo = cutNo;
  if (itemName) filter.itemName = { $regex: itemName, $options: 'i' };
  if (size) filter.size = size;
  if (startDate || endDate) {
    filter.dcDate = {};
    if (startDate) filter.dcDate.$gte = new Date(startDate);
    if (endDate) filter.dcDate.$lte = new Date(endDate);
  }
  const docs = await StitchingDelivery.find(filter).sort({ dcDate: -1 }).lean();
  res.json(docs);
});

export const getStitchingDeliveryById = asyncHandler(async (req, res) => {
  const doc = await StitchingDelivery.findById(req.params.id).lean();
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

export const updateStitchingDelivery = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, [
    'colourRows', 'cutDetails', 'partWiseDetail', 'accessories',
  ]);
  const doc = await StitchingDelivery.findByIdAndUpdate(req.params.id, data, { new: true });
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

export const deleteStitchingDelivery = asyncHandler(async (req, res) => {
  await StitchingDelivery.findByIdAndDelete(req.params.id);
  res.json({ message: 'Deleted' });
});

// ═══════════════════════════════════════════════════════
// CUTTING DAILY PLAN
// ═══════════════════════════════════════════════════════
export const createCuttingDailyPlan = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, ['planRows']);
  data.createdBy = req.user._id;
  const doc = new CuttingDailyPlan(data);
  const saved = await doc.save();
  res.status(201).json(saved);
});

export const getCuttingDailyPlans = asyncHandler(async (req, res) => {
  const { date } = req.query;
  const filter = {};
  if (date) {
    const d = new Date(date);
    const next = new Date(d);
    next.setDate(next.getDate() + 1);
    filter.date = { $gte: d, $lt: next };
  }
  const docs = await CuttingDailyPlan.find(filter).sort({ date: -1 }).lean();
  res.json(docs);
});

export const getCuttingDailyPlanById = asyncHandler(async (req, res) => {
  const doc = await CuttingDailyPlan.findById(req.params.id).lean();
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

export const updateCuttingDailyPlan = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, ['planRows']);
  const doc = await CuttingDailyPlan.findByIdAndUpdate(req.params.id, data, { new: true });
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

// ═══════════════════════════════════════════════════════
// STITCHING GRN
// ═══════════════════════════════════════════════════════
export const createStitchingGrn = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, ['colourRows']);
  data.createdBy = req.user._id;
  const doc = new StitchingGrn(data);
  const saved = await doc.save();
  res.status(201).json(saved);
});

export const getStitchingGrns = asyncHandler(async (req, res) => {
  const { type, startDate, endDate } = req.query;
  const filter = {};
  if (type) filter.type = type;
  if (startDate || endDate) {
    filter.date = {};
    if (startDate) filter.date.$gte = new Date(startDate);
    if (endDate) filter.date.$lte = new Date(endDate);
  }
  const docs = await StitchingGrn.find(filter).sort({ date: -1 }).lean();
  res.json(docs);
});

export const getStitchingGrnById = asyncHandler(async (req, res) => {
  const doc = await StitchingGrn.findById(req.params.id).lean();
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

export const updateStitchingGrn = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, ['colourRows']);
  const doc = await StitchingGrn.findByIdAndUpdate(req.params.id, data, { new: true });
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

// ═══════════════════════════════════════════════════════
// IRON & PACKING DC
// ═══════════════════════════════════════════════════════
export const createIronPackingDc = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, ['colourRows', 'accessories']);
  data.createdBy = req.user._id;
  const doc = new IronPackingDc(data);
  const saved = await doc.save();
  res.status(201).json(saved);
});

export const getIronPackingDcs = asyncHandler(async (req, res) => {
  const { type, startDate, endDate } = req.query;
  const filter = {};
  if (type) filter.type = type;
  if (startDate || endDate) {
    filter.date = {};
    if (startDate) filter.date.$gte = new Date(startDate);
    if (endDate) filter.date.$lte = new Date(endDate);
  }
  const docs = await IronPackingDc.find(filter).sort({ date: -1 }).lean();
  res.json(docs);
});

export const getIronPackingDcById = asyncHandler(async (req, res) => {
  const doc = await IronPackingDc.findById(req.params.id).lean();
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

export const updateIronPackingDc = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, ['colourRows', 'accessories']);
  const doc = await IronPackingDc.findByIdAndUpdate(req.params.id, data, { new: true });
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

// ═══════════════════════════════════════════════════════
// ACCESSORIES ITEM ASSIGNMENT
// ═══════════════════════════════════════════════════════
export const createAccessoriesItemAssign = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, ['accessories']);
  data.createdBy = req.user._id;

  // Upsert by itemName
  const existing = await AccessoriesItemAssign.findOne({ itemName: data.itemName });
  let doc;
  if (existing) {
    doc = await AccessoriesItemAssign.findByIdAndUpdate(existing._id, data, { new: true });
  } else {
    doc = await AccessoriesItemAssign.create(data);
  }
  res.status(201).json(doc);
});

export const getAccessoriesItemAssigns = asyncHandler(async (req, res) => {
  const { itemName } = req.query;
  const filter = {};
  if (itemName) filter.itemName = { $regex: itemName, $options: 'i' };
  const docs = await AccessoriesItemAssign.find(filter).lean();
  res.json(docs);
});

export const getAccessoriesItemAssignById = asyncHandler(async (req, res) => {
  const doc = await AccessoriesItemAssign.findById(req.params.id).lean();
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

export const updateAccessoriesItemAssign = asyncHandler(async (req, res) => {
  const data = parseJsonFields(req.body, ['accessories']);
  const doc = await AccessoriesItemAssign.findByIdAndUpdate(req.params.id, data, { new: true });
  if (!doc) { res.status(404); throw new Error('Not found'); }
  res.json(doc);
});

export const deleteAccessoriesItemAssign = asyncHandler(async (req, res) => {
  await AccessoriesItemAssign.findByIdAndDelete(req.params.id);
  res.json({ message: 'Deleted' });
});
