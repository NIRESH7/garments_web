import axios from 'axios';

const login = async () => {
    try {
        const response = await axios.post('http://13.220.94.83:5001/api/auth/login', {
            email: 'admin@example.com',
            password: 'password123'
        });
        console.log('Login Successful:', response.data);
    } catch (error) {
        if (error.response) {
            console.error('Login Failed:', error.response.status, error.response.data);
        } else {
            console.error('Login Error:', error.message);
        }
    }
};

login();
