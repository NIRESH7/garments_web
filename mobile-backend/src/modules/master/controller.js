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
    const { name, photo, gsm } = req.body;

    // Use lean() to get a plain JavaScript object, avoiding Mongoose document validation issues on load
    const category = await Category.findById(req.params.id).lean();

    if (category) {
        let values = category.values || [];

        // Migration: Robustly Convert ALL values to objects
        values = values.map(v => {
            if (typeof v === 'string') {
                return { name: v, photo: null, gsm: null };
            }
            // Handle edge case where v might be an object but missing 'name' or be something else
            if (v && typeof v === 'object' && !v.name) {
                // Try to fallback to string representation if it has meaningful data, else ignore
                return { name: String(v), photo: null, gsm: null };
            }
            return v;
        }).filter(v => v && v.name); // Filter out any nulls or invalid objects

        // Case-insensitive check on the cleaned array
        const exists = values.some(v => v.name.toLowerCase() === name.toLowerCase());

        if (exists) {
            res.status(400);
            throw new Error('Value already exists in this category');
        }

        values.push({ name, photo, gsm });

        // Update the document directly with the sanitized array
        const updatedCategory = await Category.findByIdAndUpdate(
            req.params.id,
            { values: values },
            { new: true, runValidators: true }
        );

        res.status(201).json(updatedCategory);
    } else {
        res.status(404);
        throw new Error('Category not found');
    }
});

const deleteCategoryValue = asyncHandler(async (req, res) => {
    const { value } = req.params; // 'value' passed as path param is the 'name'
    const category = await Category.findById(req.params.id);

    if (category) {
        category.values = category.values.filter(v => v.name !== value);
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

// @desc    Update a party
// @route   PUT /api/master/parties/:id
// @access  Private
const updateParty = asyncHandler(async (req, res) => {
    const { name, address, mobileNumber, process, gstIn, rate } = req.body;
    const party = await Party.findById(req.params.id);

    if (party) {
        party.name = name || party.name;
        party.address = address || party.address;
        party.mobileNumber = mobileNumber || party.mobileNumber;
        party.process = process || party.process;
        party.gstIn = gstIn || party.gstIn;
        party.rate = rate !== undefined ? rate : party.rate;

        const updatedParty = await party.save();
        res.json(updatedParty);
    } else {
        res.status(404);
        throw new Error('Party not found');
    }
});

// @desc    Update an item group
// @route   PUT /api/master/item-groups/:id
// @access  Private
const updateItemGroup = asyncHandler(async (req, res) => {
    const { groupName, itemNames, gsm, colours, rate } = req.body;
    const itemGroup = await ItemGroup.findById(req.params.id);

    if (itemGroup) {
        itemGroup.groupName = groupName || itemGroup.groupName;
        itemGroup.itemNames = itemNames || itemGroup.itemNames;
        itemGroup.gsm = gsm || itemGroup.gsm;
        itemGroup.colours = colours || itemGroup.colours;
        itemGroup.rate = rate !== undefined ? rate : itemGroup.rate;

        const updatedItemGroup = await itemGroup.save();
        res.json(updatedItemGroup);
    } else {
        res.status(404);
        throw new Error('Item Group not found');
    }
});

// @desc    Delete a party
// @route   DELETE /api/master/parties/:id
// @access  Private
const deleteParty = asyncHandler(async (req, res) => {
    const party = await Party.findById(req.params.id);
    if (party) {
        await Party.deleteOne({ _id: party._id });
        res.json({ message: 'Party removed' });
    } else {
        res.status(404);
        throw new Error('Party not found');
    }
});

// @desc    Delete an item group
// @route   DELETE /api/master/item-groups/:id
// @access  Private
const deleteItemGroup = asyncHandler(async (req, res) => {
    const itemGroup = await ItemGroup.findById(req.params.id);
    if (itemGroup) {
        await ItemGroup.deleteOne({ _id: itemGroup._id });
        res.json({ message: 'Item Group removed' });
    } else {
        res.status(404);
        throw new Error('Item Group not found');
    }
});

export {
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
};
