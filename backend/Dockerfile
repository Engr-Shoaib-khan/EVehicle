# Use official Node.js 18 LTS image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (production only)
RUN npm install --omit=dev

# Copy the rest of the application code
COPY . .

# Create uploads directory
RUN mkdir -p uploads/kyc

# Expose the application port
EXPOSE 5000

# Set environment variables (Placeholders - will be overridden by docker-compose or AWS)
ENV NODE_ENV=production
ENV PORT=5000

# Start the application
CMD ["npm", "start"]
