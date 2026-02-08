import express from 'express';
import {
    createAssignment,
    getAssignments,
    deleteAssignment,
} from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';

const router = express.Router();

router
    .route('/assignments')
    .post(protect, createAssignment)
    .get(protect, getAssignments);

router.route('/assignments/:id').delete(protect, deleteAssignment);

export default router;
