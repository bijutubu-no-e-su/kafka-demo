# --- Build stage ---
FROM --platform=linux/amd64 node:20-alpine AS build
WORKDIR /app
# lock があれば一緒にコピー
COPY package.json package-lock.json* ./
# lock があるなら ci、無ければ install
RUN if [ -f package-lock.json ]; then \
      npm ci --no-audit --no-fund; \
    else \
      npm install --no-audit --no-fund; \
    fi
COPY . .
RUN npm run build

# --- Runtime stage ---
FROM --platform=linux/amd64 node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev --no-audit --no-fund; \
    else \
      npm install --omit=dev --no-audit --no-fund; \
    fi
COPY --from=build /app/dist ./dist
COPY server.js ./
EXPOSE 3000
CMD ["node", "server.js"]
