import express from 'express';
const router = express.Router();
import {
    createInward,
    getInwards,
    getLotsFifo,
    getBalancedSets,
    generateInwardNumber,
    generateDcNumber,
    createOutward,
    getOutwards,
    getLotAgingReport,
} from './controller.js';
import {
    getOverviewReport,
    getInwardOutwardReport,
    getMonthlySummaryReport,
} from './reportController.js';
import { protect } from '../../middleware/authMiddleware.js';
import upload from '../../middleware/uploadMiddleware.js';

// Inward
router.route('/inward')
    .post(protect, upload.fields([
        { name: 'lotInchargeSignature', maxCount: 1 },
        { name: 'authorizedSignature', maxCount: 1 },
        { name: 'mdSignature', maxCount: 1 },
        // Add other image fields if necessary, e.g. qualityImage, etc.
        // For now focusing on signatures as requested.
        // If other images like qualityImage are sent as files too, add them here.
        // Based on analysis, other images seem to be base64 strings or not strictly defined as files yet in this flow.
        // However, `MobileApiService` in `saveInward` was just JSON. 
        // If we switch to Multipart, ALL files must be handled here.
        // BUT, looking at `controller.js`, `qualityImage` etc are just strings in body. 
        // If frontend sends them as files now, we need to handle them.
        // User request specifically mentioned "E-signature to be saved permanently".
        // I will stick to signatures for now to avoid breaking other image logic if they are base64.
        // But wait, if request is multipart, text fields come in req.body, files in req.files.
        // If existing images are base64 strings in text fields, they will still work.
    ]), createInward)
    .get(protect, getInwards);

router.get('/inward/fifo', protect, getLotsFifo);
router.get('/inward/balanced-sets', protect, getBalancedSets);
router.get('/inward/generate-no', protect, generateInwardNumber);

// Outward
router.route('/outward')
    .post(protect, createOutward)
    .get(protect, getOutwards);

router.get('/outward/generate-dc', protect, generateDcNumber);

// Reports
router.get('/reports/aging', protect, getLotAgingReport);
router.get('/reports/overview', protect, getOverviewReport);
router.get('/reports/inward-outward', protect, getInwardOutwardReport);
router.get('/reports/monthly', protect, getMonthlySummaryReport);

export default router;
