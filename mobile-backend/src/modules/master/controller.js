import asyncHandler from 'express-async-handler';
import Category from './categoryModel.js';
import Party from './partyModel.js';
import ItemGroup from './itemGroupModel.js';
import Lot from './lotModel.js';
import StockLimit from './stockLimitModel.js';

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
    const { name, photo, gsm, knittingDia, cuttingDia, sizeType } = req.body;

    const category = await Category.findById(req.params.id).lean();

    if (category) {
        let values = category.values || [];

        // Migration: Robustly Convert ALL values to objects
        values = values.map(v => {
            if (typeof v === 'string') {
                return { name: v, photo: null, gsm: null, knittingDia: null, cuttingDia: null };
            }
            if (v && typeof v === 'object' && !v.name) {
                return { name: String(v), photo: null, gsm: null, knittingDia: null, cuttingDia: null };
            }
            return v;
        }).filter(v => v && v.name);

        const exists = values.some(v => v.name.toLowerCase() === name.toLowerCase());

        if (exists) {
            res.status(400);
            throw new Error('Value already exists in this category');
        }

        values.push({ name, photo, gsm, knittingDia: knittingDia || null, cuttingDia: cuttingDia || null, sizeType });

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

const updateCategoryValue = asyncHandler(async (req, res) => {
    const { id, value: oldValueName } = req.params;
    const { name: newName, photo, gsm, knittingDia, cuttingDia, sizeType } = req.body;

    const category = await Category.findById(id);

    if (category) {
        // Use loose matching or trim for the name since it comes from the URL
        const valueIndex = category.values.findIndex(v => v.name.trim() === decodeURIComponent(oldValueName).trim());

        if (valueIndex === -1) {
            res.status(404);
            throw new Error(`Registry entry "${oldValueName}" not found in this category`);
        }

        // Update fields
        category.values[valueIndex].name = newName || category.values[valueIndex].name;
        category.values[valueIndex].photo = photo !== undefined ? photo : category.values[valueIndex].photo;
        category.values[valueIndex].gsm = gsm !== undefined ? gsm : category.values[valueIndex].gsm;
        category.values[valueIndex].knittingDia = knittingDia !== undefined ? knittingDia : category.values[valueIndex].knittingDia;
        category.values[valueIndex].cuttingDia = cuttingDia !== undefined ? cuttingDia : category.values[valueIndex].cuttingDia;
        category.values[valueIndex].sizeType = sizeType !== undefined ? sizeType : category.values[valueIndex].sizeType;

        await category.save();
        res.json(category);
    } else {
        res.status(404);
        throw new Error('Category not found');
    }
});

const deleteCategoryValue = asyncHandler(async (req, res) => {
    const { id, value } = req.params;
    const category = await Category.findById(id);

    if (category) {
        category.values = category.values.filter(v => v.name.trim() !== decodeURIComponent(value).trim());
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

// @desc    Get item group by group name (for lot auto-fill)
// @route   GET /api/master/item-groups/by-name?name=...
// @access  Private
const getItemGroupByGroupName = asyncHandler(async (req, res) => {
    const { name } = req.query;
    if (!name) {
        res.status(400);
        throw new Error('name query param is required');
    }
    const group = await ItemGroup.findOne({
        $or: [
            { groupName: { $regex: new RegExp(`^${name.trim()}$`, 'i') } },
            { itemNames: { $regex: new RegExp(`^${name.trim()}$`, 'i') } }
        ]
    });
    if (group) {
        res.json(group);
    } else {
        res.status(404).json(null);
    }
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

// --- STOCK LIMIT HANDLERS ---
const createStockLimit = asyncHandler(async (req, res) => {
    const { lotName, dia, minWeight, maxWeight, minRolls, maxRolls, manualAdjustment } = req.body;

    const limit = await StockLimit.findOneAndUpdate(
        { lotName, dia },
        { minWeight, maxWeight, minRolls, maxRolls, manualAdjustment },
        { new: true, upsert: true }
    );

    res.status(201).json(limit);
});

const getStockLimits = asyncHandler(async (req, res) => {
    const limits = await StockLimit.find({});
    res.json(limits);
});

// @desc    Update a stock limit
// @route   PUT /api/master/stock-limits/:id
// @access  Private
const updateStockLimit = asyncHandler(async (req, res) => {
    const { lotName, dia, minWeight, maxWeight, minRolls, maxRolls, manualAdjustment } = req.body;
    const limit = await StockLimit.findById(req.params.id);

    if (limit) {
        limit.lotName = lotName || limit.lotName;
        limit.dia = dia || limit.dia;
        limit.minWeight = minWeight !== undefined ? minWeight : limit.minWeight;
        limit.maxWeight = maxWeight !== undefined ? maxWeight : limit.maxWeight;
        limit.minRolls = minRolls !== undefined ? minRolls : limit.minRolls;
        limit.maxRolls = maxRolls !== undefined ? maxRolls : limit.maxRolls;
        limit.manualAdjustment = manualAdjustment !== undefined ? manualAdjustment : limit.manualAdjustment;

        const updatedLimit = await limit.save();
        res.json(updatedLimit);
    } else {
        res.status(404);
        throw new Error('Stock Limit not found');
    }
});

// @desc    Delete a stock limit
// @route   DELETE /api/master/stock-limits/:id
// @access  Private
const deleteStockLimit = asyncHandler(async (req, res) => {
    const limit = await StockLimit.findById(req.params.id);
    if (limit) {
        await StockLimit.deleteOne({ _id: limit._id });
        res.json({ message: 'Stock Limit removed' });
    } else {
        res.status(404);
        throw new Error('Stock Limit not found');
    }
});

export {
    createCategory,
    getCategories,
    deleteCategory,
    addCategoryValue,
    updateCategoryValue,
    createParty,
    getParties,
    updateParty,
    deleteParty,
    createItemGroup,
    getItemGroups,
    getItemGroupByGroupName,
    updateItemGroup,
    deleteItemGroup,
    deleteCategoryValue,
    createLot,
    getLots,
    createStockLimit,
    getStockLimits,
    updateStockLimit,
    deleteStockLimit,
};
