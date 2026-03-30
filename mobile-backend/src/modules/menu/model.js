import mongoose from 'mongoose';

const menuItemSchema = mongoose.Schema({
    title: {
        type: String,
        required: true
    },
    icon: {
        type: String,
        default: 'folder-outline'
    },
    route: {
        type: String,
        default: ''
    },
    isHeader: {
        type: Boolean,
        default: false
    },
    children: [
        {
            title: String,
            icon: String,
            route: String
        }
    ]
}, {
    timestamps: true
});

const Menu = mongoose.model('Menu', menuItemSchema);

export default Menu;
