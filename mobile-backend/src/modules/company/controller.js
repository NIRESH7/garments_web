import asyncHandler from 'express-async-handler';
import Company from './model.js';
import { getFilePath } from '../../utils/fileUtils.js';

// @desc    Get company info
// @route   GET /api/company
// @access  Public
const getCompany = asyncHandler(async (req, res) => {
    let company = await Company.findOne({});
    if (!company) {
        // Create a default one if none exists
        company = await Company.create({ name: 'My Company' });
    }
    res.json(company);
});

// @desc    Update company info
// @route   POST /api/company
// @access  Private/Admin
const updateCompany = asyncHandler(async (req, res) => {
    const { name, address, mobileNumber, email, headerText } = req.body;

    let company = await Company.findOne({});

    let logo = req.body.logo;
    if (req.file) {
        logo = getFilePath(req.file);
    }

    if (company) {
        company.name = name || company.name;
        company.address = address || company.address;
        company.mobileNumber = mobileNumber || company.mobileNumber;
        company.email = email || company.email;
        company.headerText = headerText || company.headerText;
        if (logo) company.logo = logo;

        const updatedCompany = await company.save();
        res.json(updatedCompany);
    } else {
        const newCompany = await Company.create({
            name: name || 'My Company',
            address,
            mobileNumber,
            email,
            headerText,
            logo
        });
        res.status(201).json(newCompany);
    }
});

export { getCompany, updateCompany };
