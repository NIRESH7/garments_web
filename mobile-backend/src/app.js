// Load env vars at the very top (using import 'dotenv/config' would be even better but this is safer for now)
import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import helmet from 'helmet';
import path from 'path';
import connectDB from './config/db.js';
import { errorHandler, notFound } from './middleware/errorMiddleware.js';
import fetch from 'node-fetch';

const app = express();
const isProduction = process.env.NODE_ENV === 'production';

// 1. Move logging to the top to catch everything
app.use(morgan(isProduction ? 'combined' : 'dev'));

if (!isProduction) {
    app.use((req, res, next) => {
        console.log(`[INCOMING] ${req.method} ${req.url}`);
        next();
    });
}

// Enable CORS with a robust global override for development
app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin) {
        res.header('Access-Control-Allow-Origin', origin);
    } else {
        res.header('Access-Control-Allow-Origin', '*');
    }
    
    res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS,PATCH');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, Cross-Origin-Resource-Policy, Content-Length');
    res.header('Access-Control-Allow-Credentials', 'true');
    res.header('Cross-Origin-Resource-Policy', 'cross-origin');
    
    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});

// Also keep the cors package for standard API routes
app.use(cors({
    origin: true, // reflect origin
    credentials: true
}));
app.use(express.json({ limit: '20mb' }));

// Routes
app.get('/', (req, res) => {
    res.json({ message: 'Welcome to Mobile API V1' });
});

// Import module routes
import authRoutes from './modules/auth/routes.js';
import userRoutes from './modules/user/routes.js';
import productRoutes from './modules/product/routes.js';
import homeRoutes from './modules/home/routes.js';
import cartRoutes from './modules/cart/routes.js';
import orderRoutes from './modules/order/routes.js';
import paymentRoutes from './modules/payment/routes.js';
import notificationRoutes from './modules/notification/routes.js';
import supportRoutes from './modules/support/routes.js';
import masterRoutes from './modules/master/routes.js';
import inventoryRoutes from './modules/inventory/routes.js';
import productionRoutes from './modules/production/routes.js';
import colorPredictRoutes from './modules/color-predict/routes.js';
import companyRoutes from './modules/company/routes.js';
import uploadRoutes from './modules/upload/routes.js';
import aiRoutes from './modules/ai/routes.js';
import taskRoutes from './modules/task/routes.js';
import { getDrillDownSummary } from './modules/inventory/drillDownController.js';
import { protect } from './middleware/authMiddleware.js';

app.get('/api/inventory/drill-down', protect, getDrillDownSummary);
app.get('/api/inventory/drilldown', protect, getDrillDownSummary);

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/home', homeRoutes);
app.use('/api/products', productRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/support', supportRoutes);
app.use('/api/master', masterRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/production', productionRoutes);
app.use('/api/color-predict', colorPredictRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/company', companyRoutes);
app.use('/api/ai', aiRoutes);
if (!isProduction) {
    console.log('DEBUG: Registering /api/tasks route');
}
app.use('/api/tasks', taskRoutes);

// Proxy for S3 images to avoid CORS on Web
app.get('/api/proxy-image', async (req, res) => {
    const imageUrl = req.query.url;
    if (!imageUrl) return res.status(400).send('URL is required');
    try {
        const response = await fetch(imageUrl);
        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);
        
        res.set('Content-Type', response.headers.get('content-type') || 'image/jpeg');
        res.set('Access-Control-Allow-Origin', '*');
        res.set('Cache-Control', 'public, max-age=86400'); // 24h cache
        res.send(buffer);
    } catch (error) {
        console.error('Proxy Error:', error);
        res.status(500).send('Error fetching image');
    }
});

// Serve uploads with explicit headers to support Flutter Web (Html and CanvasKit)
app.use('/uploads', (req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Cross-Origin-Resource-Policy', 'cross-origin');
    next();
}, express.static(path.join(path.resolve(), 'uploads')));

// Error Handling
app.use(notFound);
app.use(errorHandler);

export default app;
