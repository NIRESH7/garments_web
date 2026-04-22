import asyncHandler from 'express-async-handler';
import Inward from '../inventory/inwardModel.js';
import Outward from '../inventory/outwardModel.js';

// --- HELPERS (Synced with inventory controller) ---
const normalizeText = (value) => value?.toString().trim() ?? '';

const canonicalSet = (s) => {
    const normalized = normalizeText(s).toLowerCase().replace(/^set/i, '');
    const numericPart = normalized.replace(/[^0-9]/g, '');
    if (numericPart && !isNaN(numericPart)) {
        return parseInt(numericPart, 10).toString();
    }
    return normalized.replace(/[^a-z0-9]/g, '');
};

const canonicalColour = (c) => {
    return normalizeText(c).toLowerCase().replace(/[^a-z0-9]/g, '');
};

const canonicalKey = (setNo, colour) => {
    return `${canonicalSet(setNo)}|${canonicalColour(colour)}`;
};

// @desc    Get Detailed Drill-Down Summary for Dashboard
// @route   GET /api/inventory/drill-down
// @access  Private
/**
 * Query Parameters:
 * - type: 'opening' | 'inward' | 'outward' | 'closing'
 * - lotName: string (optional)
 * - lotNo: string (optional)
 * - dia: string (optional)
 * - startDate: ISO string (optional)
 * - endDate: ISO string (optional)
 */
const getDrillDownSummary = asyncHandler(async (req, res) => {
    try {
        const { type, lotName, lotNo, dia, setNo, startDate, endDate } = req.query;

        // Date Range Logic
        // Date Range Logic - If not provided, use all time (1970 to 2099)
        const start = startDate ? new Date(startDate) : new Date(0); // 1970
        const end = endDate ? new Date(endDate) : new Date('2099-12-31');

        console.log(`[DrillDown] Type: ${type}, LotName: ${lotName}, LotNo: ${lotNo}, Dia: ${dia}`);

        // 1. Fetch relevant data based on type
        // Opening: Everything before startDate
        // Inward: Inwards within period
        // Outward: Outwards within period
        // Closing: Everything before endDate
        
        let inwardQuery = {};
        let outwardQuery = {};

        if (type === 'opening') {
            inwardQuery.inwardDate = { $lt: start };
            outwardQuery.dateTime = { $lt: start };
        } else if (type === 'inward') {
            inwardQuery.inwardDate = { $gte: start, $lte: end };
            outwardQuery = { _id: null }; // No outwards for inward report
        } else if (type === 'outward') {
            // We still need inwards to get Metadata (GSM, Rate) even for Outward reports
            inwardQuery = {}; 
            outwardQuery.dateTime = { $gte: start, $lte: end };
        } else if (type === 'closing') {
            inwardQuery.inwardDate = { $lte: end };
            outwardQuery.dateTime = { $lte: end };
        }

        // Apply filters (Flexible with whitespace/trimming)
        if (lotName) {
            const finalLotName = lotName.toString().trim();
            const escapedName = finalLotName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
            const regexLotName = new RegExp('^\\s*' + escapedName + '\\s*$', 'i');
            inwardQuery.lotName = regexLotName;
            outwardQuery.lotName = regexLotName;
        }
        if (lotNo) {
            const finalLotNo = lotNo.toString().trim();
            const escapedNo = finalLotNo.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
            const regexLotNo = new RegExp('^\\s*' + escapedNo + '\\s*$', 'i');
            inwardQuery.lotNo = regexLotNo;
            outwardQuery.lotNo = regexLotNo;
        }
        if (dia) {
            const escapedDia = dia.toString().trim().replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
            const regexDia = new RegExp('^\\s*' + escapedDia + '\\s*$', 'i');
            inwardQuery['diaEntries.dia'] = regexDia; // Force inward to match DIA if at set level
            outwardQuery.dia = regexDia;
        }

        const inwards = inwardQuery._id === null ? [] : await Inward.find(inwardQuery).lean();
        const outwards = outwardQuery._id === null ? [] : await Outward.find(outwardQuery).lean();

        console.log(`[DrillDown] Found ${inwards.length} inwards and ${outwards.length} outwards`);

        // HEURISTIC: Check if this LOT/DIA is "Set Wise"
        // We look at all inwards for this DIA to see if any have more than 1 set
        let globalMaxSets = 0;
        if (lotName && lotNo && dia) {
            inwards.forEach(inw => {
                inw.storageDetails?.forEach(s => {
                    if (s.dia?.toString().trim() === dia.toString().trim()) {
                        const rows = Array.isArray(s.rows) ? s.rows : [];
                        rows.forEach(r => {
                            if (Array.isArray(r.setWeights)) {
                                globalMaxSets = Math.max(globalMaxSets, r.setWeights.length);
                            }
                        });
                    }
                });
            });
        }
        console.log(`[DrillDown] Global Max Sets for ${lotNo}/${dia}: ${globalMaxSets}`);

        // 2. Determine Next Level of Drill-Down
        // Level 1: Group by lotName (if lotName is not provided)
        // Level 2: Group by lotNo (if lotName is provided but lotNo is not)
        // Level 3: Group by dia (if lotNo is provided but dia is not)
        // Level 4: Group by color (if dia is provided)
        
        let results = [];
        const groupMap = new Map();

        // Helper to get or create group entry
        const getGroup = (key, date = null) => {
            if (!groupMap.has(key)) {
                groupMap.set(key, { name: key, totalRolls: 0, totalWeight: 0, totalValue: 0, date: date });
            } else if (date && (!groupMap.get(key).date || new Date(date) < new Date(groupMap.get(key).date))) {
                groupMap.get(key).date = date; // Track earliest inward for aging
            }
            return groupMap.get(key);
        };

        // Process Inwards
        inwards.forEach(inw => {
            inw.diaEntries.forEach(de => {
                if (dia && de.dia !== dia) return;
                
                let key;
                if (!lotName) {
                    key = inw.lotName ? inw.lotName.toUpperCase().trim() : 'UNKNOWN';
                } else if (!lotNo) {
                    key = inw.lotNo ? inw.lotNo.toUpperCase().trim() : 'UNKNOWN';
                } else if (!dia) {
                    key = de.dia;
                } else {
                    key = 'DEEP_LEVEL';
                }
                
                // Extra safety for DIA level in Inward
                if (dia && de.dia?.toString().trim() !== dia.toString().trim()) return;

                if (key !== 'DEEP_LEVEL') {
                    const group = getGroup(key, inw.inwardDate || inw.dateTime);
                    
                    // FIXED: Only add weight/rolls/value if we are NOT in an Outward-only report
                    if (type !== 'outward') {
                        const weight = parseFloat(de.recWt || 0);
                        const rolls = parseInt(de.recRoll || de.roll || 0);
                        const rate = parseFloat(de.rate || inw.rate || 0);
                        
                        group.totalWeight += weight;
                        group.totalRolls += rolls;
                        group.totalValue += (weight * rate);
                    }
                }
            });
            
            // Process Storage Details for Level 4/5 (Set/Color)
            if (lotName && lotNo && dia) {
                const storage = Array.isArray(inw.storageDetails) ? inw.storageDetails : [];
                storage.forEach(s => {
                    if (s.dia !== dia) return;
                    const rows = Array.isArray(s.rows) ? s.rows : [];
                    
                    const maxSetsInStorage = globalMaxSets; // Use global heuristic

                    if (!setNo) {
                        // Level 4: Group by Set (UNLESS it's a single set entry)
                        if (maxSetsInStorage > 1) {
                            rows.forEach(row => {
                                if (Array.isArray(row.setWeights)) {
                                    row.setWeights.forEach((weightStr, index) => {
                                        if (weightStr !== null && weightStr !== undefined && weightStr !== '') {
                                            const setKey = `Set ${canonicalSet(index + 1)}`;
                                            const group = getGroup(setKey, inw.inwardDate || inw.dateTime);
                                            const weight = parseFloat(weightStr);
                                            
                                            const diaEntry = inw.diaEntries.find(d => d.dia === dia);
                                            const rate = parseFloat(diaEntry?.rate || inw.rate || 0);
                                            
                                            group.totalWeight += (type === 'outward' ? 0 : weight);
                                            group.totalRolls += (type === 'outward' ? 0 : 1);
                                            group.totalValue += (type === 'outward' ? 0 : (weight * rate));
                                        }
                                    });
                                }
                            });
                        } else {
                            // SKIP SET LEVEL: Group by Color directly
                            // Source of truth for rolls is the diaEntries (main grid)
                            const diaEntry = inw.diaEntries.find(d => d.dia === dia);
                            const totalGridRolls = parseInt(diaEntry?.recRoll || diaEntry?.roll || 0);
                            const totalStorageWeight = rows.reduce((sum, r) => sum + parseFloat(r.setWeights?.[0] || 0), 0);

                            rows.forEach(row => {
                                if (Array.isArray(row.setWeights) && row.setWeights[0]) {
                                    const colorKey = row.colour || 'Unknown';
                                    const group = getGroup(colorKey, inw.inwardDate || inw.dateTime);
                                    const weight = parseFloat(row.setWeights[0]);
                                    
                                    const rate = parseFloat(diaEntry?.rate || inw.rate || 0);
                                    
                                    // Proportionally allocate rolls from the main grid
                                    const proportion = totalStorageWeight > 0 ? (weight / totalStorageWeight) : (1 / rows.length);
                                    const allocatedRolls = proportion * totalGridRolls;

                                    group.totalWeight += (type === 'outward' ? 0 : weight);
                                    group.totalRolls += (type === 'outward' ? 0 : allocatedRolls); 
                                    group.totalValue += (type === 'outward' ? 0 : (weight * rate));
                                    group.isColorLevel = true; // Signal to frontend
                                    
                                    if (!group.rack) group.rack = s.racks ? s.racks[0] : '';
                                    if (!group.pallet) group.pallet = s.pallets ? s.pallets[0] : '';
                                    if (!group.gsm) group.gsm = row.gsm || inw.gsm || '';
                                    if (!group.inwardNo) group.inwardNo = inw.inwardNo;
                                }
                            });
                        }
                    } else {
                        // Level 5: Group by Color inside the given Set
                        const targetSetIndex = parseInt(setNo.replace(/Set /i, '').trim()) - 1;
                        rows.forEach(row => {
                            if (Array.isArray(row.setWeights) && row.setWeights[targetSetIndex]) {
                                const weightStr = row.setWeights[targetSetIndex];
                                if (weightStr !== null && weightStr !== undefined && weightStr !== '') {
                                    const colorKey = row.colour || 'Unknown';
                                    const group = getGroup(colorKey);
                                    const weight = parseFloat(weightStr);
                                    
                                    const diaEntry = inw.diaEntries.find(d => d.dia === dia);
                                    const rate = parseFloat(diaEntry?.rate || inw.rate || 0);
                                    
                                    group.totalWeight += (type === 'outward' ? 0 : weight);
                                    group.totalRolls += (type === 'outward' ? 0 : 1);
                                    group.totalValue += (type === 'outward' ? 0 : (weight * rate));

                                    // Add details only if not already present or if we want the FIRST one
                                    if (!group.rack) group.rack = s.racks ? s.racks[targetSetIndex] : '';
                                    if (!group.pallet) group.pallet = s.pallets ? s.pallets[targetSetIndex] : '';
                                    if (!group.gsm) group.gsm = row.gsm || inw.gsm || '';
                                    if (!group.inwardNo) group.inwardNo = inw.inwardNo;
                                    if (!group.fromParty) group.fromParty = inw.fromParty;
                                    if (!group.date) group.date = inw.inwardDate;
                                }
                            }
                        });
                    }
                });
            }
        });

        // Process Outwards (Subtract from totals if type is Opening or Closing)
        outwards.forEach(out => {
            const isReduction = (type === 'opening' || type === 'closing' || type === 'outward');
            const multiplier = (type === 'opening' || type === 'closing') ? -1 : 1;

            let key;
            if (!lotName) {
                key = out.lotName ? out.lotName.toUpperCase().trim() : 'UNKNOWN';
            } else if (!lotNo) {
                key = out.lotNo ? out.lotNo.toUpperCase().trim() : 'UNKNOWN';
            } else if (!dia) {
                key = out.dia;
            } else {
                key = 'DEEP_LEVEL';
            }

            // Extra safety for DIA level in Outward
            if (dia && out.dia?.toString().trim() !== dia.toString().trim()) return;

            if (key !== 'DEEP_LEVEL') {
                const group = getGroup(key);
                const items = Array.isArray(out.items) ? out.items : [];
                items.forEach(item => {
                    const weight = parseFloat(item.total_weight || 0);
                    let rolls = 0;
                    if (Array.isArray(item.colours)) {
                        item.colours.forEach(c => rolls += (parseInt(c.no_of_rolls) || 0));
                    }
                    
                    group.totalWeight += (weight * multiplier);
                    group.totalRolls += (rolls * multiplier);
                    
                    // Outward needs a rate from the corresponding inward
                    // Find any inward with same lotNo and dia to get the rate
                    const inwardForRate = inwards.find(inw => 
                        inw.lotNo?.toUpperCase().trim() === out.lotNo?.toUpperCase().trim() &&
                        inw.lotName?.toUpperCase().trim() === out.lotName?.toUpperCase().trim()
                    );
                    const diaEntry = inwardForRate?.diaEntries?.find(d => d.dia === out.dia);
                    const rate = parseFloat(diaEntry?.rate || inwardForRate?.rate || 0);
                    
                    group.totalValue += (weight * multiplier * rate);
                });
            } else if (lotName && lotNo && dia) {
                // Deep level for Outward
                const items = Array.isArray(out.items) ? out.items : [];
                
                if (!setNo) {
                    // Level 4: Group by Set (OR Color if not set-wise)
                    if (globalMaxSets > 1) {
                        items.forEach(item => {
                            const setKey = `Set ${canonicalSet(item.set_no || 'Unknown')}`;
                            const group = getGroup(setKey);
                            const weight = parseFloat(item.total_weight || 0);
                            let rolls = 0;
                            if (Array.isArray(item.colours)) {
                                item.colours.forEach(c => rolls += (parseInt(c.no_of_rolls) || 0));
                            }
                            
                            group.totalWeight += (weight * multiplier);
                            group.totalRolls += (rolls * multiplier);
    
                            const inwardForRate = inwards.find(inw => 
                                inw.lotNo?.toUpperCase().trim() === out.lotNo?.toUpperCase().trim() &&
                                inw.lotName?.toUpperCase().trim() === out.lotName?.toUpperCase().trim()
                            );
                            const diaEntry = inwardForRate?.diaEntries?.find(d => d.dia === out.dia);
                            const rate = parseFloat(diaEntry?.rate || inwardForRate?.rate || 0);
                            group.totalValue += (weight * multiplier * rate);
                        });
                    } else {
                        // SKIP SET LEVEL: Group by Color directly for Outward
                        items.forEach(item => {
                            if (Array.isArray(item.colours)) {
                                item.colours.forEach(c => {
                                    const colorKey = c.colour || 'Unknown';
                                    const group = getGroup(colorKey);
                                    const weight = parseFloat(c.weight || 0);
                                    const rolls = parseInt(c.no_of_rolls || 0);
                                    
                                    group.totalWeight += (weight * multiplier);
                                    group.totalRolls += (rolls * multiplier);
                                    
                                    const inwardForRate = inwards.find(inw => 
                                        inw.lotNo?.toUpperCase().trim() === out.lotNo?.toUpperCase().trim() &&
                                        inw.lotName?.toUpperCase().trim() === out.lotName?.toUpperCase().trim()
                                    );
                                    const diaEntry = inwardForRate?.diaEntries?.find(d => d.dia === out.dia);
                                    const rate = parseFloat(diaEntry?.rate || inwardForRate?.rate || 0);
                                    group.totalValue += (weight * multiplier * rate);
                                    group.isColorLevel = true;
                                });
                            }
                        });
                    }
                } else {
                    // Level 5: Group by Colour inside the given Set
                    const targetSetNo = canonicalSet(setNo);
                    items.forEach(item => {
                        if (canonicalSet(item.set_no) === targetSetNo) {
                            if (Array.isArray(item.colours)) {
                                item.colours.forEach(c => {
                                    const colorKey = c.colour || 'Unknown';
                                    const group = getGroup(colorKey);
                                    const weight = parseFloat(c.weight || 0);
                                    const rolls = parseInt(c.no_of_rolls || 0);
                                    
                                    // Rate lookup for outward color level
                                    const inwardForRate = inwards.find(inw => 
                                        inw.lotNo?.toUpperCase().trim() === out.lotNo?.toUpperCase().trim() &&
                                        inw.lotName?.toUpperCase().trim() === out.lotName?.toUpperCase().trim()
                                    );
                                    const diaEntry = inwardForRate?.diaEntries?.find(d => d.dia === dia);
                                    const rate = parseFloat(diaEntry?.rate || inwardForRate?.rate || 0);

                                    group.totalWeight += (weight * multiplier);
                                    group.totalRolls += (rolls * multiplier);
                                    group.totalValue += (weight * multiplier * rate);

                                    // Add details for Outward if possible (referencing Inward)
                                    if (inwardForRate) {
                                        const targetSetIndex = parseInt(targetSetNo) - 1;
                                        const storage = Array.isArray(inwardForRate.storageDetails) ? inwardForRate.storageDetails : [];
                                        const s = storage.find(st => st.dia === dia);
                                        const row = s?.rows?.find(r => r.colour?.toUpperCase().trim() === colorKey.toUpperCase().trim());
                                        
                                        if (!group.rack) group.rack = s?.racks ? s.racks[targetSetIndex] : '';
                                        if (!group.pallet) group.pallet = s?.pallets ? s.pallets[targetSetIndex] : '';
                                        if (!group.gsm) group.gsm = row?.gsm || inwardForRate.gsm || '';
                                        if (!group.inwardNo) group.inwardNo = inwardForRate.inwardNo;
                                        if (!group.fromParty) group.fromParty = inwardForRate.fromParty;
                                        if (!group.date) group.date = out.dateTime; // FIXED: Use Outward Date
                                    }
                                });
                            }
                        }
                    });
                }
            }
        });

        // Finalize results
        results = Array.from(groupMap.values()).map(g => {
            let agingDays = 0;
            if (g.date) {
                const diffTime = Math.abs(new Date() - new Date(g.date));
                agingDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
            }
            return {
                ...g,
                totalRolls: Math.max(0, Math.round(g.totalRolls)),
                totalWeight: Math.max(0, parseFloat(g.totalWeight.toFixed(3))),
                totalValue: Math.max(0, parseFloat(g.totalValue.toFixed(2))),
                days: agingDays
            };
        }).filter(g => g.totalWeight > 0.01 && g.totalRolls > 0); // Only show positive stock

        res.json(results);
    } catch (error) {
        console.error('[DrillDown Error]', error);
        res.status(500).json({ message: 'Error fetching drill-down data', error: error.message });
    }
});

export { getDrillDownSummary };
