import asyncHandler from 'express-async-handler';
import Category from './categoryModel.js';
import Party from './partyModel.js';
import ItemGroup from './itemGroupModel.js';
import Lot from './lotModel.js';

// --- CATEGORY & DROPDOWN HANDLERS ---

// @desc    Create a new category
// @route   POST /api/master/categories
// @access  Private/Admin
const createCategory = asyncHandler(async (req, res) => {
    const { name } = req.body;

    const categoryExists = await Category.findOne({ name });

    if (categoryExists) {
        res.status(400);
        throw new Error('Category already exists');
    }

    const category = await Category.create({ name, values: [] });
    res.status(201).json(category);
});

// @desc    Get all categories
// @route   GET /api/master/categories
// @access  Private
const getCategories = asyncHandler(async (req, res) => {
    const categories = await Category.find({});
    res.json(categories);
});

// @desc    Delete a category
// @route   DELETE /api/master/categories/:id
// @access  Private/Admin
const deleteCategory = asyncHandler(async (req, res) => {
    const category = await Category.findById(req.params.id);

    if (category) {
        await Category.deleteOne({ _id: category._id });
        res.json({ message: 'Category removed' });
    } else {
        res.status(404);
        throw new Error('Category not found');
    }
});

// @desc    Add value to category (Dropdown Setup)
// @route   POST /api/master/categories/:id/values
// @access  Private/Admin
const addCategoryValue = asyncHandler(async (req, res) => {
    const { value } = req.body;
    const category = await Category.findById(req.params.id);

    if (category) {
        if (category.values.includes(value)) {
            res.status(400);
            throw new Error('Value already exists in this category');
        }
        category.values.push(value);
        await category.save();
        res.status(201).json(category);
    } else {
        res.status(404);
        throw new Error('Category not found');
    }
});

const deleteCategoryValue = asyncHandler(async (req, res) => {
    const { value } = req.params;
    const category = await Category.findById(req.params.id);

    if (category) {
        category.values = category.values.filter(v => v !== value);
        await category.save();
        res.json(category);
    } else {
        res.status(404);
        throw new Error('Category not found');
    }
});

// --- PARTY HANDLERS ---

// @desc    Save a new party (Party Master)
// @route   POST /api/master/parties
// @access  Private
const createParty = asyncHandler(async (req, res) => {
    const { name, address, mobileNumber, process, gstIn, rate } = req.body;

    // Case-insensitive check
    const partyExists = await Party.findOne({
        name: { $regex: new RegExp(`^${name.trim()}$`, 'i') }
    });

    if (partyExists) {
        res.status(400);
        throw new Error('Party Name already exists');
    }

    const party = await Party.create({
        name: name.trim(),
        address,
        mobileNumber,
        process,
        gstIn,
        rate,
    });

    res.status(201).json(party);
});

// @desc    Get all parties
// @route   GET /api/master/parties
// @access  Private
const getParties = asyncHandler(async (req, res) => {
    const parties = await Party.find({});
    res.json(parties);
});

// --- ITEM GROUP HANDLERS ---

// @desc    Save a new item group (Item Group Master)
// @route   POST /api/master/item-groups
// @access  Private
const createItemGroup = asyncHandler(async (req, res) => {
    const { groupName, itemNames, gsm, colours, rate } = req.body;

    // Case-insensitive check
    const groupExists = await ItemGroup.findOne({
        groupName: { $regex: new RegExp(`^${groupName.trim()}$`, 'i') }
    });

    if (groupExists) {
        res.status(400);
        throw new Error('Item Group Name already exists');
    }

    const itemGroup = await ItemGroup.create({
        groupName: groupName.trim(),
        itemNames,
        gsm,
        colours,
        rate,
    });

    res.status(201).json(itemGroup);
});

// @desc    Get all item groups
// @route   GET /api/master/item-groups
// @access  Private
const getItemGroups = asyncHandler(async (req, res) => {
    const itemGroups = await ItemGroup.find({});
    res.json(itemGroups);
});

// --- LOT HANDLERS ---
const createLot = asyncHandler(async (req, res) => {
    const { lotNumber, partyName, process, remarks } = req.body;
    const lotExists = await Lot.findOne({ lotNumber });
    if (lotExists) {
        res.status(400);
        throw new Error('Lot Number already exists');
    }
    const lot = await Lot.create({ lotNumber, partyName, process, remarks });
    res.status(201).json(lot);
});

const getLots = asyncHandler(async (req, res) => {
    const lots = await Lot.find({});
    res.json(lots);
});

export {
    createCategory,
    getCategories,
    deleteCategory,
    addCategoryValue,
    createParty,
    getParties,
    createItemGroup,
    getItemGroups,
    deleteCategoryValue,
    createLot,
    getLots,
};
