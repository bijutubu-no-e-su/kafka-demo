FROM --platform=linux/amd64 node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --no-audit --no-fund
COPY writer.js ./
CMD ["node", "writer.js"]
