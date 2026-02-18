import express from 'express';
import {
    createAssignment,
    getAssignments,
    deleteAssignment,
} from './controller.js';
import {
    createCuttingOrder,
    getCuttingOrders,
    getCuttingOrderById,
    deleteCuttingOrder,
} from './cuttingOrderController.js';
import { protect } from '../../middleware/authMiddleware.js';

const router = express.Router();

router
    .route('/assignments')
    .post(protect, createAssignment)
    .get(protect, getAssignments);

router.route('/assignments/:id').delete(protect, deleteAssignment);

router
    .route('/cutting-orders')
    .post(protect, createCuttingOrder)
    .get(protect, getCuttingOrders);

router
    .route('/cutting-orders/:id')
    .get(protect, getCuttingOrderById)
    .delete(protect, deleteCuttingOrder);

export default router;


