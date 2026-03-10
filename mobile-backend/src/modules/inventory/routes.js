import express from 'express';
import multer from 'multer';
import path from 'path';
const router = express.Router();
import {
    createInward,
    importInwardWorkbook,
    getInwards,
    deleteInward,
    updateInward,
    getLotsFifo,
    getBalancedSets,
    generateInwardNumber,
    generateDcNumber,
    createOutward,
    getOutwards,
    deleteOutward,
    updateOutward,
    getLotAgingReport,
    getInwardColours,
    getFifoRecommendation,
    updateInwardComplaint,
    getQualityAuditReport,
    getLotDetails,
    getDistinctLots,
    checkFifoViolation,
} from './controller.js';

import {
    getOverviewReport,
    getInwardOutwardReport,
    getMonthlySummaryReport,
    getClientFormatReport,
    getGodownStockReport,
    getShadeCardReport,
    getLotAgingSummaryReport,
    getRackPalletStockReport,
} from './reportController.js';

import { protect } from '../../middleware/authMiddleware.js';
import upload from '../../middleware/uploadMiddleware.js';

const inwardImportUpload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 25 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        const mime = (file.mimetype || '').toLowerCase();
        const isExcelMime = mime.includes('spreadsheetml') || mime === 'application/vnd.ms-excel';
        const isPdf = ext === '.pdf' || mime === 'application/pdf';
        if (ext === '.xlsx' || ext === '.xls' || isExcelMime || isPdf) {
            cb(null, true);
            return;
        }
        cb(new Error('Only Excel or PDF files are allowed'));
    },
});

router.route('/inward')
    .post(protect, upload.fields([
        { name: 'lotInchargeSignature', maxCount: 1 },
        { name: 'authorizedSignature', maxCount: 1 },
        { name: 'mdSignature', maxCount: 1 },
    ]), createInward)
    .get(protect, getInwards);

router.post('/inward/import', protect, inwardImportUpload.single('file'), importInwardWorkbook);

router.route('/inward/:id')
    .put(protect, upload.fields([
        { name: 'lotInchargeSignature', maxCount: 1 },
        { name: 'authorizedSignature', maxCount: 1 },
        { name: 'mdSignature', maxCount: 1 },
    ]), updateInward)
    .delete(protect, deleteInward);

router.get('/inward/fifo', protect, getLotsFifo);
router.get('/inward/balanced-sets', protect, getBalancedSets);
router.get('/inward/generate-no', protect, generateInwardNumber);
router.get('/inward/colours', protect, getInwardColours);
router.get('/inward/fifo-recommendation', protect, getFifoRecommendation);
router.put('/inward/:id/complaint-solution', protect, updateInwardComplaint);
router.get('/inward/lot-details', protect, getLotDetails);
router.get('/inward/distinct-lots', protect, getDistinctLots);

// Outward
router.route('/outward')
    .post(protect, upload.fields([
        { name: 'lotInchargeSignature', maxCount: 1 },
        { name: 'authorizedSignature', maxCount: 1 },
    ]), createOutward)
    .get(protect, getOutwards);

router.route('/outward/:id')
    .put(protect, upload.fields([
        { name: 'lotInchargeSignature', maxCount: 1 },
        { name: 'authorizedSignature', maxCount: 1 },
    ]), updateOutward)
    .delete(protect, deleteOutward);

router.get('/outward/generate-dc', protect, generateDcNumber);
router.get('/outward/check-fifo', protect, checkFifoViolation);

// Reports
router.get('/reports/client', getClientFormatReport);
router.get('/reports/godown-stock', getGodownStockReport);
router.get('/reports/aging', protect, getLotAgingReport);
router.get('/reports/quality-audit', protect, getQualityAuditReport);
router.get('/reports/overview', protect, getOverviewReport);
router.get('/reports/inward-outward', protect, getInwardOutwardReport);
router.get('/reports/monthly', protect, getMonthlySummaryReport);
router.get('/reports/shade-card', protect, getShadeCardReport);
router.get('/reports/aging-summary', protect, getLotAgingSummaryReport);
router.get('/reports/rack-pallet', protect, getRackPalletStockReport);

export default router;
