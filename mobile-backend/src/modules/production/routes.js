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

export default router;


