import asyncHandler from 'express-async-handler';
import Order from '../order/model.js';

// @desc    Update order to paid (Payment Screen)
// @route   PUT /api/orders/:id/pay
// @access  Private
const updateOrderToPaid = asyncHandler(async (req, res) => {
    const order = await Order.findById(req.params.id);

    if (order) {
        order.isPaid = true;
        order.paidAt = Date.now();
        order.paymentResult = {
            id: req.body.id,
            status: req.body.status,
            update_time: req.body.update_time,
            email_address: req.body.email_address,
        };

        const updatedOrder = await order.save();

        res.json(updatedOrder);
    } else {
        res.status(404);
        throw new Error('Order not found');
    }
});

// @desc    Get Stripe/Razorpay Config/Key
// @route   GET /api/payments/config
// @access  Private
const getPaymentConfig = asyncHandler(async (req, res) => {
    res.json({
        stripeKey: process.env.STRIPE_PUBLISHABLE_KEY || 'pk_test_placeholder',
        razorpayKey: process.env.RAZORPAY_KEY_ID || 'rzp_test_placeholder',
    });
});

export { updateOrderToPaid, getPaymentConfig };
