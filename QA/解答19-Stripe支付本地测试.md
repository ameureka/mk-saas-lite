# 问题19：支付体系的设计，使用 Stripe 的支付接口打通，使用本地的工具快速响应，以及如何使用

## 概述

MkSaaS 使用 Stripe 作为支付解决方案，提供完整的本地开发和测试环境。通过 Stripe CLI 和测试模式，开发者可以在本地快速测试支付流程，无需部署到生产环境。

## 一、Stripe 本地开发环境

### 1. 安装 Stripe CLI

#### macOS

```bash
# 使用 Homebrew 安装
brew install stripe/stripe-cli/stripe

# 验证安装
stripe --version
```

#### Linux

```bash
# 下载并安装
wget https://github.com/stripe/stripe-cli/releases/latest/download/stripe_linux_x86_64.tar.gz
tar -xvf stripe_linux_x86_64.tar.gz
sudo mv stripe /usr/local/bin/

# 验证安装
stripe --version
```

#### Windows

```powershell
# 使用 Scoop 安装
scoop bucket add stripe https://github.com/stripe/scoop-stripe-cli.git
scoop install stripe

# 验证安装
stripe --version
```

### 2. 登录 Stripe

```bash
# 登录到 Stripe 账户
stripe login

# 这会打开浏览器，授权 CLI 访问你的账户
# 授权后，CLI 会自动配置
```

### 3. 配置测试密钥

```env
# .env.local

# Stripe 测试密钥
STRIPE_SECRET_KEY=sk_test_51xxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxx

# Stripe 公开密钥
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_51xxxxx

# 测试价格 ID
NEXT_PUBLIC_STRIPE_PRICE_PRO_MONTHLY=price_xxxxx
NEXT_PUBLIC_STRIPE_PRICE_PRO_YEARLY=price_xxxxx
NEXT_PUBLIC_STRIPE_PRICE_LIFETIME=price_xxxxx
```

## 二、本地 Webhook 测试

### 1. 启动 Webhook 转发

```bash
# 转发 Stripe Webhook 到本地
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# 输出示例：
# > Ready! Your webhook signing secret is whsec_xxxxx (^C to quit)
# > 2024-11-13 10:00:00   --> charge.succeeded [evt_xxxxx]
# > 2024-11-13 10:00:01   <-- [200] POST http://localhost:3000/api/webhooks/stripe [evt_xxxxx]
```

### 2. 使用特定端口

```bash
# 如果你的应用运行在不同端口
stripe listen --forward-to localhost:3005/api/webhooks/stripe
```

### 3. 过滤特定事件

```bash
# 只监听特定事件
stripe listen \
  --forward-to localhost:3000/api/webhooks/stripe \
  --events checkout.session.completed,customer.subscription.created,invoice.paid
```

### 4. 查看 Webhook 日志

```bash
# 在另一个终端查看详细日志
stripe listen --forward-to localhost:3000/api/webhooks/stripe --print-json
```

## 三、触发测试事件

### 1. 使用 Stripe CLI 触发事件

```bash
# 触发 checkout.session.completed 事件
stripe trigger checkout.session.completed

# 触发 payment_intent.succeeded 事件
stripe trigger payment_intent.succeeded

# 触发 customer.subscription.created 事件
stripe trigger customer.subscription.created

# 触发 invoice.paid 事件
stripe trigger invoice.paid

# 触发 customer.subscription.deleted 事件
stripe trigger customer.subscription.deleted
```

### 2. 自定义事件数据

```bash
# 使用自定义数据触发事件
stripe trigger checkout.session.completed \
  --add checkout_session:metadata.userId=user_123 \
  --add checkout_session:metadata.planId=pro
```

### 3. 查看事件详情

```bash
# 列出最近的事件
stripe events list --limit 10

# 查看特定事件
stripe events retrieve evt_xxxxx
```

## 四、测试支付流程

### 1. 测试卡号

Stripe 提供多种测试卡号用于不同场景：

```typescript
// 测试卡号列表
export const TEST_CARDS = {
  // 成功支付
  success: {
    number: '4242 4242 4242 4242',
    cvc: '任意3位数字',
    date: '任意未来日期',
    description: '支付成功',
  },
  
  // 需要 3D Secure 验证
  secure3D: {
    number: '4000 0027 6000 3184',
    cvc: '任意3位数字',
    date: '任意未来日期',
    description: '需要 3D Secure 验证',
  },
  
  // 余额不足
  insufficientFunds: {
    number: '4000 0000 0000 9995',
    cvc: '任意3位数字',
    date: '任意未来日期',
    description: '余额不足',
  },
  
  // 卡被拒绝
  declined: {
    number: '4000 0000 0000 0002',
    cvc: '任意3位数字',
    date: '任意未来日期',
    description: '卡被拒绝',
  },
  
  // 过期卡
  expired: {
    number: '4000 0000 0000 0069',
    cvc: '任意3位数字',
    date: '任意未来日期',
    description: '过期卡',
  },
  
  // 处理错误
  processingError: {
    number: '4000 0000 0000 0119',
    cvc: '任意3位数字',
    date: '任意未来日期',
    description: '处理错误',
  },
  
  // 不同国家的卡
  countries: {
    us: '4242 4242 4242 4242',
    cn: '6200 0000 0000 0005',
    jp: '3530 1113 3330 0000',
    gb: '4000 0082 6000 0000',
  },
};
```

### 2. 完整测试流程

```bash
# 1. 启动应用
pnpm dev

# 2. 在另一个终端启动 Webhook 转发
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# 3. 在浏览器中测试支付
# - 访问 http://localhost:3000/pricing
# - 选择一个计划
# - 使用测试卡号 4242 4242 4242 4242
# - 完成支付

# 4. 观察 Webhook 事件
# - 在 Stripe CLI 终端查看事件
# - 检查应用日志
# - 验证数据库更新
```

### 3. 测试订阅流程

```typescript
// 测试订阅创建
async function testSubscriptionCreation() {
  // 1. 创建 Checkout Session
  const response = await fetch('/api/create-checkout', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      priceId: 'price_test_xxxxx',
      planId: 'pro',
    }),
  });
  
  const { url } = await response.json();
  
  // 2. 重定向到 Stripe Checkout
  window.location.href = url;
  
  // 3. 使用测试卡完成支付
  // 4. 观察 Webhook 事件
  // 5. 验证订阅创建
}
```

## 五、调试工具

### 1. Stripe Dashboard

访问 [dashboard.stripe.com](https://dashboard.stripe.com) 查看：

- 支付记录
- 客户信息
- 订阅状态
- Webhook 日志
- 事件历史

### 2. 本地日志

```typescript
// src/app/api/webhooks/stripe/route.ts
export async function POST(req: Request) {
  const body = await req.text();
  const signature = req.headers.get('stripe-signature')!;
  
  // 详细日志
  console.log('=== Stripe Webhook ===');
  console.log('Signature:', signature);
  console.log('Body length:', body.length);
  
  try {
    const event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
    
    console.log('Event type:', event.type);
    console.log('Event data:', JSON.stringify(event.data, null, 2));
    
    // 处理事件
    await handleWebhookEvent(event);
    
    console.log('Event processed successfully');
    
    return NextResponse.json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    return NextResponse.json(
      { error: 'Webhook handler failed' },
      { status: 400 }
    );
  }
}
```

### 3. Webhook 测试工具

```typescript
// scripts/test-webhook.ts
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
});

async function testWebhook() {
  // 创建测试 Checkout Session
  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    line_items: [{
      price: 'price_test_xxxxx',
      quantity: 1,
    }],
    success_url: 'http://localhost:3000/success',
    cancel_url: 'http://localhost:3000/cancel',
  });
  
  console.log('Test session created:', session.id);
  console.log('URL:', session.url);
  
  // 模拟 Webhook 事件
  const event = {
    type: 'checkout.session.completed',
    data: {
      object: session,
    },
  };
  
  // 发送到本地 Webhook
  const response = await fetch('http://localhost:3000/api/webhooks/stripe', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'stripe-signature': 'test',
    },
    body: JSON.stringify(event),
  });
  
  console.log('Webhook response:', await response.json());
}

testWebhook();
```

## 六、常见测试场景

### 1. 测试订阅创建

```bash
# 1. 触发 checkout.session.completed
stripe trigger checkout.session.completed

# 2. 触发 customer.subscription.created
stripe trigger customer.subscription.created

# 3. 触发 invoice.paid
stripe trigger invoice.paid

# 4. 验证数据库
# - 检查 payment 表
# - 检查 user 表的 customerId
# - 检查积分是否添加
```

### 2. 测试订阅更新

```bash
# 1. 触发 customer.subscription.updated
stripe trigger customer.subscription.updated

# 2. 验证订阅状态更新
```

### 3. 测试订阅取消

```bash
# 1. 触发 customer.subscription.deleted
stripe trigger customer.subscription.deleted

# 2. 验证订阅状态
# 3. 验证用户权限
```

### 4. 测试支付失败

```bash
# 1. 使用失败的测试卡
# 卡号: 4000 0000 0000 0002

# 2. 触发 invoice.payment_failed
stripe trigger invoice.payment_failed

# 3. 验证错误处理
# 4. 验证用户通知
```

### 5. 测试退款

```bash
# 1. 创建支付
stripe trigger payment_intent.succeeded

# 2. 创建退款
stripe refunds create --charge=ch_xxxxx

# 3. 验证退款处理
```

## 七、自动化测试

### 1. 集成测试

```typescript
// tests/payment.test.ts
import { describe, it, expect, beforeAll } from 'vitest';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
});

describe('Payment Integration', () => {
  let customerId: string;
  
  beforeAll(async () => {
    // 创建测试客户
    const customer = await stripe.customers.create({
      email: 'test@example.com',
      name: 'Test User',
    });
    customerId = customer.id;
  });
  
  it('should create checkout session', async () => {
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: 'subscription',
      line_items: [{
        price: process.env.NEXT_PUBLIC_STRIPE_PRICE_PRO_MONTHLY!,
        quantity: 1,
      }],
      success_url: 'http://localhost:3000/success',
      cancel_url: 'http://localhost:3000/cancel',
    });
    
    expect(session.id).toBeDefined();
    expect(session.url).toBeDefined();
  });
  
  it('should handle webhook event', async () => {
    const response = await fetch('http://localhost:3000/api/webhooks/stripe', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type: 'checkout.session.completed',
        data: {
          object: {
            id: 'cs_test_xxxxx',
            customer: customerId,
          },
        },
      }),
    });
    
    expect(response.status).toBe(200);
  });
});
```

### 2. E2E 测试

```typescript
// tests/e2e/payment.spec.ts
import { test, expect } from '@playwright/test';

test('complete payment flow', async ({ page }) => {
  // 1. 访问价格页面
  await page.goto('http://localhost:3000/pricing');
  
  // 2. 点击订阅按钮
  await page.click('[data-testid="subscribe-pro-monthly"]');
  
  // 3. 等待重定向到 Stripe Checkout
  await page.waitForURL(/checkout\.stripe\.com/);
  
  // 4. 填写测试卡信息
  await page.fill('[name="cardNumber"]', '4242424242424242');
  await page.fill('[name="cardExpiry"]', '12/34');
  await page.fill('[name="cardCvc"]', '123');
  await page.fill('[name="billingName"]', 'Test User');
  
  // 5. 提交支付
  await page.click('[type="submit"]');
  
  // 6. 等待重定向回应用
  await page.waitForURL(/localhost:3000\/payment/);
  
  // 7. 验证支付成功
  await expect(page.locator('[data-testid="payment-success"]')).toBeVisible();
});
```

## 八、最佳实践

### 1. 开发环境

- 始终使用测试密钥
- 使用 Stripe CLI 转发 Webhook
- 记录详细日志
- 使用测试卡号

### 2. 错误处理

- 捕获所有 Stripe 错误
- 提供友好的错误消息
- 记录错误详情
- 实施重试机制

### 3. 安全性

- 验证 Webhook 签名
- 使用 HTTPS
- 不在前端暴露密钥
- 实施幂等性检查

### 4. 监控

- 监控 Webhook 失败
- 追踪支付成功率
- 设置告警
- 定期审查日志

## 总结

MkSaaS 提供了完整的 Stripe 本地测试环境：

1. **Stripe CLI**: 本地 Webhook 转发
2. **测试卡号**: 多种测试场景
3. **事件触发**: 快速测试流程
4. **调试工具**: 详细日志和监控
5. **自动化测试**: 集成和 E2E 测试
6. **最佳实践**: 安全和可靠的实现

通过这些工具，可以在本地快速开发和测试支付功能。
