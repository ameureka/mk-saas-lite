# PPT 语义检索平台方案（10k PPT 规模）

> 本文整合 q1~q8 文档内容，提供一份整体设计说明。详细分项可参考 `/Users/amerlin/Desktop/pachong/docs/ppt_architecture_q*.md`。

## 1. 前置条件
- 已拥有合法的 PPT 数据源，数量级 ~10,000 份（后续可扩展）。
- 每份 PPT 需提取文本并生成结构化摘要 + 标签，最终用于语义检索和推荐。

## 2. 摘要与 Embedding 策略
- **摘要输出结构**：`title`、`summary`（2-3 句）、`sections`、`tags`、`ideal_use_cases`（JSON）。
- **注意事项**：长度控制在 300 字以内、过滤“第一PPT”等品牌字、保存原始 prompt 以便重跑。
- **Embedding 模型**：`text-embedding-3-small`（1536 维，$0.00002/1K tokens，10k PPT 约 $2）；亦可用 DeepSeek/国产模型替代以降低成本。

## 3. 向量数据库与成本
| 方案 | 免费层 | 说明 |
| --- | --- | --- |
| Pinecone Starter | 5M 向量 | 可满足 10k~1M 数据；超出再升级 |
| Qdrant Cloud | 1M 向量 | 免费 tier 足够当前规模 |
| Cloudflare Vectorize | 100k 向量 | 适合边缘部署；付费层 $0.10/百万向量/天 |
| 自建 Milvus | — | 对 10k PPT 可暂不必；若扩展 >100k，建议 4C16G + 200GB SSD 起步 |

向量数据量估算（1536 维、float32）：10k 条 ≈ 60MB（含索引 ~70MB），远低于免费层限制。

## 4. 后端架构（FastAPI + Celery + Redis + Postgres + 向量库）
```mermaid
graph TD
  A[FastAPI / API Gateway] -->|搜索请求| B[Embedding 服务]
  B --> C[向量库 (Pinecone/Qdrant/etc.)]
  C -->|Top-K IDs| A
  A -->|详情| D[PostgreSQL Meta]
  A -->|下载/预览链接| E[对象存储 R2/S3]
  subgraph 异步任务
    F[Celery Worker] -->|解析PPT/摘要| D
    F -->|写入| C
    F -->|上传文件/预览| E
  end
  Redis((Redis)) --> F
  Redis --> A
```
- **FastAPI**：对外搜索、详情、推荐、下载接口。
- **Celery + Redis**：处理 PPT 解析、摘要、embedding、索引导入。
- **PostgreSQL**（Supabase/Neon 免费层）：存 meta（标题、摘要、标签、embedding_id 等）。
- **向量库**：Pinecone/Qdrant/Vectorize 免费层，后期可迁移到自建 Milvus。
- **对象存储**：Cloudflare R2/AWS S3 免费层保存 PPT & 预览图。

## 5. 前端方案
- Next.js + shadcn/Ant Design + Vercel AI SDK。
- 搜索页提供自然语言输入、筛选条件、卡片列表；详情页展示摘要、章节、用途、相似模板；推荐模块结合向量相似 + 行为数据。
- 模板预览：使用预生成图片 / react-ppt-viewer。

## 6. 阶段性策略
1. **MVP（≤10k PPT）**
   - API：FastAPI + Supabase 免费层。
   - 向量库：Pinecone/Qdrant/Vectorize 免费层。
   - 队列：简单线程 / Upstash Redis 免费层。
   - 摘要：规则化或少量 LLM 摘要。
2. **增长阶段（10k~100k）**
   - 引入 Celery + Redis（自建或托管）。
   - 升级 Postgres（Supabase Pro 或自建）、向量库付费层。
   - 深度 LLM 摘要 + 推荐策略，增加日志/统计。
3. **成熟阶段（>100k）**
   - 自建 Milvus + Postgres（4C16G 起），或阿里/腾讯向量数据库。
   - 多索引、多语言、权限/付费体系、推荐模型。

## 7. 成本预估（10k PPT）
| 模块 | 免费层可用？ | 说明 |
| --- | --- | --- |
| API / FastAPI | 是（Vercel/Cloudflare 免费层） | 亦可自建 CVM (~¥1500/年) |
| Postgres | 是（Supabase 500MB） | 10k 数据约 50MB |
| 向量库 | 是（Pinecone/Qdrant/Vectorize） | 10k 向量 ≈ 70MB |
| Redis/Celery | 是（Upstash 10k 请求/天） | 若 QPS 增长再升级 |
| Embedding | 约 $2 （OpenAI small） | DeepSeek 等国产模型可更低 |
| 对象存储 | Cloudflare R2/S3 免费层 | 上传流量有限制，适合 MVP |

**总计**：在当前规模可几乎零成本运行，主要费用是 LLM/embedding 的按量计费。

## 8. 关键监控
- `ppt_meta` 表大小、索引命中率。
- 向量库向量数、延迟、错误率。
- Celery 队列累计任务、失败率。
- LLM token 用量（embedding+摘要）。
- 用户行为（搜索词、下载量、推荐点击）。

## 9. 后续优化
1. 完善摘要 pipeline（含 fallback）。
2. 统一向量检索接口，支持 Pinecone/Milvus/Vectorize 切换。
3. 引入热榜/个性化推荐（协同过滤 + embedding）。
4. 记录授权/版权信息，准备 UGC 或商业合作。
5. 构建运营后台（Ant Design Pro）+ 监控面板。

---
**结论**：以 10k PPT 为起点，采用 FastAPI + Celery + Supabase + 向量库 SaaS 可快速构建语义检索与推荐平台。成本几乎为零，组件均有免费层或开源替代；随着规模增长，再迁移到自建 Milvus/Postgres、国产 embedding、云厂商托管向量库，形成可扩展、合规的 PPT 服务竞品。记得为每份 PPT 保留来源与 embedding 版本，以便未来迭代与合规检查。
