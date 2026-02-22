import express from 'express';
import {
    createTask,
    getTasks,
    getTaskById,
    addTaskReply,
    updateTaskStatus,
} from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';

const router = express.Router();

router.route('/').get(protect, getTasks).post(protect, createTask);
router.route('/:id').get(protect, getTaskById);
router.route('/:id/reply').post(protect, addTaskReply);
router.route('/:id/status').put(protect, updateTaskStatus);

export default router;
