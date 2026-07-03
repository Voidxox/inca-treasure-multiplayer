# 多阶段构建：先在完整环境编译 TypeScript，再把产物装进精简运行镜像。
FROM node:22-alpine AS build
WORKDIR /app

# 先只拷贝依赖清单，利用层缓存：源码改动不会使 npm ci 缓存失效。
COPY package.json package-lock.json ./
RUN npm ci

# 拷贝源码与配置并构建（tsc 编译服务端 + 复制客户端产物）。
COPY tsconfig.server.json tsconfig.client.json index.html ./
COPY src ./src
COPY scripts ./scripts
RUN npm run build

# ---- 运行阶段：只装生产依赖，减小镜像体积与攻击面。----
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# 只拷贝构建产物，不带源码与开发依赖。
COPY --from=build /app/dist ./dist

# 以非 root 用户运行，符合最小权限原则。
USER node

EXPOSE 4174

# 容器编排可对 /health 探活（server 已内置该端点）。
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||4174)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/server/index.js"]
