# Stage 1 - install dependencies and produce the static production build
FROM node:22-alpine AS build
WORKDIR /app

# Copy manifests first so npm install is cached when only source changes
COPY package.json ./
RUN npm install

# Copy the rest of the source and build
COPY vite.config.js index.html ./
COPY src ./src
RUN npm run build

# Stage 2 - serve the built static files with Nginx
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
