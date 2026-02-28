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
} from './cuttingOrderController.js';
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
router.get('/cutting-orders/:id/allocation-report', protect, getAllocationReport);

router
    .route('/cutting-orders/:id')
    .get(protect, getCuttingOrderById)
    .delete(protect, deleteCuttingOrder);


export default router;


