import express from 'express';
import {
    createAssignment,
    getAssignments,
    deleteAssignment,
    updateAssignment,
} from './controller.js';
import {
    createCuttingOrder,
    getCuttingOrders,
    getCuttingOrderById,
    deleteCuttingOrder,
    getFifoAllocation,
    saveLotAllocation,
    getAllocationReport,
    getPreviousPlanning,
    getCuttingPlanReport,
    updateCuttingOrder,
    deleteLotAllocation,
    updateLotAllocation,
    getAllAllocationsByDate,
} from './cuttingOrderController.js';
import {
    createCuttingMaster,
    getCuttingMasters,
    getCuttingMasterById,
    updateCuttingMaster,
    deleteCuttingMaster,
} from './cuttingMasterController.js';
import {
    createAccessoriesMaster,
    getAccessoriesMasters,
    getAccessoriesMasterById,
    updateAccessoriesMaster,
    deleteAccessoriesMaster,
} from './accessoriesMasterController.js';
import { protect } from '../../middleware/authMiddleware.js';

// ─── NEW MODULE IMPORTS ──────────────────────────────────────────────────────
import {
    createCuttingEntry,
    getCuttingEntries,
    getCuttingEntryById,
    updateCuttingEntry,
    deleteCuttingEntry,
    saveCuttingEntryPage2,
    getCuttingEntryPage2,
    getCutStockReport,
    getCuttingEntryReport,
} from './cuttingEntryController.js';

import {
    createStitchingDelivery,
    getStitchingDeliveries,
    getStitchingDeliveryById,
    updateStitchingDelivery,
    deleteStitchingDelivery,
    createCuttingDailyPlan,
    getCuttingDailyPlans,
    getCuttingDailyPlanById,
    updateCuttingDailyPlan,
    createStitchingGrn,
    getStitchingGrns,
    getStitchingGrnById,
    updateStitchingGrn,
    createIronPackingDc,
    getIronPackingDcs,
    getIronPackingDcById,
    updateIronPackingDc,
    createAccessoriesItemAssign,
    getAccessoriesItemAssigns,
    getAccessoriesItemAssignById,
    updateAccessoriesItemAssign,
    deleteAccessoriesItemAssign,
} from './newModulesController.js';
// ─────────────────────────────────────────────────────────────────────────────

const router = express.Router();

router
    .route('/assignments')
    .post(protect, createAssignment)
    .get(protect, getAssignments);

router
    .route('/assignments/:id')
    .delete(protect, deleteAssignment)
    .put(protect, updateAssignment);

router.get('/cutting-orders/fifo-allocation', protect, getFifoAllocation);
router.get('/cutting-orders/all-allocations-by-date', protect, getAllAllocationsByDate);
router.get('/cutting-orders/previous-entries', protect, getPreviousPlanning);
router.get('/cutting-orders/report', protect, getCuttingPlanReport);

router
    .route('/cutting-orders')
    .post(protect, createCuttingOrder)
    .get(protect, getCuttingOrders);

router.post('/cutting-orders/:id/allocate', protect, saveLotAllocation);
router.delete('/cutting-orders/:id/allocation/:allocationId', protect, deleteLotAllocation);
router.put('/cutting-orders/:id/allocation/:allocationId', protect, updateLotAllocation);
router.get('/cutting-orders/:id/allocation-report', protect, getAllocationReport);
router
    .route('/cutting-orders/:id')
    .get(protect, getCuttingOrderById)
    .put(protect, updateCuttingOrder)
    .delete(protect, deleteCuttingOrder);


// Cutting Master routes
router
    .route('/cutting-master')
    .post(protect, ...createCuttingMaster)
    .get(protect, getCuttingMasters);

router
    .route('/cutting-master/:id')
    .get(protect, getCuttingMasterById)
    .put(protect, ...updateCuttingMaster)
    .delete(protect, deleteCuttingMaster);

// Accessories Master routes
router
    .route('/accessories-master')
    .post(protect, createAccessoriesMaster)
    .get(protect, getAccessoriesMasters);

router
    .route('/accessories-master/:id')
    .get(protect, getAccessoriesMasterById)
    .put(protect, updateAccessoriesMaster)
    .delete(protect, deleteAccessoriesMaster);

// ─── NEW MODULE ROUTES ────────────────────────────────────────────────────────

// Report routes (must come before /:id pattern)
router.get('/cutting-entry/reports/cut-stock', protect, getCutStockReport);
router.get('/cutting-entry/reports/entry-report', protect, getCuttingEntryReport);

// Cutting Entry (Page 1)
router.route('/cutting-entry')
    .post(protect, createCuttingEntry)
    .get(protect, getCuttingEntries);
router.route('/cutting-entry/:id')
    .get(protect, getCuttingEntryById)
    .put(protect, updateCuttingEntry)
    .delete(protect, deleteCuttingEntry);

// Cutting Entry Page 2
router.route('/cutting-entry/:id/page2')
    .post(protect, saveCuttingEntryPage2)
    .get(protect, getCuttingEntryPage2);

// Stitching Delivery DC
router.route('/stitching-delivery')
    .post(protect, createStitchingDelivery)
    .get(protect, getStitchingDeliveries);
router.route('/stitching-delivery/:id')
    .get(protect, getStitchingDeliveryById)
    .put(protect, updateStitchingDelivery)
    .delete(protect, deleteStitchingDelivery);

// Cutting Daily Plan
router.route('/cutting-daily-plan')
    .post(protect, createCuttingDailyPlan)
    .get(protect, getCuttingDailyPlans);
router.route('/cutting-daily-plan/:id')
    .get(protect, getCuttingDailyPlanById)
    .put(protect, updateCuttingDailyPlan);

// Stitching GRN
router.route('/stitching-grn')
    .post(protect, createStitchingGrn)
    .get(protect, getStitchingGrns);
router.route('/stitching-grn/:id')
    .get(protect, getStitchingGrnById)
    .put(protect, updateStitchingGrn);

// Iron & Packing DC
router.route('/iron-packing-dc')
    .post(protect, createIronPackingDc)
    .get(protect, getIronPackingDcs);
router.route('/iron-packing-dc/:id')
    .get(protect, getIronPackingDcById)
    .put(protect, updateIronPackingDc);

// Accessories Item Assignment
router.route('/accessories-item-assign')
    .post(protect, createAccessoriesItemAssign)
    .get(protect, getAccessoriesItemAssigns);
router.route('/accessories-item-assign/:id')
    .get(protect, getAccessoriesItemAssignById)
    .put(protect, updateAccessoriesItemAssign)
    .delete(protect, deleteAccessoriesItemAssign);

export default router;
