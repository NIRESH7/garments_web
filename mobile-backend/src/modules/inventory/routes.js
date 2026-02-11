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

// Inward
router.route('/inward')
    .post(protect, createInward)
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
