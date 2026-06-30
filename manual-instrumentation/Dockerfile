FROM node:20-alpine AS deps
WORKDIR /app
COPY manual-instrumentation/package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

FROM deps AS build
COPY manual-instrumentation/tsconfig.json ./
COPY app/src ./src
COPY manual-instrumentation/tracer.ts ./tracer.ts
RUN npm run build

FROM node:20-alpine AS prod-deps
WORKDIR /app
COPY manual-instrumentation/package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi \
  && npm cache clean --force

FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY manual-instrumentation/package.json ./
USER node
EXPOSE 3000
CMD ["node", "-r", "./dist/tracer.js", "dist/main.js"]
