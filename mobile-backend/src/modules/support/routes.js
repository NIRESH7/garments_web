import express from 'express';
import { createTicket, getMyTickets } from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';

const router = express.Router();

router.route('/').post(protect, createTicket).get(protect, getMyTickets);

export default router;
