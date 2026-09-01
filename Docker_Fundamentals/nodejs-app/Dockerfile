# Small official Node.js base image
FROM node:22-alpine

# All app files live here inside the container
WORKDIR /app

# Copy the manifest first so this layer is cached when only source changes
COPY package.json ./

# Copy the application source
COPY server.js ./

# Document the port the app listens on
EXPOSE 3000

# Start the server
CMD ["node", "server.js"]
