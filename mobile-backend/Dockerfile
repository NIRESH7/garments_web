# Use Node.js 20 alpine (required for OpenAI file uploads / File global support)
FROM node:20-alpine

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
