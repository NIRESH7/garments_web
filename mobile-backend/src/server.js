import app from './app.js';
import fs from 'fs';
import path from 'path';

const PORT = 5001; // process.env.PORT || 5001;

// Ensure uploads directory exists
const uploadsDir = path.join(path.resolve(), 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

app.listen(PORT, () => {
    console.log(`Server running in ${process.env.NODE_ENV} mode on port ${PORT}`);
});
