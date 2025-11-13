# 问题14：关于使用后端的 API 以及大模型的管理有没有详细的权限以及使用的控制

## 概述

MkSaaS 实现了完善的权限管理系统，包括用户认证、角色权限、API 访问控制、大模型使用限制和积分消费管理。系统通过多层安全机制确保资源的合理使用。

## 一、认证与授权架构

### 1. 认证层级

```
认证层级:

Level 1: 公开访问
├── 营销页面
├── 博客文章
├── 文档
└── 登录/注册页面

Level 2: 已登录用户
├── 仪表板
├── 个人设置
├── 基础功能
└── 免费计划功能

Level 3: 付费用户
├── 高级功能
├── AI 功能
├── 更多积分
└── 优先支持

Level 4: 管理员
├── 用户管理
├── 系统配置
├── 数据管理
└── 监控面板
```

### 2. Better Auth 权限系统

#### 用户角色定义

```typescript
// src/db/schema.ts
export const user = pgTable("user", {
  id: text("id").primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  role: text('role'),  // 'admin' | 'user' | null
  banned: boolean('banned'),
  banReason: text('ban_reason'),
  banExpires: timestamp('ban_expires'),
  // ...
});
```

#### 角色检查

```typescript
// src/lib/auth-utils.ts
export function isAdmin(user: User): boolean {
  return user.role === 'admin';
}

export function isUser(user: User): boolean {
  return user.role === 'user' || user.role === null;
}

export function isBanned(user: User): boolean {
  if (!user.banned) return false;
  
  // 检查封禁是否过期
  if (user.banExpires && new Date(user.banExpires) < new Date()) {
    return false;
  }
  
  return true;
}
```

## 二、API 权限控制

### 1. Server Actions 权限

#### 安全的 Action 客户端

```typescript
// src/lib/safe-action.ts
import { createSafeActionClient } from 'next-safe-action';
import { getSession } from './auth';

// 公开 Action（无需登录）
export const publicActionClient = createSafeActionClient({
  handleReturnedServerError(e) {
    return {
      serverError: 'An error occurred',
    };
  },
});

// 需要登录的 Action
export const userActionClient = createSafeActionClient({
  async middleware() {
    const session = await getSession();
    
    if (!session) {
      throw new Error('Unauthorized');
    }
    
    // 检查用户是否被封禁
    if (isBanned(session.user)) {
      throw new Error('User is banned');
    }
    
    return {
      user: session.user,
    };
  },
  handleReturnedServerError(e) {
    return {
      serverError: e.message,
    };
  },
});

// 需要管理员权限的 Action
export const adminActionClient = createSafeActionClient({
  async middleware() {
    const session = await getSession();
    
    if (!session) {
      throw new Error('Unauthorized');
    }
    
    if (!isAdmin(session.user)) {
      throw new Error('Forbidden: Admin access required');
    }
    
    return {
      user: session.user,
    };
  },
  handleReturnedServerError(e) {
    return {
      serverError: e.message,
    };
  },
});
```

#### 使用示例

```typescript
// src/actions/my-action.ts
'use server';

import { userActionClient, adminActionClient } from '@/lib/safe-action';
import { z } from 'zod';

// 普通用户 Action
const userSchema = z.object({
  name: z.string(),
});

export const updateProfileAction = userActionClient
  .schema(userSchema)
  .action(async ({ parsedInput, ctx }) => {
    // ctx.user 包含当前用户信息
    const userId = ctx.user.id;
    
    // 执行操作
    await db.update(user)
      .set({ name: parsedInput.name })
      .where(eq(user.id, userId));
    
    return {
      success: true,
    };
  });

// 管理员 Action
const adminSchema = z.object({
  userId: z.string(),
  banned: z.boolean(),
});

export const banUserAction = adminActionClient
  .schema(adminSchema)
  .action(async ({ parsedInput, ctx }) => {
    // 只有管理员可以执行
    await db.update(user)
      .set({ 
        banned: parsedInput.banned,
        banReason: 'Violation of terms',
      })
      .where(eq(user.id, parsedInput.userId));
    
    return {
      success: true,
    };
  });
```

### 2. API Routes 权限

#### 权限中间件

```typescript
// src/lib/api-middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { getSession } from './auth';

export async function requireAuth(req: NextRequest) {
  const session = await getSession();
  
  if (!session) {
    return NextResponse.json(
      { error: 'Unauthorized' },
      { status: 401 }
    );
  }
  
  if (isBanned(session.user)) {
    return NextResponse.json(
      { error: 'User is banned' },
      { status: 403 }
    );
  }
  
  return session;
}

export async function requireAdmin(req: NextRequest) {
  const session = await requireAuth(req);
  
  if (session instanceof NextResponse) {
    return session; // 返回错误响应
  }
  
  if (!isAdmin(session.user)) {
    return NextResponse.json(
      { error: 'Forbidden: Admin access required' },
      { status: 403 }
    );
  }
  
  return session;
}
```

#### API 路由使用

```typescript
// src/app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/api-middleware';
import { db } from '@/db';
import { user } from '@/db/schema';

export async function GET(req: NextRequest) {
  // 检查管理员权限
  const session = await requireAdmin(req);
  
  if (session instanceof NextResponse) {
    return session; // 返回错误响应
  }
  
  // 获取所有用户
  const users = await db.select().from(user);
  
  return NextResponse.json({
    success: true,
    data: users,
  });
}
```

### 3. 路由级别权限

#### Middleware 保护

```typescript
// src/middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { getSession } from './lib/auth';

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  
  // 获取 session
  const session = await getSession();
  const isLoggedIn = !!session;
  
  // 管理员路由保护
  if (pathname.startsWith('/admin')) {
    if (!isLoggedIn) {
      return NextResponse.redirect(new URL('/auth/login', req.url));
    }
    
    if (!isAdmin(session.user)) {
      return NextResponse.redirect(new URL('/dashboard', req.url));
    }
  }
  
  // 受保护路由
  const protectedRoutes = ['/dashboard', '/settings', '/ai'];
  const isProtectedRoute = protectedRoutes.some(route => 
    pathname.startsWith(route)
  );
  
  if (isProtectedRoute && !isLoggedIn) {
    return NextResponse.redirect(new URL('/auth/login', req.url));
  }
  
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next|_vercel|.*\\..*).*)'],
};
```

## 三、大模型权限管理

### 1. 模型访问控制

#### 模型权限配置

```typescript
// src/config/ai-models.ts
export interface ModelConfig {
  id: string;
  name: string;
  provider: string;
  requiredPlan: 'free' | 'pro' | 'lifetime';
  costPerRequest: number;  // 积分消耗
  rateLimit: {
    requests: number;
    window: number;  // 秒
  };
}

export const modelConfigs: Record<string, ModelConfig> = {
  'gpt-3.5-turbo': {
    id: 'gpt-3.5-turbo',
    name: 'GPT-3.5 Turbo',
    provider: 'openai',
    requiredPlan: 'free',
    costPerRequest: 1,
    rateLimit: {
      requests: 10,
      window: 60,
    },
  },
  'gpt-4-turbo': {
    id: 'gpt-4-turbo',
    name: 'GPT-4 Turbo',
    provider: 'openai',
    requiredPlan: 'pro',
    costPerRequest: 10,
    rateLimit: {
      requests: 20,
      window: 60,
    },
  },
  'gpt-4': {
    id: 'gpt-4',
    name: 'GPT-4',
    provider: 'openai',
    requiredPlan: 'pro',
    costPerRequest: 20,
    rateLimit: {
      requests: 10,
      window: 60,
    },
  },
  'claude-3-opus': {
    id: 'claude-3-opus',
    name: 'Claude 3 Opus',
    provider: 'anthropic',
    requiredPlan: 'lifetime',
    costPerRequest: 15,
    rateLimit: {
      requests: 15,
      window: 60,
    },
  },
};
```

#### 模型访问检查

```typescript
// src/lib/ai/model-access.ts
import { modelConfigs } from '@/config/ai-models';
import { getCurrentPlan } from '@/lib/price-plan';
import { getCreditBalance } from '@/credits/server';

export async function checkModelAccess(
  userId: string,
  modelId: string
): Promise<{
  allowed: boolean;
  reason?: string;
}> {
  const modelConfig = modelConfigs[modelId];
  
  if (!modelConfig) {
    return {
      allowed: false,
      reason: 'Model not found',
    };
  }
  
  // 检查用户计划
  const currentPlan = await getCurrentPlan(userId);
  const planHierarchy = ['free', 'pro', 'lifetime'];
  const userPlanLevel = planHierarchy.indexOf(currentPlan.id);
  const requiredPlanLevel = planHierarchy.indexOf(modelConfig.requiredPlan);
  
  if (userPlanLevel < requiredPlanLevel) {
    return {
      allowed: false,
      reason: `This model requires ${modelConfig.requiredPlan} plan`,
    };
  }
  
  // 检查积分余额
  const balance = await getCreditBalance(userId);
  
  if (balance < modelConfig.costPerRequest) {
    return {
      allowed: false,
      reason: 'Insufficient credits',
    };
  }
  
  // 检查速率限制
  const rateLimitOk = await checkRateLimit(
    userId,
    modelId,
    modelConfig.rateLimit
  );
  
  if (!rateLimitOk) {
    return {
      allowed: false,
      reason: 'Rate limit exceeded',
    };
  }
  
  return {
    allowed: true,
  };
}
```

### 2. 速率限制

#### Redis 速率限制

```typescript
// src/lib/rate-limit.ts
import { Redis } from '@upstash/redis';

const redis = Redis.fromEnv();

export async function checkRateLimit(
  userId: string,
  resource: string,
  limit: { requests: number; window: number }
): Promise<boolean> {
  const key = `ratelimit:${userId}:${resource}`;
  
  // 获取当前计数
  const current = await redis.incr(key);
  
  // 第一次请求，设置过期时间
  if (current === 1) {
    await redis.expire(key, limit.window);
  }
  
  // 检查是否超过限制
  return current <= limit.requests;
}

// 获取剩余配额
export async function getRateLimitStatus(
  userId: string,
  resource: string,
  limit: { requests: number; window: number }
): Promise<{
  remaining: number;
  resetAt: number;
}> {
  const key = `ratelimit:${userId}:${resource}`;
  
  const [current, ttl] = await Promise.all([
    redis.get(key),
    redis.ttl(key),
  ]);
  
  const used = current ? parseInt(current as string) : 0;
  const remaining = Math.max(0, limit.requests - used);
  const resetAt = Date.now() + (ttl > 0 ? ttl * 1000 : 0);
  
  return {
    remaining,
    resetAt,
  };
}
```

#### 使用速率限制

```typescript
// src/app/api/ai/chat/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/api-middleware';
import { checkRateLimit } from '@/lib/rate-limit';
import { modelConfigs } from '@/config/ai-models';

export async function POST(req: NextRequest) {
  const session = await requireAuth(req);
  
  if (session instanceof NextResponse) {
    return session;
  }
  
  const { model, messages } = await req.json();
  const modelConfig = modelConfigs[model];
  
  // 检查速率限制
  const rateLimitOk = await checkRateLimit(
    session.user.id,
    `ai:${model}`,
    modelConfig.rateLimit
  );
  
  if (!rateLimitOk) {
    return NextResponse.json(
      { 
        error: 'Rate limit exceeded',
        retryAfter: modelConfig.rateLimit.window,
      },
      { 
        status: 429,
        headers: {
          'Retry-After': modelConfig.rateLimit.window.toString(),
        },
      }
    );
  }
  
  // 继续处理请求
  // ...
}
```

### 3. 积分消费控制

#### 预检查积分

```typescript
// src/lib/ai/credit-check.ts
import { getCreditBalance } from '@/credits/server';
import { consumeCredits } from '@/credits/credits';
import { modelConfigs } from '@/config/ai-models';

export async function consumeModelCredits(
  userId: string,
  modelId: string,
  description: string
): Promise<{
  success: boolean;
  error?: string;
}> {
  const modelConfig = modelConfigs[modelId];
  const cost = modelConfig.costPerRequest;
  
  // 检查余额
  const balance = await getCreditBalance(userId);
  
  if (balance < cost) {
    return {
      success: false,
      error: `Insufficient credits. Required: ${cost}, Available: ${balance}`,
    };
  }
  
  // 消费积分
  try {
    await consumeCredits({
      userId,
      amount: cost,
      description: `${description} (${modelConfig.name})`,
    });
    
    return {
      success: true,
    };
  } catch (error) {
    return {
      success: false,
      error: 'Failed to consume credits',
    };
  }
}
```

#### AI API 集成积分

```typescript
// src/app/api/ai/generate/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/api-middleware';
import { checkModelAccess } from '@/lib/ai/model-access';
import { consumeModelCredits } from '@/lib/ai/credit-check';
import { generateText } from 'ai';
import { openai } from '@ai-sdk/openai';

export async function POST(req: NextRequest) {
  const session = await requireAuth(req);
  
  if (session instanceof NextResponse) {
    return session;
  }
  
  const { model, prompt } = await req.json();
  
  // 1. 检查模型访问权限
  const accessCheck = await checkModelAccess(session.user.id, model);
  
  if (!accessCheck.allowed) {
    return NextResponse.json(
      { error: accessCheck.reason },
      { status: 403 }
    );
  }
  
  // 2. 消费积分
  const creditResult = await consumeModelCredits(
    session.user.id,
    model,
    'AI Text Generation'
  );
  
  if (!creditResult.success) {
    return NextResponse.json(
      { error: creditResult.error },
      { status: 402 }
    );
  }
  
  // 3. 调用 AI 模型
  try {
    const { text } = await generateText({
      model: openai(model),
      prompt,
    });
    
    return NextResponse.json({
      success: true,
      text,
    });
  } catch (error) {
    // 如果 AI 调用失败，退还积分
    await refundCredits(session.user.id, modelConfigs[model].costPerRequest);
    
    return NextResponse.json(
      { error: 'AI generation failed' },
      { status: 500 }
    );
  }
}
```

## 四、API 密钥管理

### 1. 用户 API 密钥

#### 数据库 Schema

```typescript
// src/db/schema.ts
export const apiKey = pgTable("api_key", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().references(() => user.id),
  name: text("name").notNull(),
  key: text("key").notNull().unique(),
  lastUsedAt: timestamp("last_used_at"),
  expiresAt: timestamp("expires_at"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => ({
  userIdIdx: index("api_key_user_id_idx").on(table.userId),
  keyIdx: index("api_key_key_idx").on(table.key),
}));
```

#### 生成 API 密钥

```typescript
// src/actions/create-api-key.ts
'use server';

import { userActionClient } from '@/lib/safe-action';
import { z } from 'zod';
import { db } from '@/db';
import { apiKey } from '@/db/schema';
import { nanoid } from 'nanoid';
import crypto from 'crypto';

const schema = z.object({
  name: z.string().min(1).max(100),
  expiresInDays: z.number().optional(),
});

export const createApiKeyAction = userActionClient
  .schema(schema)
  .action(async ({ parsedInput, ctx }) => {
    // 生成安全的 API 密钥
    const key = `mk_${crypto.randomBytes(32).toString('hex')}`;
    
    const expiresAt = parsedInput.expiresInDays
      ? new Date(Date.now() + parsedInput.expiresInDays * 24 * 60 * 60 * 1000)
      : null;
    
    const newKey = await db.insert(apiKey).values({
      id: nanoid(),
      userId: ctx.user.id,
      name: parsedInput.name,
      key,
      expiresAt,
      createdAt: new Date(),
    }).returning();
    
    return {
      success: true,
      data: newKey[0],
    };
  });
```

#### 验证 API 密钥

```typescript
// src/lib/api-key-auth.ts
import { db } from '@/db';
import { apiKey, user } from '@/db/schema';
import { eq, and, gt, or, isNull } from 'drizzle-orm';

export async function validateApiKey(key: string): Promise<{
  valid: boolean;
  userId?: string;
  error?: string;
}> {
  if (!key || !key.startsWith('mk_')) {
    return {
      valid: false,
      error: 'Invalid API key format',
    };
  }
  
  const result = await db
    .select({
      apiKey: apiKey,
      user: user,
    })
    .from(apiKey)
    .innerJoin(user, eq(apiKey.userId, user.id))
    .where(
      and(
        eq(apiKey.key, key),
        or(
          isNull(apiKey.expiresAt),
          gt(apiKey.expiresAt, new Date())
        )
      )
    )
    .limit(1);
  
  if (result.length === 0) {
    return {
      valid: false,
      error: 'Invalid or expired API key',
    };
  }
  
  const { apiKey: keyData, user: userData } = result[0];
  
  // 检查用户是否被封禁
  if (isBanned(userData)) {
    return {
      valid: false,
      error: 'User is banned',
    };
  }
  
  // 更新最后使用时间
  await db
    .update(apiKey)
    .set({ lastUsedAt: new Date() })
    .where(eq(apiKey.id, keyData.id));
  
  return {
    valid: true,
    userId: userData.id,
  };
}
```

#### API 密钥认证中间件

```typescript
// src/lib/api-key-middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { validateApiKey } from './api-key-auth';

export async function requireApiKey(req: NextRequest) {
  const apiKey = req.headers.get('x-api-key') || 
                 req.headers.get('authorization')?.replace('Bearer ', '');
  
  if (!apiKey) {
    return NextResponse.json(
      { error: 'API key required' },
      { status: 401 }
    );
  }
  
  const validation = await validateApiKey(apiKey);
  
  if (!validation.valid) {
    return NextResponse.json(
      { error: validation.error },
      { status: 401 }
    );
  }
  
  return validation.userId;
}
```

#### 使用 API 密钥

```typescript
// src/app/api/v1/generate/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { requireApiKey } from '@/lib/api-key-middleware';

export async function POST(req: NextRequest) {
  // 验证 API 密钥
  const userId = await requireApiKey(req);
  
  if (userId instanceof NextResponse) {
    return userId; // 返回错误响应
  }
  
  // 继续处理请求
  const { prompt } = await req.json();
  
  // ... AI 生成逻辑
  
  return NextResponse.json({
    success: true,
    result: '...',
  });
}
```

## 五、审计日志

### 1. 记录 API 使用

```typescript
// src/lib/audit-log.ts
import { db } from '@/db';
import { auditLog } from '@/db/schema';
import { nanoid } from 'nanoid';

export async function logApiUsage(data: {
  userId: string;
  action: string;
  resource: string;
  metadata?: Record<string, any>;
  ipAddress?: string;
  userAgent?: string;
}) {
  await db.insert(auditLog).values({
    id: nanoid(),
    userId: data.userId,
    action: data.action,
    resource: data.resource,
    metadata: data.metadata,
    ipAddress: data.ipAddress,
    userAgent: data.userAgent,
    createdAt: new Date(),
  });
}
```

### 2. 查询审计日志

```typescript
// src/actions/get-audit-logs.ts
'use server';

import { adminActionClient } from '@/lib/safe-action';
import { z } from 'zod';
import { db } from '@/db';
import { auditLog } from '@/db/schema';
import { eq, desc } from 'drizzle-orm';

const schema = z.object({
  userId: z.string().optional(),
  limit: z.number().default(50),
});

export const getAuditLogsAction = adminActionClient
  .schema(schema)
  .action(async ({ parsedInput }) => {
    const query = db
      .select()
      .from(auditLog)
      .orderBy(desc(auditLog.createdAt))
      .limit(parsedInput.limit);
    
    if (parsedInput.userId) {
      query.where(eq(auditLog.userId, parsedInput.userId));
    }
    
    const logs = await query;
    
    return {
      success: true,
      data: logs,
    };
  });
```

## 六、最佳实践

### 1. 安全建议

- 始终验证用户身份
- 使用最小权限原则
- 记录所有敏感操作
- 定期审查权限配置
- 实施速率限制
- 加密敏感数据

### 2. 性能优化

- 缓存权限检查结果
- 使用索引优化查询
- 批量处理权限验证
- 异步记录审计日志

### 3. 监控告警

- 监控异常访问模式
- 追踪 API 使用量
- 设置速率限制告警
- 记录失败的认证尝试

## 总结

MkSaaS 提供了完整的权限管理系统：

1. **多层认证**: 公开、用户、付费、管理员
2. **API 保护**: Server Actions 和 API Routes 权限控制
3. **模型访问**: 基于计划和积分的模型访问控制
4. **速率限制**: 防止滥用和过度使用
5. **积分管理**: 精确的使用量控制
6. **API 密钥**: 支持程序化访问
7. **审计日志**: 完整的操作记录

通过这些机制，确保系统资源的安全和合理使用。
