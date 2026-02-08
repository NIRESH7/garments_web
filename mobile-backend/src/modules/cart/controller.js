import asyncHandler from 'express-async-handler';
import Cart from './model.js';

// @desc    Get user cart (Cart Screen)
// @route   GET /api/cart
// @access  Private
const getCart = asyncHandler(async (req, res) => {
    const cart = await Cart.findOne({ user: req.user._id });

    if (cart) {
        res.json(cart);
    } else {
        // Return empty cart if not found
        res.json({ cartItems: [] });
    }
});

// @desc    Update cart items (Sync Cart)
// @route   POST /api/cart
// @access  Private
const updateCart = asyncHandler(async (req, res) => {
    const { cartItems } = req.body;

    let cart = await Cart.findOne({ user: req.user._id });

    if (cart) {
        cart.cartItems = cartItems;
        const updatedCart = await cart.save();
        res.json(updatedCart);
    } else {
        const newCart = await Cart.create({
            user: req.user._id,
            cartItems,
        });
        res.status(201).json(newCart);
    }
});

// @desc    Clear cart
// @route   DELETE /api/cart
// @access  Private
const clearCart = asyncHandler(async (req, res) => {
    const cart = await Cart.findOne({ user: req.user._id });
    if (cart) {
        cart.cartItems = [];
        await cart.save();
        res.json({ message: 'Cart cleared' });
    } else {
        res.status(404);
        throw new Error('Cart not found');
    }
});

export { getCart, updateCart, clearCart };
