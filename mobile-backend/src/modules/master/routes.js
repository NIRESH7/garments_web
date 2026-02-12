import express from 'express';
import {
    createCategory,
    getCategories,
    deleteCategory,
    addCategoryValue,
    createParty,
    getParties,
    updateParty,
    deleteParty,
    createItemGroup,
    getItemGroups,
    updateItemGroup,
    deleteItemGroup,
    deleteCategoryValue,
    createLot,
    getLots,
} from './controller.js';
import { protect, admin } from '../../middleware/authMiddleware.js';

const router = express.Router();

// Categories & Dropdown Setup
router.route('/categories')
    .post(protect, createCategory)
    .get(protect, getCategories);

router.route('/categories/:id')
    .delete(protect, admin, deleteCategory);

router.route('/categories/:id/values')
    .post(protect, addCategoryValue);

router.route('/categories/:id/values/:value')
    .delete(protect, deleteCategoryValue);

// Party Master
router.route('/parties')
    .post(protect, createParty)
    .get(protect, getParties);

router.route('/parties/:id')
    .put(protect, updateParty)
    .delete(protect, deleteParty);

// Item Group Master
router.route('/item-groups')
    .post(protect, createItemGroup)
    .get(protect, getItemGroups);

router.route('/item-groups/:id')
    .put(protect, updateItemGroup)
    .delete(protect, deleteItemGroup);

// Lot Master
router.route('/lots')
    .post(protect, createLot)
    .get(protect, getLots);

export default router;
