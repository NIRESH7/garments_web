import asyncHandler from 'express-async-handler';
import Inward from './inwardModel.js';
import Outward from './outwardModel.js';
import Notification from '../notification/model.js';

// --- INWARD HANDLERS ---

// @desc    Create a new inward entry (Lot Inward Entry)
// @route   POST /api/inventory/inward
// @access  Private
const createInward = asyncHandler(async (req, res) => {
    try {
        const {
            inwardNo,
            inwardDate,
            inTime,
            outTime,
            lotName,
            lotNo,
            fromParty,
            process,
            rate,
            gsm,
            vehicleNo,
            partyDcNo,
            diaEntries,
            storageDetails,
            qualityStatus,
            qualityImage,
            gsmStatus,
            gsmImage,
            shadeStatus,
            shadeImage,
            washingStatus,
            washingImage,
            complaintText,
            complaintImage,
            balanceImage,
        } = req.body;

        // Handle file uploads for signatures
        let finalLotInchargeSignature = req.body.lotInchargeSignature;
        let finalAuthorizedSignature = req.body.authorizedSignature;
        let finalMdSignature = req.body.mdSignature;

        if (req.files) {
            if (req.files.lotInchargeSignature) {
                finalLotInchargeSignature = `/${req.files.lotInchargeSignature[0].path.replace(/\\/g, '/')}`;
            }
            if (req.files.authorizedSignature) {
                finalAuthorizedSignature = `/${req.files.authorizedSignature[0].path.replace(/\\/g, '/')}`;
            }
            if (req.files.mdSignature) {
                finalMdSignature = `/${req.files.mdSignature[0].path.replace(/\\/g, '/')}`;
            }
        }

        // --- Parse JSON strings for diaEntries and storageDetails ---
        let processedDiaEntries = diaEntries;
        if (typeof diaEntries === 'string') {
            try {
                processedDiaEntries = JSON.parse(diaEntries);
            } catch (e) {
                console.error('Failed to parse diaEntries JSON:', e);
            }
        }

        let processedStorageDetails = storageDetails;
        if (typeof storageDetails === 'string') {
            try {
                processedStorageDetails = JSON.parse(storageDetails);
            } catch (e) {
                console.error('Failed to parse storageDetails JSON:', e);
            }
        }

        // --- MERGE LOGIC: Check for existing lot ---
        const cleanLotNo = lotNo?.toString().trim();
        const cleanLotName = lotName?.toString().trim();

        // Escape regex special characters just in case
        const escapedLotNo = cleanLotNo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const escapedLotName = cleanLotName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

        console.log(`Checking merge for Lot No: [${cleanLotNo}], Lot Name: [${cleanLotName}]`);

        let inward = await Inward.findOne({
            lotNo: { $regex: new RegExp(`^\\s*${escapedLotNo}\\s*$`, 'i') },
            lotName: { $regex: new RegExp(`^\\s*${escapedLotName}\\s*$`, 'i') }
        });

        if (inward) {
            console.log(`SUCCESS: Found existing Inward: ${inward.inwardNo} (ID: ${inward._id})`);

            // 1. Merge diaEntries
            if (processedDiaEntries && Array.isArray(processedDiaEntries)) {
                console.log(`Merging ${processedDiaEntries.length} new DIA entries...`);
                processedDiaEntries.forEach(newEntry => {
                    const existingEntry = inward.diaEntries.find(e => e.dia?.toString().trim() === newEntry.dia?.toString().trim());
                    if (existingEntry) {
                        console.log(`  Updating existing DIA: ${newEntry.dia}`);
                        existingEntry.roll = (Number(existingEntry.roll) || 0) + (Number(newEntry.roll) || 0);
                        existingEntry.sets = (Number(existingEntry.sets) || 0) + (Number(newEntry.sets) || 0);
                        existingEntry.delivWt = Number(((Number(existingEntry.delivWt) || 0) + (Number(newEntry.delivWt) || 0)).toFixed(2));
                        existingEntry.recRoll = (Number(existingEntry.recRoll) || 0) + (Number(newEntry.recRoll) || 0);
                        existingEntry.recWt = Number(((Number(existingEntry.recWt) || 0) + (Number(newEntry.recWt) || 0)).toFixed(2));
                        existingEntry.rate = Number(newEntry.rate) || existingEntry.rate;
                    } else {
                        console.log(`  Adding new DIA: ${newEntry.dia}`);
                        inward.diaEntries.push(newEntry);
                    }
                });
            }

            // 2. Merge storageDetails
            let currentStorage = Array.isArray(inward.storageDetails) ? inward.storageDetails : [];

            if (processedStorageDetails && Array.isArray(processedStorageDetails)) {
                console.log(`Merging ${processedStorageDetails.length} storage detail blocks...`);
                processedStorageDetails.forEach(newStorage => {
                    const existingStorage = currentStorage.find(s => s.dia?.toString().trim() === newStorage.dia?.toString().trim());
                    if (existingStorage) {
                        console.log(`  Updating storage for DIA: ${newStorage.dia}`);
                        // Merge Racks & Pallets
                        const combinedRacks = [...(existingStorage.racks || []), ...(newStorage.racks || [])];
                        existingStorage.racks = combinedRacks;

                        const combinedPallets = [...(existingStorage.pallets || []), ...(newStorage.pallets || [])];
                        existingStorage.pallets = combinedPallets;

                        // Merge Rows (Colours)
                        if (!existingStorage.rows) existingStorage.rows = [];
                        newStorage.rows.forEach(newRow => {
                            const existingRow = existingStorage.rows.find(r => r.colour?.toString().trim().toLowerCase() === newRow.colour?.toString().trim().toLowerCase());
                            if (existingRow) {
                                console.log(`    Appending to existing colour: ${newRow.colour}`);
                                existingRow.setWeights = [...(existingRow.setWeights || []), ...(newRow.setWeights || [])];
                                existingRow.totalWeight = Number(((Number(existingRow.totalWeight) || 0) + (Number(newRow.totalWeight) || 0)).toFixed(2));
                            } else {
                                console.log(`    Adding new colour: ${newRow.colour}`);
                                existingStorage.rows.push(newRow);
                            }
                        });
                    } else {
                        console.log(`  Adding new storage DIA: ${newStorage.dia}`);
                        currentStorage.push(newStorage);
                    }
                });
            }
            inward.storageDetails = currentStorage;
            inward.markModified('storageDetails');
            inward.markModified('diaEntries');

            // 3. Update metadata fields with latest info
            console.log("Updating metadata fields...");
            if (process) inward.process = process;
            if (fromParty) inward.fromParty = fromParty;
            if (rate) inward.rate = Number(rate);
            if (gsm) inward.gsm = gsm;
            if (vehicleNo) inward.vehicleNo = vehicleNo;
            if (partyDcNo) inward.partyDcNo = partyDcNo;
            if (outTime) inward.outTime = outTime;

            // ... keep latest check statuses
            if (qualityStatus) inward.qualityStatus = qualityStatus;
            if (qualityImage) inward.qualityImage = qualityImage;
            if (gsmStatus) inward.gsmStatus = gsmStatus;
            if (gsmImage) inward.gsmImage = gsmImage;
            if (shadeStatus) inward.shadeStatus = shadeStatus;
            if (shadeImage) inward.shadeImage = shadeImage;
            if (washingStatus) inward.washingStatus = washingStatus;
            if (washingImage) inward.washingImage = washingImage;
            if (complaintText) inward.complaintText = complaintText;
            if (complaintImage) inward.complaintImage = complaintImage;
            if (balanceImage) inward.balanceImage = balanceImage;

            if (finalLotInchargeSignature) inward.lotInchargeSignature = finalLotInchargeSignature;
            if (finalAuthorizedSignature) inward.authorizedSignature = finalAuthorizedSignature;
            if (finalMdSignature) inward.mdSignature = finalMdSignature;

            await inward.save();
            console.log("Merge complete and saved.");

            // Create notification
            await Notification.create({
                user: req.user._id,
                title: 'Inward Updated',
                body: `Inward Lot ${cleanLotNo} (${cleanLotName}) updated with new entries.`,
                type: 'info'
            }).catch(err => console.error('Notification failed:', err));

            return res.status(201).json(inward); // Return 201 for Flutter app success
        }

        console.log("No existing Lot found. Creating new Inward record...");
        // --- CREATE LOGIC (If no existing lot) ---
        let finalInwardNo = inwardNo;
        if (!finalInwardNo) {
            const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
            const count = await Inward.countDocuments({
                createdAt: {
                    $gte: new Date(new Date().setHours(0, 0, 0, 0)),
                    $lt: new Date(new Date().setHours(23, 59, 59, 999))
                }
            });
            finalInwardNo = `INW-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
        }

        inward = await Inward.create({
            user: req.user._id,
            inwardNo: finalInwardNo,
            inwardDate,
            inTime,
            outTime,
            lotName,
            lotNo,
            fromParty,
            process,
            rate: Number(rate) || 0,
            gsm,
            vehicleNo,
            partyDcNo,
            diaEntries: processedDiaEntries,
            storageDetails: processedStorageDetails,
            qualityStatus,
            qualityImage,
            gsmStatus,
            gsmImage,
            shadeStatus,
            shadeImage,
            washingStatus,
            washingImage,
            complaintText,
            complaintImage,
            balanceImage,
            lotInchargeSignature: finalLotInchargeSignature,
            authorizedSignature: finalAuthorizedSignature,
            mdSignature: finalMdSignature,
        });

        // Create notification
        await Notification.create({
            user: req.user._id,
            title: 'New Inward Created',
            body: `New Inward processed for Lot ${lotNo} (${lotName}).`,
            type: 'success'
        }).catch(err => console.error('Notification failed:', err));

        res.status(201).json(inward);
    } catch (error) {
        console.error('Error in createInward:', error);
        res.status(500);
        throw new Error(`Failed to process inward entry: ${error.message}`);
    }
});

// @desc    Get all inward entries
// @route   GET /api/inventory/inward
// @access  Private
const getInwards = asyncHandler(async (req, res) => {
    const { startDate, endDate, fromParty, lotName, lotNo } = req.query;

    let query = {};
    if (startDate || endDate) {
        query.inwardDate = {};
        if (startDate) query.inwardDate.$gte = startDate;
        if (endDate) query.inwardDate.$lte = endDate;
    }
    if (fromParty) query.fromParty = { $regex: new RegExp(fromParty, 'i') };
    if (lotName) query.lotName = { $regex: new RegExp(lotName, 'i') };
    if (lotNo) query.lotNo = { $regex: new RegExp(lotNo, 'i') };

    const inwards = await Inward.find(query).sort({ inwardDate: -1 });
    res.json(inwards);
});

// @desc    Get Lots by DIA for FIFO
// @route   GET /api/inventory/inward/fifo
const getLotsFifo = asyncHandler(async (req, res) => {
    const { dia } = req.query;
    const inwards = await Inward.find({ 'diaEntries.dia': dia }).sort({ inwardDate: 1 });
    const lotNos = [...new Set(inwards.map(i => i.lotNo))];
    res.json(lotNos);
});

// @desc    Get Balanced Sets for Lot and DIA
// @route   GET /api/inventory/inward/balanced-sets
const getBalancedSets = asyncHandler(async (req, res) => {
    const { lotNo, dia } = req.query;
    const inwards = await Inward.find({ lotNo, 'diaEntries.dia': dia });

    // Aggregate all possible sets from storageDetails (Inwards)
    let allSets = [];
    inwards.forEach(inward => {
        if (inward.storageDetails && inward.storageDetails.length > 0) {
            inward.storageDetails.forEach(sd => {
                if (sd.dia === dia) {
                    sd.rows.forEach(row => {
                        row.setWeights.forEach((wt, idx) => {
                            allSets.push({
                                set_no: (idx + 1).toString(),
                                colour: row.colour,
                                weight: parseFloat(wt) || 0,
                                rack_name: sd.racks && sd.racks[idx] ? sd.racks[idx] : 'Not Assigned',
                                pallet_number: sd.pallets && sd.pallets[idx] ? sd.pallets[idx] : 'Not Assigned'
                            });
                        });
                    });
                }
            });
        }
    });

    // Find all set_no already used in Outwards for this Lot + Dia
    const outwards = await Outward.find({ lotNo, dia });
    const usedSetNumbers = new Set();
    outwards.forEach(outward => {
        if (outward.items) {
            outward.items.forEach(item => {
                if (item.set_no) {
                    usedSetNumbers.add(item.set_no.toString());
                }
            });
        }
    });

    // Filter out ANY set that has already been dispatched (even if partial color was used, though standard should be full set)
    // The requirement is: "Already used Set Numbers must NOT appear again"
    const balancedSets = allSets.filter(s => !usedSetNumbers.has(s.set_no.toString()));

    res.json(balancedSets);
});

// @desc    Get All Colours for a Lot (from Inward)
// @route   GET /api/inventory/inward/colours
const getInwardColours = asyncHandler(async (req, res) => {
    const { lotNo } = req.query;
    const inwards = await Inward.find({ lotNo });

    const colours = new Set();
    inwards.forEach(inward => {
        if (inward.storageDetails && inward.storageDetails.length > 0) {
            inward.storageDetails.forEach(sd => {
                sd.rows.forEach(row => {
                    if (row.colour) colours.add(row.colour);
                });
            });
        }
        // Fallback to diaEntries if storageDetails is empty
        if (inward.diaEntries && inward.diaEntries.length > 0) {
            // diaEntries usually don't have colour explicitly unless matched with something else.
            // But let's check if we missed anything. 
            // In current schema, colours are in storageDetails.
        }
    });

    res.json(Array.from(colours));
});

// @desc    Generate Inward Number (for UI display)
// @route   GET /api/inventory/inward/generate-no
// @access  Private
const generateInwardNumber = asyncHandler(async (req, res) => {
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const count = await Inward.countDocuments({
        createdAt: {
            $gte: new Date(new Date().setHours(0, 0, 0, 0)),
            $lt: new Date(new Date().setHours(23, 59, 59, 999)),
        },
    });
    const inwardNo = `INW-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
    res.json({ inwardNo });
});

// @desc    Get FIFO Recommendation for Lot Name and DIA
// @route   GET /api/inventory/inward/fifo-recommendation
const getFifoRecommendation = asyncHandler(async (req, res) => {
    const { lotName, dia } = req.query;

    if (!lotName || !dia) {
        res.status(400);
        throw new Error('Lot Name and DIA are required');
    }

    // 1. Find all inwards for this Lot Name and DIA, sorted by date (FIFO)
    const inwards = await Inward.find({
        lotName: { $regex: new RegExp(`^${lotName}$`, 'i') },
        'diaEntries.dia': dia
    }).sort({ inwardDate: 1, createdAt: 1 }); // Secondary sort by createdAt if dates are same

    const lotNos = [...new Set(inwards.map(i => i.lotNo))];

    for (const lotNo of lotNos) {
        console.log(`Checking FIFO for Lot No: ${lotNo}`);
        // 2. Check available stock for this specific lot + dia
        const lotInwards = await Inward.find({ lotNo, 'diaEntries.dia': dia });
        let totalInwardWt = 0;
        lotInwards.forEach(inw => {
            const entry = inw.diaEntries.find(e => e.dia === dia);
            if (entry) totalInwardWt += (entry.recWt || 0);
        });

        const lotOutwards = await Outward.find({ lotNo, dia });
        let totalOutwardWt = 0;
        lotOutwards.forEach(out => {
            out.items.forEach(item => {
                totalOutwardWt += (item.total_weight || 0);
            });
        });

        const balance = totalInwardWt - totalOutwardWt;
        console.log(`  Lot: ${lotNo}, Balance: ${balance}`);

        if (balance > 0.1) {
            // 3. Check if there are balanced sets (not yet dispatched)
            const usedSetNumbers = new Set();
            lotOutwards.forEach(out => {
                if (out.items) {
                    out.items.forEach(item => {
                        if (item.set_no) usedSetNumbers.add(item.set_no.toString());
                    });
                }
            });

            // Count total sets across all inwards for this lot
            let availableSet = null;
            let foundSet = false;

            for (const inw of lotInwards) {
                if (foundSet) break;
                if (inw.storageDetails && Array.isArray(inw.storageDetails)) {
                    for (const sd of inw.storageDetails) {
                        if (sd.dia === dia) {
                            // Assuming sets are listed in rows
                            for (const row of sd.rows) {
                                for (let i = 0; i < row.setWeights.length; i++) {
                                    const setNo = (i + 1).toString();
                                    if (!usedSetNumbers.has(setNo)) {
                                        availableSet = {
                                            lotNo,
                                            lotName: inw.lotName,
                                            rackName: sd.racks && sd.racks[i] ? sd.racks[i] : 'Not Assigned',
                                            palletNumber: sd.pallets && sd.pallets[i] ? sd.pallets[i] : 'Not Assigned',
                                            balanceWeight: balance
                                        };
                                        console.log(`  Found FIFO Lot: ${lotNo} with Set: ${setNo}`);
                                        foundSet = true;
                                        break;
                                    }
                                }
                                if (foundSet) break;
                            }
                        }
                        if (foundSet) break;
                    }
                } else {
                    // Fallback for lots without storage details but with balance
                    console.log(`  Lot ${lotNo} has balance but no storage details (sets)`);
                }
            }

            if (availableSet) {
                return res.json(availableSet);
            }
        }
    }

    console.log(`No FIFO recommendation found for ${lotName} / ${dia}`);
    res.json(null);
});

// --- OUTWARD HANDLERS ---

// @desc    Generate DC Number
// @route   GET /api/inventory/outward/generate-dc
const generateDcNumber = asyncHandler(async (req, res) => {
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const count = await Outward.countDocuments({
        createdAt: {
            $gte: new Date(new Date().setHours(0, 0, 0, 0)),
            $lt: new Date(new Date().setHours(23, 59, 59, 999))
        }
    });
    const dcNo = `DC-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
    res.json({ dc_number: dcNo });
});

// @desc    Create a new outward entry (Outward Screen)
// @route   POST /api/inventory/outward
// @access  Private
const createOutward = asyncHandler(async (req, res) => {
    let {
        lotName,
        dateTime,
        dia,
        lotNo,
        partyName,
        process,
        address,
        vehicleNo,
        inTime,
        outTime,
        items,
        dc_number,
    } = req.body;

    // Parse items if it's a JSON string (common with multipart/form-data)
    console.log('[DEBUG] createOutward raw items type:', typeof items);

    if (typeof items === 'string') {
        try {
            console.log('[DEBUG] items is string, parsing...');
            items = JSON.parse(items);
            req.body.items = items;
            console.log('[DEBUG] Parsed items successfully. Is Array?', Array.isArray(items));
        } catch (e) {
            console.error('[DEBUG] Items parsing error:', e);
            res.status(400);
            throw new Error('Invalid items format');
        }
    } else if (!items) {
        console.log('[DEBUG] items is falsy, setting to empty array');
        items = [];
        req.body.items = items;
    }

    if (!Array.isArray(items)) {
        console.error('[DEBUG] Items is NOT an array. Type:', typeof items, 'Value:', items);
        res.status(400);
        throw new Error('Items must be an array of sets');
    }

    const dcNo = dc_number || `DC-${Date.now()}`;

    // CHECK FOR DUPLICATE SET NUMBERS (Validation Rule: Lot + Dia + Set must be unique)
    const existingOutwards = await Outward.find({ lotNo, dia });
    const usedSetNumbers = new Set();
    existingOutwards.forEach(out => {
        out.items.forEach(item => usedSetNumbers.add(item.set_no.toString()));
    });

    // Handle file uploads for signatures
    let finalLotInchargeSignature = req.body.lotInchargeSignature;
    let finalAuthorizedSignature = req.body.authorizedSignature;
    let lotInchargeSignTime = req.body.lotInchargeSignTime;
    let authorizedSignTime = req.body.authorizedSignTime;

    if (req.files) {
        if (req.files.lotInchargeSignature) {
            finalLotInchargeSignature = `/${req.files.lotInchargeSignature[0].path.replace(/\\/g, '/')}`;
            lotInchargeSignTime = lotInchargeSignTime || new Date();
        }
        if (req.files.authorizedSignature) {
            finalAuthorizedSignature = `/${req.files.authorizedSignature[0].path.replace(/\\/g, '/')}`;
            authorizedSignTime = authorizedSignTime || new Date();
        }
    }

    const requestedSetNumbers = items.map(item => item.set_no.toString());
    const duplicates = requestedSetNumbers.filter(setNo => usedSetNumbers.has(setNo));

    if (duplicates.length > 0) {
        res.status(400);
        throw new Error(`Set Number(s) ${duplicates.join(', ')} already delivered for Lot ${lotNo} and DIA ${dia}`);
    }

    const outward = await Outward.create({
        user: req.user._id,
        dcNo,
        lotName,
        dateTime,
        dia,
        lotNo,
        partyName,
        process,
        address,
        vehicleNo,
        inTime,
        outTime,
        items: items.map(item => ({
            set_no: item.set_no,
            total_weight: item.total_weight || 0,
            rack_name: item.rack_name,
            pallet_number: item.pallet_number,
            colours: item.colours.map(c => ({
                colour: c.colour,
                weight: c.weight || 0,
                no_of_rolls: c.no_of_rolls || 0,
                roll_weight: c.roll_weight || 0
            }))
        })),
        lotInchargeSignature: finalLotInchargeSignature,
        authorizedSignature: finalAuthorizedSignature,
        lotInchargeSignTime: lotInchargeSignTime,
        authorizedSignTime: authorizedSignTime,
    });

    // Create notification
    await Notification.create({
        user: req.user._id,
        title: 'New Outward Created',
        body: `Outward entry processed for DC ${dcNo} (Lot: ${lotNo}).`,
        type: 'success'
    }).catch(err => console.error('Notification failed:', err));

    res.status(201).json(outward);
});

// @desc    Get all outward entries
// @route   GET /api/inventory/outward
// @access  Private
const getOutwards = asyncHandler(async (req, res) => {
    const { startDate, endDate, lotName, lotNo, dia } = req.query;

    let query = {};
    if (startDate || endDate) {
        query.dateTime = {}; // Note: dateTime is the field name in Outward model
        if (startDate) query.dateTime.$gte = startDate;
        if (endDate) query.dateTime.$lte = endDate;
    }
    if (lotName) query.lotName = { $regex: new RegExp(lotName, 'i') };
    if (lotNo) query.lotNo = { $regex: new RegExp(lotNo, 'i') };
    if (dia) query.dia = { $regex: new RegExp(dia, 'i') };

    const outwards = await Outward.find(query).sort({ dateTime: -1 });
    res.json(outwards);
});

// @desc    Delete an outward entry
// @route   DELETE /api/inventory/outward/:id
// @access  Private
const deleteOutward = asyncHandler(async (req, res) => {
    const outward = await Outward.findById(req.params.id);

    if (outward) {
        await outward.deleteOne();
        res.json({ message: 'Outward entry removed' });
    } else {
        res.status(404);
        throw new Error('Outward entry not found');
    }
});

// @desc    Update an outward entry
// @route   PUT /api/inventory/outward/:id
// @access  Private
const updateOutward = asyncHandler(async (req, res) => {
    const outward = await Outward.findById(req.params.id);

    if (outward) {
        let {
            lotName,
            dateTime,
            dia,
            lotNo,
            partyName,
            process,
            address,
            vehicleNo,
            inTime,
            outTime,
            items,
            dcNo
        } = req.body;

        if (typeof items === 'string') {
            items = JSON.parse(items);
        }

        outward.lotName = lotName || outward.lotName;
        outward.dateTime = dateTime || outward.dateTime;
        outward.dia = dia || outward.dia;
        outward.lotNo = lotNo || outward.lotNo;
        outward.partyName = partyName || outward.partyName;
        outward.process = process || outward.process;
        outward.address = address || outward.address;
        outward.vehicleNo = vehicleNo || outward.vehicleNo;
        outward.inTime = inTime || outward.inTime;
        outward.outTime = outTime || outward.outTime;
        outward.dcNo = dcNo || outward.dcNo;

        if (items) {
            outward.items = items.map(item => ({
                set_no: item.set_no,
                total_weight: item.total_weight || 0,
                rack_name: item.rack_name,
                pallet_number: item.pallet_number,
                colours: item.colours.map(c => ({
                    colour: c.colour,
                    weight: c.weight || 0,
                    no_of_rolls: c.no_of_rolls || 0,
                    roll_weight: c.roll_weight || 0
                }))
            }));
        }

        if (req.files) {
            if (req.files.lotInchargeSignature) {
                outward.lotInchargeSignature = `/${req.files.lotInchargeSignature[0].path.replace(/\\/g, '/')}`;
                outward.lotInchargeSignTime = new Date();
            }
            if (req.files.authorizedSignature) {
                outward.authorizedSignature = `/${req.files.authorizedSignature[0].path.replace(/\\/g, '/')}`;
                outward.authorizedSignTime = new Date();
            }
        }

        const updatedOutward = await outward.save();
        res.json(updatedOutward);
    } else {
        res.status(404);
        throw new Error('Outward entry not found');
    }
});


// @desc    Get Lot Aging Report
// @route   GET /api/inventory/reports/aging
// @access  Private
const getLotAgingReport = asyncHandler(async (req, res) => {
    const { lotNo, lotName, colour, dia, startDate, endDate } = req.query;

    let query = {};
    if (lotNo) query.lotNo = { $regex: new RegExp(lotNo, 'i') };
    if (lotName) query.lotName = { $regex: new RegExp(lotName, 'i') };

    if (startDate || endDate) {
        query.inwardDate = {};
        if (startDate) query.inwardDate.$gte = startDate;
        if (endDate) query.inwardDate.$lte = endDate;
    }

    const inwards = await Inward.find(query).sort({ inwardDate: 1 });

    let report = [];

    inwards.forEach((inward) => {
        // We need to map diaEntries to storageDetails if possible to get colour
        // Or if storageDetails exist, use them.
        // The requirement is to show Colour. Colour is in storageDetails -> rows -> colour.

        // Strategy: Iterate over storageDetails if available, as they contain the broken-down rolls/weights per colour.
        // If storageDetails is empty (old data or not entered), fallback to diaEntries (colour will be "N/A").

        if (inward.storageDetails && inward.storageDetails.length > 0) {
            inward.storageDetails.forEach(sd => {
                sd.rows.forEach(row => {
                    // Each row has a colour and setWeights
                    // We need total weight/rolls for this colour/dia combination
                    // But wait, storageDetails tracks sets, not necessarily strict rolls count matching diaEntries one-to-one in a simple way 
                    // unless we sum them up.
                    // The user wants "Rolls" and "Wt". 
                    // In storageDetails, we have 'setWeights'. Number of weights = number of sets (which might be rolls if 1 roll = 1 set, but usually multiple rolls).
                    // Actually `diaEntries` has the authoritative `recRoll` and `recWt`.
                    // `storageDetails` is for sticker mapping.
                    // If we want accurate inventory "Stock" aging, we should use the remaining balance. 
                    // But the report seems to be "Aging Details" of *Inwards*, i.e. when it came in.
                    // The requirement says "filter option with lotno,lotname,colour,dia".

                    // Let's explicitly try to link them. 
                    // If we strictly want "Inward" aging, we list what came in.
                    // If we split by colour, we must know how many rolls/weight per colour.
                    // `storageDetails` has `setWeights` (list of weights). count(setWeights) approx rolls (or sets).
                    // Let's assume 1 set ~ 1 roll/bundle for this report or just count the entries.

                    const setWeights = row.setWeights.map(w => parseFloat(w) || 0);
                    const totalWt = setWeights.reduce((a, b) => a + b, 0);
                    const totalRolls = setWeights.length; // Approximate if sets=rolls

                    if (totalWt > 0) {
                        report.push({
                            lot_number: inward.lotNo,
                            lot_name: inward.lotName,
                            inward_date: inward.inwardDate,
                            dia: sd.dia,
                            colour: row.colour, // THE NEW FIELD
                            rolls: totalRolls,
                            weight: totalWt,
                            age: Math.ceil((new Date() - new Date(inward.inwardDate)) / (1000 * 60 * 60 * 24))
                        });
                    }
                });
            });
        } else {
            // Fallback for non-sticker entries
            inward.diaEntries.forEach(entry => {
                report.push({
                    lot_number: inward.lotNo,
                    lot_name: inward.lotName,
                    inward_date: inward.inwardDate,
                    dia: entry.dia,
                    colour: 'N/A',
                    rolls: entry.recRoll,
                    weight: entry.recWt,
                    age: Math.ceil((new Date() - new Date(inward.inwardDate)) / (1000 * 60 * 60 * 24))
                });
            });
        }
    });

    // Apply filters that couldn't be done in DB query easily
    if (colour) {
        report = report.filter(r => r.colour && r.colour.toLowerCase().includes(colour.toLowerCase()));
    }
    if (dia) {
        report = report.filter(r => r.dia && r.dia.toLowerCase().includes(dia.toLowerCase()));
    }

    res.json(report);
});

// @desc    Update complaint solution for Inward
// @route   PUT /api/inventory/inward/:id/complaint-solution
const updateInwardComplaint = asyncHandler(async (req, res) => {
    const inward = await Inward.findById(req.params.id);

    if (inward) {
        inward.complaintReply = req.body.complaintReply || inward.complaintReply;
        inward.complaintResolution = req.body.complaintResolution || inward.complaintResolution;
        inward.complaintFindDate = req.body.complaintFindDate || inward.complaintFindDate;
        inward.complaintCompletionDate = req.body.complaintCompletionDate || inward.complaintCompletionDate;
        inward.complaintArrestLotNo = req.body.complaintArrestLotNo || inward.complaintArrestLotNo;
        inward.isComplaintCleared = req.body.isComplaintCleared !== undefined ? req.body.isComplaintCleared : inward.isComplaintCleared;

        const updatedInward = await inward.save();
        res.json(updatedInward);
    } else {
        res.status(404);
        throw new Error('Inward not found');
    }
});

// @desc    Get Quality & Complaint Audit Report
// @route   GET /api/inventory/reports/quality-audit
const getQualityAuditReport = asyncHandler(async (req, res) => {
    const { lotNo, isCleared } = req.query;

    let query = {
        $or: [
            { qualityStatus: 'Not OK' },
            { gsmStatus: 'Not OK' },
            { shadeStatus: 'Not OK' },
            { washingStatus: 'Not OK' },
            { complaintText: { $exists: true, $ne: '' } },
            { complaintResolution: { $exists: true, $ne: '' } },
            { complaintReply: { $exists: true, $ne: '' } }
        ]
    };

    if (lotNo) query.lotNo = { $regex: new RegExp(lotNo, 'i') };
    if (isCleared !== undefined) query.isComplaintCleared = isCleared === 'true';

    const report = await Inward.find(query).sort({ inwardDate: -1 });
    res.json(report);
});

// @desc    Get Lot Details for Auto-population
// @route   GET /api/inventory/inward/lot-details
// @access  Private
const getLotDetails = asyncHandler(async (req, res) => {
    const { lotName, lotNo } = req.query;

    if (!lotName || !lotNo) {
        return res.status(400).json({ message: 'Lot Name and Lot No are required' });
    }

    const cleanLotNo = lotNo.toString().trim();
    const cleanLotName = lotName.toString().trim();

    // Escape regex special characters just in case
    const escapedLotNo = cleanLotNo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const escapedLotName = cleanLotName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

    const inward = await Inward.findOne({
        lotNo: { $regex: new RegExp(`^\\s*${escapedLotNo}\\s*$`, 'i') },
        lotName: { $regex: new RegExp(`^\\s*${escapedLotName}\\s*$`, 'i') }
    });

    if (inward) {
        // Calculate existing totals per DIA
        const diaDetails = inward.diaEntries.map(entry => ({
            dia: entry.dia,
            existingRecRolls: entry.recRoll || entry.roll || 0,
            existingRecWt: entry.recWt || 0
        }));

        res.json(diaDetails);
    } else {
        res.json([]);
    }
});

// @desc    Get Distinct Lot Numbers from Inward
// @route   GET /api/inventory/inward/distinct-lots
const getDistinctLots = asyncHandler(async (req, res) => {
    const lots = await Inward.distinct('lotNo');
    // Map to object structure expected by frontend [{ lotNumber: '...' }]
    const result = lots.filter(l => l).map(l => ({ lotNumber: l }));
    res.json(result);
    res.json(result);
});

// @desc    Check for FIFO Violation (Set availability in previous lots)
// @route   GET /api/inventory/outward/check-fifo
const checkFifoViolation = asyncHandler(async (req, res) => {
    const { dia, setNo, rack, pallet } = req.query;

    if (!dia || !setNo) {
        res.status(400);
        throw new Error('Dia and Set Number are required');
    }

    console.log(`[FIFO Check] Checking for Dia: ${dia}, Set: ${setNo}, Rack: ${rack}, Pallet: ${pallet}`);

    // 1. Find all Inwards with this Dia, sorted by Date (Oldest first)
    // We need to look for ANY lot that has this combination available.
    // Logic: 
    // - Iterate through all lots (oldest to newest).
    // - If we find a lot that contains this specific Set No (mapped to Rack/Pallet if provided, or just Set No uniqueness within Dia)
    // - AND that set is NOT yet outwarded (balance > 0).
    // - Then that is the "Current FIFO Lot" for this Set.

    // However, the requirement is slightly more specific: 
    // "if I previously skipped an earlier lot and try to process a later lot... trigger notification... This Dia, Set Number... already available in a previous lot."

    // This implies we aren't just looking for "Is this set available ANYWHERE?".
    // We are looking for "Is this set available in an OLDER lot than the one I am currently working on?".
    // BUT, the current screen `_toggleSetSelection` doesn't pass the "Current Lot Date" or "Current Lot ID" easily to compare "Older".
    // AND the user selects "Lot Number" at the top of the screen.
    // SO, we know the "Current Selected Lot".

    // Revised Logic:
    // 1. Get the "Current Lot" (from query params - I need to add `currentLotNo` to request).
    // 2. Find the Inward Date of the Current Lot.
    // 3. Find all Lots OLDER than Current Lot (same Dia).
    // 4. Check if the requested Set (Set No) exists and is available in any of those OLDER lots.

    const { currentLotNo } = req.query;
    if (!currentLotNo) {
        // If no current lot is specified (rare), we can't compare "older". 
        // But maybe we just check ALL lots? 
        // Let's assume user ALWAYS selects a Lot No first.
        res.status(400);
        throw new Error('Current Lot Number is required');
    }

    const currentInward = await Inward.findOne({ lotNo: currentLotNo });
    if (!currentInward) {
        // Current lot not found? Can't do FIFO check against non-existent ref.
        return res.json({ violation: false });
    }

    // Find all lots OLDER than current lot
    const olderInwards = await Inward.find({
        'diaEntries.dia': dia,
        inwardDate: { $lt: currentInward.inwardDate },
        lotNo: { $ne: currentLotNo } // Exclude self just in case date is identical
    }).sort({ inwardDate: 1 });

    for (const oldLot of olderInwards) {
        // Check if Set exists in this Old Lot
        // We need to check if it was INWARDED
        let setInOldLot = false;

        if (oldLot.storageDetails && oldLot.storageDetails.length > 0) {
            oldLot.storageDetails.forEach(sd => {
                if (sd.dia === dia) {
                    sd.rows.forEach(row => {
                        // Check matching set index? 
                        // Logic: Set No 1 = Index 0.
                        // User passes setNo (string "1").
                        const setIdx = parseInt(setNo) - 1;
                        if (setIdx >= 0 && setIdx < row.setWeights.length) {
                            // This old lot HAS this set number.
                            // Check if Rack/Pallet matches? 
                            // User requirement: "This Dia, Set Number, Rack, and Pallet Number are already available..."
                            // This implies the Exact Same Physical Item (if Set No is unique globally or per Dia).
                            // If Set 1 is in Lot A (Rack A) and Set 1 is in Lot B (Rack B)... are they the same?
                            // Usually Set No resets per Lot? Or is it unique per Dia?
                            // "Select Set No (Unique)" in UI suggests unique per Lot.
                            // If Set 1 in Lot A and Set 1 in Lot B are different physical bundles, why block?
                            // "skipped an earlier lot... try to process a later lot"
                            // This means I should consume Lot A's Set 1 before Lot B's Set 1?
                            // YES. Standard FIFO. Consume Oldest Lot first.
                            // So if Lot A has a "Set 1" available, I shouldn't take "Set 1" from Lot B?
                            // Or simply, if Lot A has ANY stock, I should exhaust it?
                            // The prompt specifically says: "This Dia, Set Number, Rack, and Pallet Number are already available"
                            // This phrasing is tricky. It sounds like specific item duplication.
                            // BUT "skipped earlier lot" implies general FIFO.
                            // I will assume: If "Set <N>" exists in Older Lot and is NOT Outwarded, BLOCK.
                            // It doesn't matter if Rack matches. If Old Lot has a Set <N>, use it.

                            // WAIT, usually Set 1 in Lot A is totally different fabric from Set 1 in Lot B.
                            // Unless it's "Same Dia" logic where sets are interchangeable?
                            // Let's stick to the prompt's implied logic: 
                            // Check if Older Lot has this Set Number available.

                            setInOldLot = true;
                        }
                    });
                }
            });
        }

        if (setInOldLot) {
            // Check if it's already used (Outwarded)
            const oldLotOutward = await Outward.find({ lotNo: oldLot.lotNo, dia });
            let isUsed = false;
            oldLotOutward.forEach(out => {
                if (out.items) {
                    out.items.forEach(item => {
                        if (item.set_no && item.set_no.toString() === setNo.toString()) {
                            isUsed = true;
                        }
                    });
                }
            });

            if (!isUsed) {
                // VIOLATION FOUND!
                // Old Lot has this Set, and it's not used.
                return res.json({
                    violation: true,
                    lotNo: oldLot.lotNo,
                    lotName: oldLot.lotName,
                    inwardDate: oldLot.inwardDate,
                    message: `FIFO Violation: Set ${setNo} is available in older Lot ${oldLot.lotNo}. Please use that first.`
                });
            }
        }
    }

    res.json({ violation: false });
});

// @desc    Delete an inward entry
// @route   DELETE /api/inventory/inward/:id
// @access  Private
const deleteInward = asyncHandler(async (req, res) => {
    const inward = await Inward.findById(req.params.id);

    if (inward) {
        await inward.deleteOne();
        res.json({ message: 'Inward entry removed' });
    } else {
        res.status(404);
        throw new Error('Inward entry not found');
    }
});

// @desc    Update an inward entry
// @route   PUT /api/inventory/inward/:id
// @access  Private
const updateInward = asyncHandler(async (req, res) => {
    const inward = await Inward.findById(req.params.id);

    if (inward) {
        const {
            inwardDate,
            inTime,
            outTime,
            lotName,
            lotNo,
            fromParty,
            process,
            rate,
            gsm,
            vehicleNo,
            partyDcNo,
            diaEntries,
            storageDetails,
            qualityStatus,
            qualityImage,
            gsmStatus,
            gsmImage,
            shadeStatus,
            shadeImage,
            washingStatus,
            washingImage,
            complaintText,
            complaintImage,
            balanceImage,
        } = req.body;

        inward.inwardDate = inwardDate || inward.inwardDate;
        inward.inTime = inTime || inward.inTime;
        inward.outTime = outTime || inward.outTime;
        inward.lotName = lotName || inward.lotName;
        inward.lotNo = lotNo || inward.lotNo;
        inward.fromParty = fromParty || inward.fromParty;
        inward.process = process || inward.process;
        inward.rate = rate !== undefined ? Number(rate) : inward.rate;
        inward.gsm = gsm || inward.gsm;
        inward.vehicleNo = vehicleNo || inward.vehicleNo;
        inward.partyDcNo = partyDcNo || inward.partyDcNo;

        inward.qualityStatus = qualityStatus || inward.qualityStatus;
        inward.qualityImage = qualityImage || inward.qualityImage;
        inward.gsmStatus = gsmStatus || inward.gsmStatus;
        inward.gsmImage = gsmImage || inward.gsmImage;
        inward.shadeStatus = shadeStatus || inward.shadeStatus;
        inward.shadeImage = shadeImage || inward.shadeImage;
        inward.washingStatus = washingStatus || inward.washingStatus;
        inward.washingImage = washingImage || inward.washingImage;
        inward.complaintText = complaintText || inward.complaintText;
        inward.complaintImage = complaintImage || inward.complaintImage;
        inward.balanceImage = balanceImage || inward.balanceImage;

        if (diaEntries) {
            inward.diaEntries = typeof diaEntries === 'string' ? JSON.parse(diaEntries) : diaEntries;
        }
        if (storageDetails) {
            inward.storageDetails = typeof storageDetails === 'string' ? JSON.parse(storageDetails) : storageDetails;
        }

        if (req.files) {
            if (req.files.lotInchargeSignature) {
                inward.lotInchargeSignature = `/${req.files.lotInchargeSignature[0].path.replace(/\\/g, '/')}`;
            }
            if (req.files.authorizedSignature) {
                inward.authorizedSignature = `/${req.files.authorizedSignature[0].path.replace(/\\/g, '/')}`;
            }
            if (req.files.mdSignature) {
                inward.mdSignature = `/${req.files.mdSignature[0].path.replace(/\\/g, '/')}`;
            }
        }

        const updatedInward = await inward.save();
        res.json(updatedInward);
    } else {
        res.status(404);
        throw new Error('Inward entry not found');
    }
});

export {
    createInward,
    getInwards,
    deleteInward,
    updateInward,
    getLotsFifo,
    getBalancedSets,
    generateInwardNumber,
    generateDcNumber,
    createOutward,
    getOutwards,
    deleteOutward,
    updateOutward,
    getLotAgingReport,
    getInwardColours,
    getFifoRecommendation,
    updateInwardComplaint,
    getQualityAuditReport,
    getLotDetails,
    getDistinctLots,
    checkFifoViolation,
};

