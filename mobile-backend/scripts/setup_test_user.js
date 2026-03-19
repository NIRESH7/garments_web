import axios from 'axios';

async function setup() {
    try {
        const res = await axios.post('http://localhost:5001/api/auth/create-admin', {
            name: 'Test Admin',
            email: 'testadmin@example.com',
            password: 'password123',
            role: 'admin'
        });
        console.log('Admin created or already exists:', res.data.email);
    } catch (err) {
        if (err.response && err.response.status === 400) {
            console.log('Admin already exists.');
        } else {
            console.error('Error creating admin:', err.message);
        }
    }
}
setup();
