import express from 'express';
import dotenv from 'dotenv';
import cors from 'cors';
import morgan from 'morgan';
import helmet from 'helmet';
import path from 'path';
import connectDB from './config/db.js';
import { errorHandler, notFound } from './middleware/errorMiddleware.js';

// Load env vars
dotenv.config();

// Connect to database
connectDB();

const app = express();
const isProduction = process.env.NODE_ENV === 'production';

// Custom CORS & Logging Middleware for Dev
app.use((req, res, next) => {
    if (process.env.NODE_ENV !== 'production') {
        console.log(`DEBUG: [${new Date().toISOString()}] ${req.method} ${req.url}`);
        console.log(`DEBUG: Origin: ${req.headers.origin}`);
    }

    const origin = req.headers.origin;
    // In development, reflect any origin to satisfy CORS
    if (origin) {
        res.header('Access-Control-Allow-Origin', origin);
    } else {
        res.header('Access-Control-Allow-Origin', '*');
    }

    res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS,PATCH');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With, Accept');
    res.header('Access-Control-Allow-Credentials', 'true');

    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});
app.use(express.json({ limit: '20mb' }));
app.use(morgan(isProduction ? 'combined' : 'dev'));

if (!isProduction) {
    app.use((req, res, next) => {
        console.log(`DEBUG: Request URL: ${req.url}`);
        next();
    });
}

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

const __dirname = path.resolve();
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Error Handling
app.use(notFound);
app.use(errorHandler);

export default app;
