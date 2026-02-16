import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Company from '../src/modules/company/model.js';
import Inward from '../src/modules/inventory/inwardModel.js';

dotenv.config();

const testReports = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        console.log('\n--- Checking Company Info ---');
        let company = await Company.findOne({});
        if (!company) {
            company = await Company.create({ name: 'Default Test Corp', address: '123 Textile St' });
            console.log('Created default company');
        }
        console.log('Company:', JSON.stringify(company, null, 2));

        console.log('\n--- Simulating Aging Summary ---');
        const inwards = await Inward.find({});
        const summary = {
            '0-15 Days': { rolls: 0, weight: 0 },
            '16-30 Days': { rolls: 0, weight: 0 },
            '31-45 Days': { rolls: 0, weight: 0 },
            '45+ Days': { rolls: 0, weight: 0 },
        };
        const now = new Date();

        inwards.forEach(inward => {
            const age = Math.ceil((now - new Date(inward.inwardDate)) / (1000 * 60 * 60 * 24));
            let bucket = '45+ Days';
            if (age <= 15) bucket = '0-15 Days';
            else if (age <= 30) bucket = '16-30 Days';
            else if (age <= 45) bucket = '31-45 Days';

            const totalRolls = inward.diaEntries.reduce((acc, curr) => acc + (curr.recRoll || curr.roll || 0), 0);
            const totalWt = inward.diaEntries.reduce((acc, curr) => acc + (curr.recWt || 0), 0);

            summary[bucket].rolls += totalRolls;
            summary[bucket].weight += totalWt;
        });

        const report = Object.keys(summary).map(key => ({
            range: key,
            rolls: summary[key].rolls,
            weight: summary[key].weight.toFixed(2)
        }));
        console.log('Aging Summary Report:', JSON.stringify(report, null, 2));

        mongoose.connection.close();
    } catch (error) {
        console.error('❌ Error:', error);
    }
};

testReports();
