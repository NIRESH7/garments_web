import app from './app.js';
import fs from 'fs';
import path from 'path';

const PORT = process.env.PORT || 5001;

// Ensure uploads directory exists
const uploadsDir = path.join(path.resolve(), 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});