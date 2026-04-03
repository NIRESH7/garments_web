import asyncHandler from 'express-async-handler';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { S3Client } from '@aws-sdk/client-s3';
import multerS3 from 'multer-s3';
import dotenv from 'dotenv';
import CuttingMaster from './cuttingMasterModel.js';

dotenv.config();

// ─── Local/S3 storage (mirrors uploadMiddleware but allows all file types) ───
const isS3Configured =
    process.env.AWS_ACCESS_KEY_ID &&
    process.env.AWS_ACCESS_KEY_ID !== 'local_key' &&
    process.env.AWS_SECRET_ACCESS_KEY &&
    process.env.AWS_SECRET_ACCESS_KEY !== 'local_secret' &&
    process.env.AWS_BUCKET_NAME;

const s3 = isS3Configured
    ? new S3Client({
          region: process.env.AWS_REGION || 'us-east-1',
          credentials: {
              accessKeyId: process.env.AWS_ACCESS_KEY_ID,
              secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
          },
      })
    : null;

const storage = isS3Configured
    ? multerS3({
          s3,
          bucket: process.env.AWS_BUCKET_NAME,
          metadata: (req, file, cb) => cb(null, { fieldName: file.fieldname }),
          key: (req, file, cb) =>
              cb(null, `uploads/${Date.now()}-${file.originalname}`),
      })
    : multer.diskStorage({
          destination(req, file, cb) {
              const dir = 'uploads/';
              if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
              cb(null, dir);
          },
          filename(req, file, cb) {
              cb(null, `${file.fieldname}-${Date.now()}${path.extname(file.originalname)}`);
          },
      });

// Allow images, audio, documents, CAD files
const cuttingMasterUpload = multer({
    storage,
    fileFilter: (req, file, cb) => cb(null, true), // accept all types
});

// Multer fields definition
const uploadFields = cuttingMasterUpload.fields([
    { name: 'itemImage', maxCount: 1 },
    { name: 'cadFile', maxCount: 1 },
    { name: 'instructionAudio', maxCount: 1 },
    { name: 'instructionDoc', maxCount: 1 },
    // patternImage_0, patternImage_1, … up to 20 rows
    ...Array.from({ length: 20 }, (_, i) => ({
        name: `patternImage_${i}`,
        maxCount: 1,
    })),
]);

/** Helper: resolve uploaded file path (local path or S3 key/url) */
const resolveFilePath = (fileObj) => {
    if (!fileObj) return '';
    if (isS3Configured && fileObj.key) return fileObj.key;
    return fileObj.path || '';
};

// ────────────────────────────────────────────────────────────────────────────
// @desc    Create a Cutting Master entry
// @route   POST /api/production/cutting-master
// @access  Private
// ────────────────────────────────────────────────────────────────────────────
const createCuttingMaster = [
    uploadFields,
    asyncHandler(async (req, res) => {
        const {
            itemName,
            size,
            dozenWeight,
            layPcs,
            lotName,
            diaName,
            knittingDia,
            cuttingDia,
            efficiency,
            wastePercentage,
            folding,
            layLengthMeter,
            patternDetails,
            instructionText,
            timeToComplete,
            meterPerDozen,
        } = req.body;

        // Parse patternDetails JSON string
        let parsedPatterns = [];
        try {
            parsedPatterns = patternDetails ? JSON.parse(patternDetails) : [];
        } catch (_) {
            parsedPatterns = [];
        }

        // Attach pattern images
        parsedPatterns = parsedPatterns.map((row, i) => {
            const imgFile = req.files?.[`patternImage_${i}`]?.[0];
            return {
                ...row,
                patternImage: imgFile ? resolveFilePath(imgFile) : (row.patternImage || ''),
            };
        });

        const eff = parseFloat(efficiency) || 0;
        const waste = parseFloat(wastePercentage) || parseFloat((100 - eff).toFixed(2));
        const effPct = parseFloat((100 - waste).toFixed(2));

        const entry = await CuttingMaster.create({
            user: req.user._id,
            itemName,
            size,
            itemImage: resolveFilePath(req.files?.itemImage?.[0]),
            dozenWeight: parseFloat(dozenWeight) || 0,
            efficiencyPct: effPct,
            layPcs: parseInt(layPcs) || 0,
            lotName: lotName || '',
            diaName: diaName || '',
            knittingDia: knittingDia || '',
            cuttingDia: cuttingDia || '',
            efficiency: eff,
            wastePercentage: waste,
            folding: parseFloat(folding) || 0,
            layLengthMeter: parseFloat(layLengthMeter) || 0,
            patternDetails: parsedPatterns,
            cadFile: resolveFilePath(req.files?.cadFile?.[0]),
            instructionAudio: resolveFilePath(req.files?.instructionAudio?.[0]),
            instructionText: instructionText || '',
            timeToComplete: timeToComplete || '',
            meterPerDozen: parseFloat(meterPerDozen) || 0,
            instructionDoc: resolveFilePath(req.files?.instructionDoc?.[0]),
        });

        res.status(201).json(entry);
    }),
];

// ────────────────────────────────────────────────────────────────────────────
// @desc    Get all Cutting Master entries
// @route   GET /api/production/cutting-master
// @access  Private
// ────────────────────────────────────────────────────────────────────────────
const getCuttingMasters = asyncHandler(async (req, res) => {
    const entries = await CuttingMaster.find({ user: req.user._id }).sort({
        createdAt: -1,
    });
    res.json(entries);
});

// ────────────────────────────────────────────────────────────────────────────
// @desc    Get a single Cutting Master entry
// @route   GET /api/production/cutting-master/:id
// @access  Private
// ────────────────────────────────────────────────────────────────────────────
const getCuttingMasterById = asyncHandler(async (req, res) => {
    const entry = await CuttingMaster.findById(req.params.id);
    if (!entry) {
        res.status(404);
        throw new Error('Cutting master entry not found');
    }
    if (entry.user.toString() !== req.user._id.toString()) {
        res.status(401);
        throw new Error('Not authorized');
    }
    res.json(entry);
});

// ────────────────────────────────────────────────────────────────────────────
// @desc    Update a Cutting Master entry
// @route   PUT /api/production/cutting-master/:id
// @access  Private
// ────────────────────────────────────────────────────────────────────────────
const updateCuttingMaster = [
    uploadFields,
    asyncHandler(async (req, res) => {
        const entry = await CuttingMaster.findById(req.params.id);
        if (!entry) {
            res.status(404);
            throw new Error('Cutting master entry not found');
        }
        if (entry.user.toString() !== req.user._id.toString()) {
            res.status(401);
            throw new Error('Not authorized');
        }

        const {
            itemName,
            size,
            dozenWeight,
            layPcs,
            lotName,
            diaName,
            knittingDia,
            cuttingDia,
            efficiency,
            wastePercentage,
            folding,
            layLengthMeter,
            patternDetails,
            instructionText,
            timeToComplete,
            meterPerDozen,
        } = req.body;

        let parsedPatterns = [];
        try {
            parsedPatterns = patternDetails ? JSON.parse(patternDetails) : entry.patternDetails;
        } catch (_) {
            parsedPatterns = entry.patternDetails;
        }

        parsedPatterns = parsedPatterns.map((row, i) => {
            const imgFile = req.files?.[`patternImage_${i}`]?.[0];
            return {
                ...row,
                patternImage: imgFile
                    ? resolveFilePath(imgFile)
                    : (row.patternImage || ''),
            };
        });

        const eff = parseFloat(efficiency) ?? entry.efficiency;
        const waste =
            parseFloat(wastePercentage) ??
            parseFloat((100 - eff).toFixed(2));
        const effPct = parseFloat((100 - waste).toFixed(2));

        entry.itemName = itemName ?? entry.itemName;
        entry.size = size ?? entry.size;
        entry.itemImage = req.files?.itemImage?.[0]
            ? resolveFilePath(req.files.itemImage[0])
            : entry.itemImage;
        entry.dozenWeight = parseFloat(dozenWeight) ?? entry.dozenWeight;
        entry.efficiencyPct = effPct;
        entry.layPcs = parseInt(layPcs) ?? entry.layPcs;
        entry.lotName = lotName ?? entry.lotName;
        entry.diaName = diaName ?? entry.diaName;
        entry.knittingDia = knittingDia ?? entry.knittingDia;
        entry.cuttingDia = cuttingDia ?? entry.cuttingDia;
        entry.efficiency = eff;
        entry.wastePercentage = waste;
        entry.folding = parseFloat(folding) ?? entry.folding;
        entry.layLengthMeter = parseFloat(layLengthMeter) ?? entry.layLengthMeter;
        entry.patternDetails = parsedPatterns;
        entry.cadFile = req.files?.cadFile?.[0]
            ? resolveFilePath(req.files.cadFile[0])
            : entry.cadFile;
        entry.instructionAudio = req.files?.instructionAudio?.[0]
            ? resolveFilePath(req.files.instructionAudio[0])
            : entry.instructionAudio;
        entry.instructionText = instructionText ?? entry.instructionText;
        entry.timeToComplete = timeToComplete ?? entry.timeToComplete;
        entry.meterPerDozen = parseFloat(meterPerDozen) ?? entry.meterPerDozen;
        entry.instructionDoc = req.files?.instructionDoc?.[0]
            ? resolveFilePath(req.files.instructionDoc[0])
            : entry.instructionDoc;

        const updated = await entry.save();
        res.json(updated);
    }),
];

// ────────────────────────────────────────────────────────────────────────────
// @desc    Delete a Cutting Master entry
// @route   DELETE /api/production/cutting-master/:id
// @access  Private
// ────────────────────────────────────────────────────────────────────────────
const deleteCuttingMaster = asyncHandler(async (req, res) => {
    const entry = await CuttingMaster.findById(req.params.id);
    if (!entry) {
        res.status(404);
        throw new Error('Cutting master entry not found');
    }
    if (entry.user.toString() !== req.user._id.toString()) {
        res.status(401);
        throw new Error('Not authorized');
    }
    await CuttingMaster.deleteOne({ _id: entry._id });
    res.json({ message: 'Cutting master entry removed' });
});

export {
    createCuttingMaster,
    getCuttingMasters,
    getCuttingMasterById,
    updateCuttingMaster,
    deleteCuttingMaster,
};
