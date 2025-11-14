### 1.1 业务背景
基于语义检索的PPT模板分享平台，旨在通过AI技术提升用户查找和获取PPT模板的效率。平台将整合现有的大量PPT资源，通过智能推荐和自然语言搜索，解决传统模板站点"内容多但难找"的痛点。

**核心问题**：
- 用户需要花费大量时间浏览和筛选模板
- 传统关键词搜索无法理解用户真实需求
- 缺少个性化推荐和智能匹配

**解决方案**：
- 使用embedding向量化技术实现语义搜索
- 通过AI自动生成模板摘要和标签
- 建立用户行为驱动的推荐系统

### 1.2 目标用户
- **主要用户**：需要制作PPT的职场人士、教师、学生
- **使用场景**：工作汇报、教学课件、学术答辩、商业提案
- **用户特征**：时间紧迫、对设计要求高、希望快速找到合适模板

### 1.3 核心价值主张
- **懒人式搜索**：一句话描述需求，AI自动匹配最合适的模板
- **智能推荐**：基于语义相似度和用户行为的精准推荐
- **高效获取**：简化下载流程，48小时有效链接，支持积分和广告变现

### 1.4 成功指标
- **MVP阶段**：DAU > 50，搜索准确率 > 70%，下载转化率 > 30%
- **增长阶段**：DAU > 500，月活用户 > 5000，付费转化率 > 5%
- **成熟阶段**：DAU > 2000，年收入 > 50万元，用户留存率 > 40%

---

## 2. 功能需求（按EARS格式）

### 2.1 核心功能列表（按优先级）

#### P0 - MVP必需功能

**需求1：智能语义搜索**
- **用户故事**：作为用户，我希望通过自然语言描述找到合适的PPT模板，以便快速获取符合需求的资源
- **验收标准**：
  1. WHEN User输入自然语言查询，THE Platform SHALL生成查询文本的embedding向量
  2. WHEN Platform接收到查询向量，THE Platform SHALL在Vector_Database中检索相似度最高的前10个Template
  3. THE Platform SHALL在3秒内返回搜索结果
  4. WHEN Platform返回搜索结果，THE Platform SHALL显示每个Template的预览图、标题、摘要和标签

**需求2：模板详情展示**
- **用户故事**：作为用户，我希望查看模板的详细信息，以便判断是否符合我的需求
- **验收标准**：
  1. WHEN User点击搜索结果中的Template，THE Platform SHALL显示Template详情页
  2. THE Platform SHALL在详情页显示模板标题、完整摘要、标签、页数和预览图
  3. THE Platform SHALL在详情页提供下载按钮
  4. THE Platform SHALL在详情页底部推荐3-5个相似Template

**需求3：基础下载功能**
- **用户故事**：作为用户，我希望快速下载所需模板，以便立即使用
- **验收标准**：
  1. WHEN User点击下载按钮，THE Platform SHALL生成有效期为48小时的COS对象存储下载链接
  2. WHEN User首次下载，THE Platform SHALL允许免费下载无需额外验证
  3. THE Platform SHALL记录下载次数到Meta_Database

#### P1 - 增强功能

**需求4：下载权限管理**
- **用户故事**：作为用户，我希望通过简单的验证获取下载链接，以便平台能提供持续服务
- **验收标准**：
  1. WHEN User第二次及以后下载，THE Platform SHALL弹出邮箱验证或积分选择界面
  2. WHEN User选择观看广告，THE Platform SHALL在广告播放完成后生成下载链接
  3. WHEN User选择使用Credits，THE Platform SHALL扣除1个Credit并立即生成下载链接
  4. WHEN下载链接过期，THE Platform SHALL提供重新获取链接的选项

**需求5：用户积分系统**
- **用户故事**：作为用户，我希望通过完成任务获得积分，以便跳过广告直接下载模板
- **验收标准**：
  1. WHEN User注册账户，THE Platform SHALL赠送5个初始Credits
  2. WHEN User每日首次登录，THE Platform SHALL赠送1个Credit
  3. WHEN User分享Template到社交媒体，THE Platform SHALL赠送2个Credits
  4. THE Platform SHALL在用户界面显示当前Credits余额

**需求6：邮箱营销系统**
- **用户故事**：作为Admin，我希望收集用户邮箱并进行营销推送，以便提高用户留存和复访率
- **验收标准**：
  1. WHEN User首次下载Template，THE Platform SHALL要求User输入Email_Verification
  2. THE Platform SHALL验证邮箱格式的有效性
  3. THE Platform SHALL每周向User发送热门模板推荐邮件
  4. WHEN User点击邮件中的链接，THE Platform SHALL自动识别User并跳过邮箱验证

#### P2 - 优化功能

**需求7：模板内容自动处理**
- **用户故事**：作为Admin，我希望系统能自动处理上传的PPT文件，以便建立可搜索的模板库
- **验收标准**：
  1. WHEN Admin上传PPT文件，THE Platform SHALL提取文件中的所有文本内容
  2. THE Platform SHALL生成200-300字的结构化摘要（标题、摘要、章节、标签、使用场景）
  3. THE Platform SHALL调用LLM API生成embedding向量
  4. THE Platform SHALL在30秒内完成单个Template的处理流程

**需求8：SEO和AIO优化**
- **用户故事**：作为平台，我希望被搜索引擎和AI模型索引，以便获取自然流量
- **验收标准**：
  1. THE Platform SHALL为每个Template生成独立的详情页URL
  2. THE Platform SHALL在详情页包含结构化的meta标签和Schema.org标记
  3. THE Platform SHALL生成sitemap.xml并定期更新
  4. THE Platform SHALL使用自然语言描述Template特征

**需求9：性能监控**
- **用户故事**：作为Admin，我希望监控系统性能指标，以便及时发现和解决问题
- **验收标准**：
  1. THE Platform SHALL记录API响应时间、错误率和QPS
  2. THE Platform SHALL监控Vector_Database的查询延迟和向量数量
  3. THE Platform SHALL在指标异常时发送告警通知

---

## 3. 技术架构

### 3.1 技术选型（基于mksaas-template）

#### 复用mksaas-template的核心能力
- **前端框架**：Next.js 15 + React 19
- **UI组件**：shadcn/ui + Radix UI + Tailwind CSS
- **认证系统**：Better Auth（支持邮箱、OAuth）
- **数据库**：PostgreSQL + Drizzle ORM
- **支付系统**：Stripe（用于积分购买）
- **邮件系统**：Resend + React Email（用于邮箱营销）
- **国际化**：next-intl（支持中英文）
- **分析工具**：Vercel Analytics + PostHog + OpenPanel
- **AI集成**：Vercel AI SDK（支持OpenAI、DeepSeek等）

#### 需要新增的技术栈
- **向量数据库**：Pinecone（免费层5M向量）或Qdrant Cloud（免费层1M向量）
- **对象存储**：Cloudflare R2（免费层10GB）或AWS S3
- **异步任务**：Vercel Cron Jobs（MVP阶段）→ Celery + Redis（规模化阶段）
- **PPT解析**：python-pptx（独立服务或Serverless Function）
- **Embedding模型**：OpenAI text-embedding-3-small（$0.00002/1K tokens）

### 3.2 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        用户层                                │
│  Next.js 前端 (搜索页 + 详情页 + 用户中心)                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      API层 (Next.js)                         │
│  /api/search  /api/templates  /api/download  /api/credits   │
└─────────────────────────────────────────────────────────────┘
                            ↓
        ┌──────────────────┴──────────────────┐
        ↓                                      ↓
┌──────────────────┐                  ┌──────────────────┐
│  PostgreSQL      │                  │  Pinecone/Qdrant │
│  (Meta数据)      │                  │  (向量检索)       │
│  - templates     │                  │  - embeddings    │
│  - users         │                  │  - similarity    │
│  - downloads     │                  └──────────────────┘
│  - credits       │
└──────────────────┘
        ↓
┌──────────────────┐
│  Cloudflare R2   │
│  (PPT文件存储)   │
│  - 原始PPT       │
│  - 预览图        │
└──────────────────┘
        ↓
┌──────────────────┐
│  异步任务队列     │
│  - PPT解析       │
│  - Embedding生成 │
│  - 邮件发送      │
└──────────────────┘
```

### 3.3 数据模型设计（Drizzle Schema）

```typescript
// src/db/schema/templates.ts
export const templates = pgTable('templates', {
  id: uuid('id').primaryKey().defaultRandom(),
  title: text('title').notNull(),
  summary: jsonb('summary').$type<{
    description: string;
    sections: string[];
    tags: string[];
    use_cases: string[];
  }>(),
  embeddingId: text('embedding_id'), // Pinecone向量ID
  embeddingModel: text('embedding_model').default('text-embedding-3-small'),
  downloadUrl: text('download_url').notNull(), // R2/S3链接
  previewUrls: text('preview_urls').array(),
  category: text('category'), // 商务/教育/医疗等
  tags: text('tags').array(),
  pageCount: integer('page_count'),
  downloadCount: integer('download_count').default(0),
  viewCount: integer('view_count').default(0),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// src/db/schema/users.ts (扩展Better Auth)
export const users = pgTable('users', {
  // Better Auth已有字段：id, email, name, image
  credits: integer('credits').default(5), // 积分余额
  totalDownloads: integer('total_downloads').default(0),
  lastLoginAt: timestamp('last_login_at'),
});

// src/db/schema/downloads.ts
export const downloads = pgTable('downloads', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').references(() => users.id),
  templateId: uuid('template_id').references(() => templates.id),
  downloadLink: text('download_link'), // 临时链接
  expiresAt: timestamp('expires_at'), // 48小时后过期
  method: text('method'), // 'ad' | 'credits' | 'free'
  createdAt: timestamp('created_at').defaultNow(),
});

// src/db/schema/credits-transactions.ts
export const creditsTransactions = pgTable('credits_transactions', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').references(() => users.id),
  amount: integer('amount'), // 正数=获得，负数=消耗
  type: text('type'), // 'signup' | 'daily' | 'share' | 'comment' | 'purchase' | 'download'
  description: text('description'),
  createdAt: timestamp('created_at').defaultNow(),
});
```

### 3.4 API设计

#### 搜索API
```typescript
// POST /api/search
Request: {
  query: string; // "我需要一个关于新能源的商务汇报PPT"
  limit?: number; // 默认10
  category?: string;
  tags?: string[];
}

Response: {
  results: Array<{
    id: string;
    title: string;
    summary: string;
    tags: string[];
    previewUrl: string;
    similarity: number; // 0-1相似度
  }>;
  total: number;
}
```

#### 下载API
```typescript
// POST /api/download
Request: {
  templateId: string;
  method: 'free' | 'ad' | 'credits';
}

Response: {
  downloadLink: string; // 48小时有效
  expiresAt: string;
  creditsRemaining?: number;
}
```

---

## 4. 非功能性需求

### 4.1 性能要求
- **搜索响应时间**：< 3秒（包含embedding生成 + 向量检索）
- **页面加载时间**：< 2秒（首屏）
- **并发支持**：> 1000 QPS（通过Vercel Edge Network）
- **向量检索延迟**：< 100ms（Pinecone/Qdrant保证）

### 4.2 安全要求
- **下载链接**：48小时过期，签名验证防止盗链
- **邮箱验证**：防止机器人批量注册和下载
- **API限流**：100次/分钟/IP（使用Vercel Edge Config）
- **数据加密**：敏感信息（邮箱、支付）使用AES-256加密

### 4.3 可观测性
- **错误监控**：Sentry集成（捕获前后端错误）
- **用户行为**：PostHog追踪（搜索词、点击、下载）
- **性能监控**：Vercel Analytics（Core Web Vitals）
- **业务指标**：自定义Dashboard（DAU、转化率、收入）

### 4.4 SEO/AIO优化
- **独立URL**：每个模板 `/templates/[id]`
- **Meta标签**：动态生成title、description、og:image
- **Schema.org**：CreativeWork结构化数据
- **Sitemap**：自动生成并提交到搜索引擎
- **RSS Feed**：供AI模型抓取

---

## 5. 实施计划（分阶段）

### 阶段0：MVP验证（1-2周）
**目标**：验证核心假设，快速上线获取用户反馈

**功能清单**：
- [x] 基于mksaas-template初始化项目
- [ ] 实现基础搜索页（关键词匹配，暂不用向量）
- [ ] 实现模板详情页（展示预览图、标题、标签）
- [ ] 实现简单下载功能（直接生成R2链接）
- [ ] 部署到Vercel（使用免费层）
- [ ] 手动导入100个模板数据

**验收标准**：
- 用户能搜索、查看、下载模板
- 页面加载速度 < 3秒
- 无严重bug，基本可用

**技术栈**：
- Next.js + PostgreSQL（Supabase免费层）
- Cloudflare R2（免费10GB）
- 无向量检索（使用PostgreSQL全文搜索）

---

### 阶段1：智能化升级（2-3周）
**目标**：引入AI语义搜索，提升搜索准确率

**功能清单**：
- [ ] 集成OpenAI Embedding API
- [ ] 接入Pinecone向量数据库（免费层）
- [ ] 实现自然语言搜索
- [ ] 批量处理现有模板生成embedding
- [ ] 优化搜索结果排序（相似度 + 热度）
- [ ] 添加"相似推荐"功能

**验收标准**：
- 搜索准确率 > 80%（人工评测）
- 向量检索延迟 < 200ms
- 支持1000+模板的语义搜索

**技术栈**：
- OpenAI text-embedding-3-small
- Pinecone免费层（5M向量）
- Vercel Serverless Functions（处理embedding）

---

### 阶段2：商业化闭环（2周）
**目标**：建立收益模式，实现自我造血

**功能清单**：
- [ ] 实现用户注册/登录（Better Auth）
- [ ] 实现积分系统（签到、分享、评论）
- [ ] 集成广告SDK（百度联盟或Google AdSense）
- [ ] 实现邮箱验证下载
- [ ] 实现邮件营销（Resend + 定时任务）
- [ ] 添加Stripe支付（购买积分）

**验收标准**：
- DAU > 100
- 下载转化率 > 30%
- 广告收益 > ¥500/月
- 邮件打开率 > 20%

**技术栈**：
- Better Auth（邮箱+OAuth）
- Stripe（支付）
- Resend（邮件）
- Vercel Cron Jobs（定时任务）

---

### 阶段3：规模化优化（持续迭代）
**目标**：支持更大规模，优化成本和性能

**功能清单**：
- [ ] 迁移到自建Milvus（降低向量库成本）
- [ ] 实现异步任务队列（Celery + Redis）
- [ ] 添加CDN加速（Cloudflare）
- [ ] 实现A/B测试框架
- [ ] 优化数据库查询（索引、缓存）
- [ ] 添加管理后台（模板管理、用户管理）

**验收标准**：
- 支持10万+模板
- DAU > 2000
- 月收入 > ¥10,000
- 系统可用性 > 99.9%

---

## 6. 风险管理

### 6.1 技术风险

| 风险 | 影响 | 概率 | 应对策略 |
|------|------|------|----------|
| 向量数据库成本超预算 | 高 | 中 | 初期使用免费层，超出后迁移到自建Milvus |
| LLM API限流 | 中 | 高 | 实现请求队列和重试机制，考虑使用DeepSeek降低成本 |
| 存储成本过高 | 中 | 中 | 压缩预览图，使用CDN缓存，按需加载 |
| PPT解析失败率高 | 中 | 中 | 实现fallback机制，手动标注失败案例 |

### 6.2 业务风险

| 风险 | 影响 | 概率 | 应对策略 |
|------|------|------|----------|
| 内容版权问题 | 高 | 中 | 记录PPT来源，建立授权机制，提供DMCA下架流程 |
| 用户增长慢 | 高 | 高 | SEO优化，社交媒体推广，内容营销 |
| 变现困难 | 高 | 中 | 多元化收入（广告+会员+B2B），测试不同定价策略 |
| 竞品压力 | 中 | 高 | 差异化定位（AI智能推荐），提升用户体验 |

### 6.3 应对策略
- **技术债务管理**：每个阶段预留20%时间重构和优化
- **成本控制**：设置预算告警，超出阈值自动降级服务
- **用户反馈**：建立反馈渠道（Discord、邮件），快速迭代
- **数据备份**：每日自动备份数据库和向量库

---

## 7. 成本预估

### 7.1 开发成本（MVP阶段）
- **人力成本**：1人 × 4周 = 4人周
- **第三方服务**：
  - Vercel：免费层
  - Supabase PostgreSQL：免费层（500MB）
  - Pinecone：免费层（5M向量）
  - Cloudflare R2：免费层（10GB）
  - OpenAI Embedding：约$2（1万条）
- **总计**：< ¥100（主要是API费用）

### 7.2 运营成本（月度，增长阶段）
- **服务器**：Vercel Pro $20/月
- **数据库**：Supabase Pro $25/月
- **向量库**：Pinecone Starter $70/月（超出免费层）
- **存储**：Cloudflare R2 $5/月（100GB）
- **AI API**：OpenAI $50/月（embedding + 摘要）
- **邮件**：Resend $20/月（5万封）
- **总计**：约$190/月（¥1,400/月）

### 7.3 ROI分析
- **收入预测**（增长阶段）：
  - 广告收入：¥3,000/月（300万PV × ¥1/千PV）
  - 积分购买：¥2,000/月（100人 × ¥20）
  - 会员订阅：¥1,000/月（50人 × ¥20）
  - **总计**：¥6,000/月
- **利润**：¥6,000 - ¥1,400 = ¥4,600/月
- **回本周期**：< 1个月（MVP成本极低）

---

## 8. 附录

### 8.1 参考资料
- mksaas-template文档：https://mksaas.com/docs
- Pinecone文档：https://docs.pinecone.io
- OpenAI Embedding指南：https://platform.openai.com/docs/guides/embeddings
- Drizzle ORM文档：https://orm.drizzle.team

### 8.2 竞品分析
- **第一PPT**（1ppt.com）：月访问52万，主要靠SEO和直接访问，广告变现
- **包图网**（ibaotu.com）：会员制，内容更丰富，但搜索体验一般
- **Canva**：在线编辑，国际化，但中文模板较少

**差异化优势**：
- AI语义搜索（竞品都是关键词匹配）
- 懒人式推荐（一句话找到模板）
- 轻量化（无需注册即可搜索）

### 8.3 技术调研
- **向量数据库对比**：Pinecone vs Qdrant vs Milvus
  - MVP选择：Pinecone（免费层足够，无需运维）
  - 规模化选择：自建Milvus（成本更低，可控性强）
- **Embedding模型对比**：OpenAI vs DeepSeek vs 本地模型
  - MVP选择：OpenAI text-embedding-3-small（质量好，成本低）
  - 优化方向：DeepSeek（国内访问快，成本更低）

---

## 9. 下一步行动

### 立即执行（本周）
1. [ ] 基于mksaas-template创建新项目
2. [ ] 设计数据库schema并执行迁移
3. [ ] 实现搜索页和详情页UI
4. [ ] 准备100个测试模板数据

### 短期目标（2周内）
1. [ ] 完成MVP功能开发
2. [ ] 部署到Vercel
3. [ ] 邀请10个种子用户测试
4. [ ] 收集反馈并快速迭代

### 中期目标（1个月内）
1. [ ] 集成AI语义搜索
2. [ ] 实现商业化功能
3. [ ] 达到DAU 100+
4. [ ] 实现正向现金流

---

**文档版本**：v0.2  
**最后更新**：2025-01-XX  
**负责人**：[Your Name]  
**审核人**：待定
