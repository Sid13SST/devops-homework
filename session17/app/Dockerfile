# ---------- build stage: install dependencies (including dev) and run the tests ----------
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm test

# ---------- runtime stage: production dependencies only ----------
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
# install production dependencies, then remove the npm/corepack CLIs: the app only
# needs the node runtime, and the bundled package managers carry their own
# vulnerable dependency trees that the image scan (correctly) flags.
RUN npm ci --omit=dev     && npm cache clean --force     && rm -rf /usr/local/lib/node_modules/npm               /usr/local/lib/node_modules/corepack               /usr/local/bin/npm               /usr/local/bin/npx               /usr/local/bin/corepack
COPY --from=build /app/app.js /app/server.js ./
# run as a non-root user
RUN addgroup -S nodeapp && adduser -S nodeapp -G nodeapp
USER nodeapp
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "server.js"]
