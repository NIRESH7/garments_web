import CuttingEntry from './cuttingEntryModel.js';
import CuttingEntryPage2 from './cuttingEntryPage2Model.js';
import asyncHandler from 'express-async-handler';

// @desc Create a new cutting entry
// @route POST /api/production/cutting-entry
export const createCuttingEntry = asyncHandler(async (req, res) => {
  const data = req.body;
  if (data.colourRows && typeof data.colourRows === 'string') {
    data.colourRows = JSON.parse(data.colourRows);
  }
  if (data.dyedDcNos && typeof data.dyedDcNos === 'string') {
    data.dyedDcNos = JSON.parse(data.dyedDcNos);
  }
  data.createdBy = req.user._id;

  const entry = new CuttingEntry(data);
  const saved = await entry.save();
  res.status(201).json(saved);
});

// @desc Get all cutting entries
// @route GET /api/production/cutting-entry
export const getCuttingEntries = asyncHandler(async (req, res) => {
  const { startDate, endDate, itemName, size, lotNo, lotName, cutNo } = req.query;
  const filter = {};

  if (cutNo) filter.cutNo = { $regex: cutNo, $options: 'i' };
  if (itemName) filter.itemName = { $regex: itemName, $options: 'i' };
  if (size) filter.size = size;
  if (lotNo) filter.lotNo = lotNo;
  if (startDate || endDate) {
    filter.cuttingDate = {};
    if (startDate) filter.cuttingDate.$gte = new Date(startDate);
    if (endDate) filter.cuttingDate.$lte = new Date(endDate);
  }

  const entries = await CuttingEntry.find(filter)
    .sort({ cuttingDate: -1, createdAt: -1 })
    .lean();
  res.json(entries);
});

// @desc Get cutting entry by ID
// @route GET /api/production/cutting-entry/:id
export const getCuttingEntryById = asyncHandler(async (req, res) => {
  const entry = await CuttingEntry.findById(req.params.id).lean();
  if (!entry) {
    res.status(404);
    throw new Error('Cutting entry not found');
  }
  res.json(entry);
});

// @desc Update cutting entry
// @route PUT /api/production/cutting-entry/:id
export const updateCuttingEntry = asyncHandler(async (req, res) => {
  const data = req.body;
  if (data.colourRows && typeof data.colourRows === 'string') {
    data.colourRows = JSON.parse(data.colourRows);
  }
  if (data.dyedDcNos && typeof data.dyedDcNos === 'string') {
    data.dyedDcNos = JSON.parse(data.dyedDcNos);
  }

  const entry = await CuttingEntry.findByIdAndUpdate(req.params.id, data, {
    new: true,
  });
  if (!entry) {
    res.status(404);
    throw new Error('Cutting entry not found');
  }
  res.json(entry);
});

// @desc Delete cutting entry
// @route DELETE /api/production/cutting-entry/:id
export const deleteCuttingEntry = asyncHandler(async (req, res) => {
  const entry = await CuttingEntry.findByIdAndDelete(req.params.id);
  if (!entry) {
    res.status(404);
    throw new Error('Cutting entry not found');
  }
  await CuttingEntryPage2.findOneAndDelete({ cuttingEntryId: req.params.id });
  res.json({ message: 'Deleted successfully' });
});

// @desc Save/update Page 2 of cutting entry
// @route POST /api/production/cutting-entry/:id/page2
export const saveCuttingEntryPage2 = asyncHandler(async (req, res) => {
  const data = req.body;
  if (data.parts && typeof data.parts === 'string') data.parts = JSON.parse(data.parts);
  if (data.layBalance && typeof data.layBalance === 'string') data.layBalance = JSON.parse(data.layBalance);

  data.cuttingEntryId = req.params.id;
  data.createdBy = req.user._id;

  const existing = await CuttingEntryPage2.findOne({ cuttingEntryId: req.params.id });
  let page2;
  if (existing) {
    page2 = await CuttingEntryPage2.findByIdAndUpdate(existing._id, data, { new: true });
  } else {
    page2 = await CuttingEntryPage2.create(data);
  }

  // Mark entry weightDate when page 2 is saved and sync global metrics
  await CuttingEntry.findByIdAndUpdate(req.params.id, {
    weightDate: new Date(),
    status: 'Completed',
    cutterWasteWT: data.cutterWasteWT || 0,
    offPatternWaste: data.offPatternWaste || 0,
    totalWasteWT: data.totalWasteWT || 0,
    wastePercent: data.wastePercent || 0,
  });
  res.status(201).json(page2);
});

// @desc Get Page 2 of cutting entry
// @route GET /api/production/cutting-entry/:id/page2
export const getCuttingEntryPage2 = asyncHandler(async (req, res) => {
  console.log(`[DEBUG] GET Page 2 for entry ID: ${req.params.id}`);
  try {
    const page2 = await CuttingEntryPage2.findOne({
      cuttingEntryId: req.params.id,
    }).lean();
    console.log(`[DEBUG] Page 2 result found: ${!!page2}`);
    if (!page2) {
      return res.json({});
    }
    res.json(page2);
  } catch (error) {
    console.error(`[ERROR] GET Page 2 failed: ${error.message}`);
    throw error;
  }
});

// @desc Get Cut Stock Report (item vs size-wise dozen count)
// @route GET /api/production/cutting-entry/reports/cut-stock
export const getCutStockReport = asyncHandler(async (req, res) => {
  const { startDate, endDate, itemName, size, cutNo, lotNo, lotName } = req.query;
  const filter = {};
  if (itemName) filter.itemName = { $regex: itemName, $options: 'i' };
  if (size) filter.size = size;
  if (cutNo) filter.cutNo = { $regex: cutNo, $options: 'i' };
  if (lotNo) filter.lotNo = lotNo;
  if (lotName) filter.lotName = { $regex: lotName, $options: 'i' };
  if (startDate || endDate) {
    filter.cuttingDate = {};
    if (startDate) filter.cuttingDate.$gte = new Date(startDate);
    if (endDate) filter.cuttingDate.$lte = new Date(endDate);
  }

  const entries = await CuttingEntry.find(filter).lean();

  // Group by itemName, then size
  const report = {};
  const sizes = ['75', '80', '85', '90', '95', '100', '105', '110'];

  for (const entry of entries) {
    const item = entry.itemName;
    if (!report[item]) {
      report[item] = { itemName: item, total: 0 };
      sizes.forEach((s) => (report[item][s] = 0));
    }
    const totalDoz = (entry.colourRows || []).reduce(
      (sum, row) => sum + (row.doz || 0),
      0
    );
    const sz = entry.size;
    if (sizes.includes(sz)) {
      report[item][sz] = (report[item][sz] || 0) + totalDoz;
    }
    report[item].total += totalDoz;
  }

  res.json(Object.values(report));
});

// @desc Get Cutting Entry Report (detailed list)
// @route GET /api/production/cutting-entry/reports/entry-report
export const getCuttingEntryReport = asyncHandler(async (req, res) => {
  const { startDate, endDate, cutNo, lotName, lotNo, itemName, size, colour } =
    req.query;
  const filter = {};
  if (cutNo) filter.cutNo = { $in: cutNo.split(',').map((s) => s.trim()) };
  if (itemName) filter.itemName = { $regex: itemName, $options: 'i' };
  if (size) filter.size = size;
  if (lotNo) filter.lotNo = lotNo;
  if (lotName) filter.lotName = { $regex: lotName, $options: 'i' };
  if (startDate || endDate) {
    filter.cuttingDate = {};
    if (startDate) filter.cuttingDate.$gte = new Date(startDate);
    if (endDate) filter.cuttingDate.$lte = new Date(endDate);
  }

  const entries = await CuttingEntry.find(filter).lean();

  // Flatten to rows per colour
  const rows = [];
  for (const entry of entries) {
    for (const row of entry.colourRows || []) {
      if (colour && row.colour !== colour) continue;
      rows.push({
        cutNo: entry.cutNo,
        itemName: entry.itemName,
        size: entry.size,
        colour: row.colour,
        lotNo: entry.lotNo,
        lotName: entry.lotName,
        pcs: row.totalPcs,
        doz: row.doz,
        cuttingDate: entry.cuttingDate,
      });
    }
  }

  res.json(rows);
});
