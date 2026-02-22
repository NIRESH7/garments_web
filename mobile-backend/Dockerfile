# Use Node.js 18 alpine for a lightweight image
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy app source source
COPY . .

# Expose the port the app runs on
EXPOSE 5001

# Start the application
CMD [ "npm", "start" ]
