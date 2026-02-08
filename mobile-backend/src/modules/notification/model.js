import mongoose from 'mongoose';

const notificationSchema = mongoose.Schema(
    {
        user: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
            ref: 'User',
        },
        title: { type: String, required: true },
        body: { type: String, required: true },
        type: { type: String, default: 'info' }, // 'order', 'promo', 'system'
        isRead: { type: Boolean, default: false },
        data: { type: Object }, // Navigation data for mobile
    },
    {
        timestamps: true,
    }
);

const Notification = mongoose.model('Notification', notificationSchema);

export default Notification;
