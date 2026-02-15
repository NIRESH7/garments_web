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
    createStockLimit,
    getStockLimits,
} from './controller.js';
import { protect, admin } from '../../middleware/authMiddleware.js';

const router = express.Router();

router.use(protect);

// Categories & Dropdown Setup
router.route('/categories')
    .post(createCategory)
    .get(getCategories);

router.route('/categories/:id')
    .delete(deleteCategory);

router.route('/categories/:id/values')
    .post(addCategoryValue);

router.route('/categories/:id/values/:value')
    .delete(deleteCategoryValue);

// Party Master
router.route('/parties')
    .post(createParty)
    .get(getParties);

router.route('/parties/:id')
    .put(updateParty)
    .delete(deleteParty);

// Item Group Master
router.route('/item-groups')
    .post(createItemGroup)
    .get(getItemGroups);

router.route('/item-groups/:id')
    .put(updateItemGroup)
    .delete(deleteItemGroup);

// Lot Master
router.route('/lots')
    .post(createLot)
    .get(getLots);

// Stock Limits
router.route('/stock-limits')
    .post(createStockLimit)
    .get(getStockLimits);

export default router;
