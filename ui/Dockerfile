FROM --platform=linux/amd64 node:20-alpine AS build
WORKDIR /app

# 依存インストール（lock があれば ci、なければ install）
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# ソース
COPY . .

# Vite dev server
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host"]
