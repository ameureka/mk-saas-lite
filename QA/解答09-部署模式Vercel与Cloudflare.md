# 问题9：关于部署模式，是在 Vercel 上部署的，以及如何配置 Cloudflare 进行部署？

## 概述

MkSaaS 支持多种部署方式，主要包括 **Vercel**、**Cloudflare Workers** 和 **Docker** 部署。每种部署方式都有其特点和适用场景。

## 部署方式对比

| 特性 | Vercel | Cloudflare Workers | Docker |
|------|--------|-------------------|--------|
| 部署难度 | ⭐ 极简 | ⭐⭐ 简单 | ⭐⭐⭐ 中等 |
| 冷启动 | 快 | 极快 | 无冷启动 |
| 全球分布 | 是 | 是 | 取决于配置 |
| 数据库支持 | 全部 | Postgres/D1 | 全部 |
| 成本 | 中等 | 低 | 可控 |
| 扩展性 | 自动 | 自动 | 手动 |
| 适用场景 | 通用 SaaS | 高并发应用 | 自建服务器 |

## 方案一：Vercel 部署（推荐）

### 特点

- **零配置部署**: 连接 GitHub 即可自动部署
- **全球 CDN**: 自动分发到全球边缘节点
- **自动 HTTPS**: 免费 SSL 证书
- **预览部署**: 每个 PR 自动生成预览环境
- **环境变量管理**: 可视化配置
- **分析工具**: 内置性能分析

### 部署步骤

#### 1. 准备工作

确保项目已推送到 GitHub:

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/yourusername/your-repo.git
git push -u origin main
```

#### 2. 连接 Vercel

1. 访问 [vercel.com](https://vercel.com)
2. 使用 GitHub 账号登录
3. 点击 "New Project"
4. 选择你的 GitHub 仓库
5. 点击 "Import"

#### 3. 配置项目

Vercel 会自动检测 Next.js 项目，默认配置：

- **Framework Preset**: Next.js
- **Build Command**: `pnpm build`
- **Output Directory**: `.next`
- **Install Command**: `pnpm install`

#### 4. 配置环境变量

在 Vercel Dashboard 中添加环境变量：

```env
# 数据库
DATABASE_URL=postgresql://user:password@host:5432/database

# Better Auth
BETTER_AUTH_SECRET=your-secret-key
BETTER_AUTH_URL=https://yourdomain.com

# GitHub OAuth
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Stripe
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_...

# Stripe 价格 ID
NEXT_PUBLIC_STRIPE_PRICE_PRO_MONTHLY=price_...
NEXT_PUBLIC_STRIPE_PRICE_PRO_YEARLY=price_...
NEXT_PUBLIC_STRIPE_PRICE_LIFETIME=price_...

# 邮件服务
RESEND_API_KEY=re_...

# 存储服务
STORAGE_REGION=auto
STORAGE_ACCESS_KEY_ID=your-access-key
STORAGE_SECRET_ACCESS_KEY=your-secret-key
STORAGE_BUCKET_NAME=your-bucket
STORAGE_ENDPOINT=https://your-endpoint.com
STORAGE_PUBLIC_URL=https://cdn.yourdomain.com
```

#### 5. 部署

点击 "Deploy" 按钮，Vercel 会自动：

1. 克隆代码
2. 安装依赖
3. 运行构建
4. 部署到全球 CDN
5. 分配域名

#### 6. 配置自定义域名

1. 在 Vercel Dashboard 进入项目设置
2. 点击 "Domains"
3. 添加你的域名
4. 按照提示配置 DNS 记录

DNS 配置示例：

```
类型    名称    值
A       @       76.76.21.21
CNAME   www     cname.vercel-dns.com
```

#### 7. 配置 Webhook

在 Stripe Dashboard 中配置 Webhook URL:

```
https://yourdomain.com/api/webhooks/stripe
```

### Vercel 配置文件

#### vercel.json

```json
{
  "functions": {
    "src/app/api/**/*": {
      "maxDuration": 300  // API 路由最大执行时间（秒）
    }
  },
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-XSS-Protection",
          "value": "1; mode=block"
        }
      ]
    }
  ],
  "rewrites": [
    {
      "source": "/api/:path*",
      "destination": "/api/:path*"
    }
  ]
}
```

### Vercel CLI 部署

```bash
# 安装 Vercel CLI
npm i -g vercel

# 登录
vercel login

# 部署到预览环境
vercel

# 部署到生产环境
vercel --prod

# 查看部署日志
vercel logs
```

### 性能优化

#### 1. 图片优化

```typescript
// next.config.ts
export default {
  images: {
    unoptimized: true,  // 禁用自动优化（节省配额）
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'cdn.yourdomain.com',
      },
    ],
  },
};
```

#### 2. 缓存配置

```typescript
// 页面级缓存
export const revalidate = 3600; // 1小时

// API 路由缓存
export async function GET() {
  return NextResponse.json(data, {
    headers: {
      'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400',
    },
  });
}
```

#### 3. 边缘函数

```typescript
// 使用 Edge Runtime
export const runtime = 'edge';

export async function GET() {
  // 在边缘节点执行
  return NextResponse.json({ message: 'Hello from Edge' });
}
```

### 监控和分析

#### 1. Vercel Analytics

```typescript
// src/app/layout.tsx
import { Analytics } from '@vercel/analytics/react';

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  );
}
```

#### 2. Speed Insights

```typescript
import { SpeedInsights } from '@vercel/speed-insights/next';

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <SpeedInsights />
      </body>
    </html>
  );
}
```

### 常见问题

#### 1. 构建超时

增加构建超时时间（Pro 计划）:

```json
{
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/next",
      "config": {
        "maxDuration": 900
      }
    }
  ]
}
```

#### 2. 函数大小限制

优化依赖，减少函数体积:

```bash
# 分析包大小
pnpm build
pnpm analyze

# 移除未使用的依赖
pnpm prune
```

#### 3. 数据库连接

使用连接池避免连接耗尽:

```typescript
const client = postgres(process.env.DATABASE_URL!, {
  max: 1,  // Serverless 环境使用单连接
});
```

## 方案二：Cloudflare Workers 部署

### 特点

- **极快的冷启动**: 毫秒级启动
- **全球分布**: 300+ 数据中心
- **低成本**: 免费额度 100,000 请求/天
- **边缘计算**: 在用户附近执行代码
- **KV 存储**: 内置键值存储
- **D1 数据库**: Serverless SQLite

### 分支说明

MkSaaS 提供两个 Cloudflare 分支：

1. **cloudflare**: 使用 PostgreSQL 数据库
2. **cloudflare-d1**: 使用 Cloudflare D1 数据库

### 部署步骤（cloudflare 分支）

#### 1. 切换分支

```bash
git checkout cloudflare
pnpm install
```

#### 2. 安装 Wrangler CLI

```bash
npm install -g wrangler

# 登录 Cloudflare
wrangler login
```

#### 3. 配置 wrangler.toml

```toml
name = "my-app"
compatibility_date = "2024-01-01"
pages_build_output_dir = ".vercel/output/static"

[env.production]
vars = { NODE_ENV = "production" }

[env.production.vars]
BETTER_AUTH_URL = "https://yourdomain.com"

# 环境变量（敏感信息使用 secrets）
```

#### 4. 设置 Secrets

```bash
# 设置数据库 URL
wrangler secret put DATABASE_URL

# 设置 Auth Secret
wrangler secret put BETTER_AUTH_SECRET

# 设置 Stripe 密钥
wrangler secret put STRIPE_SECRET_KEY
wrangler secret put STRIPE_WEBHOOK_SECRET

# 设置 OAuth 密钥
wrangler secret put GITHUB_CLIENT_SECRET
wrangler secret put GOOGLE_CLIENT_SECRET

# 设置邮件 API 密钥
wrangler secret put RESEND_API_KEY
```

#### 5. 构建和部署

```bash
# 构建项目
pnpm build

# 部署到 Cloudflare
pnpm deploy

# 或使用 wrangler
wrangler pages deploy
```

#### 6. 配置自定义域名

1. 在 Cloudflare Dashboard 中进入 Workers & Pages
2. 选择你的项目
3. 点击 "Custom Domains"
4. 添加域名

### Cloudflare D1 部署（cloudflare-d1 分支）

#### 1. 切换分支

```bash
git checkout cloudflare-d1
pnpm install
```

#### 2. 创建 D1 数据库

```bash
# 创建数据库
wrangler d1 create my-database

# 记录数据库 ID
```

#### 3. 配置 wrangler.toml

```toml
[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "your-database-id"
```

#### 4. 运行迁移

```bash
# 生成迁移文件
pnpm db:generate

# 应用迁移到 D1
wrangler d1 migrations apply my-database --remote
```

#### 5. 部署

```bash
pnpm build
pnpm deploy
```

### Cloudflare 特性

#### 1. KV 存储

```typescript
// 存储数据
await env.KV.put('key', 'value', {
  expirationTtl: 3600, // 1小时后过期
});

// 读取数据
const value = await env.KV.get('key');

// 删除数据
await env.KV.delete('key');
```

#### 2. Durable Objects

```typescript
// 定义 Durable Object
export class Counter {
  state: DurableObjectState;
  
  constructor(state: DurableObjectState) {
    this.state = state;
  }
  
  async fetch(request: Request) {
    let count = (await this.state.storage.get('count')) || 0;
    count++;
    await this.state.storage.put('count', count);
    return new Response(count.toString());
  }
}
```

#### 3. R2 存储

```typescript
// 上传文件到 R2
await env.R2.put('file.jpg', fileBuffer, {
  httpMetadata: {
    contentType: 'image/jpeg',
  },
});

// 读取文件
const object = await env.R2.get('file.jpg');
const blob = await object.blob();
```

### 性能优化

#### 1. 缓存策略

```typescript
export default {
  async fetch(request, env, ctx) {
    const cache = caches.default;
    
    // 尝试从缓存获取
    let response = await cache.match(request);
    
    if (!response) {
      // 缓存未命中，生成响应
      response = await generateResponse(request);
      
      // 存入缓存
      ctx.waitUntil(cache.put(request, response.clone()));
    }
    
    return response;
  },
};
```

#### 2. 智能路由

```typescript
// 根据地理位置路由
const country = request.cf?.country;

if (country === 'CN') {
  // 中国用户特殊处理
  return handleChinaRequest(request);
}

return handleDefaultRequest(request);
```

### 监控和日志

#### 1. 实时日志

```bash
# 查看实时日志
wrangler tail
```

#### 2. Analytics

在 Cloudflare Dashboard 查看：
- 请求数量
- 响应时间
- 错误率
- 带宽使用

### 成本对比

#### Cloudflare Workers 免费额度

- 100,000 请求/天
- 10ms CPU 时间/请求
- 无限带宽

#### Cloudflare Workers Paid

- $5/月
- 10,000,000 请求/月
- 50ms CPU 时间/请求

## 方案三：Docker 部署

### 特点

- **完全控制**: 自主管理服务器
- **无冷启动**: 持续运行
- **成本可控**: 固定服务器成本
- **灵活配置**: 自定义环境

### Dockerfile

```dockerfile
# 多阶段构建
FROM node:20-alpine AS base

# 安装依赖
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
COPY source.config.ts ./
COPY content ./content
RUN npm install -g pnpm && pnpm i --frozen-lockfile

# 构建应用
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm install -g pnpm && DOCKER_BUILD=true pnpm build

# 生产镜像
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
RUN mkdir .next
RUN chown nextjs:nodejs .next

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

### 部署步骤

#### 1. 构建镜像

```bash
docker build -t my-app:latest .
```

#### 2. 运行容器

```bash
docker run -d \
  --name my-app \
  -p 3000:3000 \
  --env-file .env \
  my-app:latest
```

#### 3. 使用 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - BETTER_AUTH_SECRET=${BETTER_AUTH_SECRET}
      # ... 其他环境变量
    depends_on:
      - postgres
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=database
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

启动服务：

```bash
docker-compose up -d
```

#### 4. 配置 Nginx 反向代理

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

#### 5. 配置 SSL

```bash
# 使用 Certbot 获取 SSL 证书
sudo certbot --nginx -d yourdomain.com
```

### 自动化部署

#### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Server

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t my-app:latest .
      
      - name: Push to registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push my-app:latest
      
      - name: Deploy to server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            docker pull my-app:latest
            docker-compose up -d
```

## 部署最佳实践

### 1. 环境分离

- **开发环境**: 本地开发
- **预览环境**: PR 自动部署
- **生产环境**: 主分支部署

### 2. 数据库迁移

```bash
# 部署前运行迁移
pnpm db:migrate

# 或在 CI/CD 中自动运行
```

### 3. 健康检查

```typescript
// src/app/api/health/route.ts
export async function GET() {
  try {
    // 检查数据库连接
    await db.select().from(user).limit(1);
    
    return NextResponse.json({ status: 'healthy' });
  } catch (error) {
    return NextResponse.json(
      { status: 'unhealthy', error: error.message },
      { status: 500 }
    );
  }
}
```

### 4. 日志管理

使用日志服务（如 Sentry、LogRocket）:

```typescript
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
});
```

### 5. 备份策略

- 数据库定期备份
- 代码版本控制
- 环境变量备份

## 总结

MkSaaS 支持三种主要部署方式：

1. **Vercel**: 最简单，适合快速上线
2. **Cloudflare Workers**: 高性能，低成本
3. **Docker**: 完全控制，适合自建

选择部署方式时考虑：
- 预算
- 技术能力
- 性能需求
- 扩展性要求

推荐新手使用 Vercel，有经验的开发者可以尝试 Cloudflare Workers 或 Docker 部署。
