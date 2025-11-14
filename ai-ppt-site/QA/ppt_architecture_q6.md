# 问题 6：后端架构（FastAPI/Celery/Redis/PostgreSQL/Milvus）详解

## 组件职责
| 组件 | 作用 | 说明 |
| --- | --- | --- |
| FastAPI | 提供 REST/WebSocket API | 对外暴露搜索、详情、下载、推荐等接口；也可作为内部服务之间的 API 网关 |
| Celery | 异步任务队列 | 处理耗时任务（PDF/PPT 解析、摘要生成、embedding 计算、批量导入等），避免阻塞 API |
| Redis | Celery broker & 缓存 | 作为 Celery 的消息中间件；同时缓存热门搜索结果、推荐列表、频率限制等 |
| PostgreSQL | 存储元数据（Meta） | 保存 PPT 的标题、摘要、标签、下载地址、embedding_id、权限信息、统计字段等结构化数据 |
| Milvus / 向量库 | 存储向量 | 保存 PPT embedding 向量，用于语义检索/相似推荐；可换成 PGVector、Pinecone、Cloudflare Vectorize 等 |

## Meta 信息示例（PostgreSQL）
```sql
CREATE TABLE ppt_meta (
  id SERIAL PRIMARY KEY,
  title TEXT,
  summary JSONB,
  tags TEXT[],
  category TEXT,
  page_count INT,
  download_url TEXT,
  preview_urls TEXT[],
  embedding_id TEXT,
  embedding_model TEXT,
  provider TEXT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```
- `embedding_id`：对应 Milvus/向量库中的主键。
- `embedding_model`：记录使用的模型，如 `text-embedding-3-small`、`deepseek-embedding`，方便重建。
- `provider`：向量库提供方，便于迁移。

## 向量存储流程
1. Celery 任务解析 PPT → 提取文本 → 调用 GPT/LLM 生成摘要/结构。 
2. Celery 任务调用 Embedding API（OpenAI/DeepSeek/本地模型），生成向量。
3. 将向量写入 Milvus（或 Pinecone 等），返回向量 ID。
4. 将向量 ID、模型版本等写入 PostgreSQL `ppt_meta`。
5. 搜索请求时：FastAPI 接收 query → 调用 Embedding API 生成 query 向量 → 在 Milvus 中检索 top-K → 根据 ID 到 PostgreSQL 获取 meta，组合返回。

## Redis 在架构中的作用
- **Celery Broker/Backend**：负责任务调度、存储任务状态。
- **缓存**：缓存热门搜索的结果、推荐列表、用户会话状态（如最近浏览的模板），减轻数据库压力。
- **限流**：通过 Redis 计数实现 API 调用限速。

## Celery 使用场景
- PPT 解压/解析、图片抽取（IO 密集）。
- 摘要生成/embedding 调用（网络调用 + CPU）。
- 向量库批量导入（Milvus index build 可能耗时）。
- 异步日志收集、行为统计写入（例如用户下载记录）。

## 为什么需要这些组件？
- **FastAPI**：轻量、高性能、与 Python 生态紧密结合，可直接调用 embedding/向量库 SDK。
- **Celery + Redis**：解耦实时接口与离线任务，保证用户请求响应迅速，同时让 embedding 生成、PPT 解析在后台并行运行。
- **PostgreSQL**：关系型数据库便于建立索引与复杂查询（按标签、行业、颜色等维度)，也能和 PGVector 协同。
- **Milvus**：专门解决高维向量检索问题，比关系数据库更适合语义搜索。

## 替代方案（按必要性评估）
- **Celery/Redis**：若初期数据量小，可先用简单队列（如 Python asyncio + SQLite 记录任务）。随着任务量增大再上 Celery。
- **PostgreSQL**：如已有 MySQL/ClickHouse 等，也可存 meta；或使用 Supabase（Postgres 托管）降低运维成本。
- **Milvus**：如果使用 Pinecone、Qdrant SaaS，则内置向量库即服务；PGVector 也可应付 <1M 级数据。
- **FastAPI**：可替换为 Django、Flask、Spring Boot、Rust Axum 等，视团队栈而定。

## 开源 vs 免费服务
| 组件 | 开源 | 免费 SaaS 替代 |
| --- | --- | --- |
| FastAPI | Yes | — |
| Celery/Redis | Yes | 可用云 MQ（如 RabbitMQ Cloud、Upstash Redis 免费层） |
| PostgreSQL | Yes | Supabase / Neon / Railway 等提供免费层 |
| Milvus | Yes | Pinecone/Qdrant/Zilliz Cloud/Cloudflare Vectorize（免费层） |

## 成本概览
- **自建**：CVM（4C16G）≈ 3000-5000 元/年；PostgreSQL 可与业务库合并；Redis 可与 Celery 共用实例。
- **托管**：Supabase 免费层（500MB 数据库，1GB 存储），适合原型；Pinecone/Qdrant 免费层可容纳 1M 以内向量。
- **渐进式策略**：MVP 阶段尽量使用免费 SaaS（Supabase + Pinecone），验证后再迁移到自建 Milvus/PostgreSQL 以降低长期成本。

> 总体而言，该技术栈并非全部强制，可根据阶段性需求拆分。关键在于：有一个可靠的 REST API 层（FastAPI）、有异步能力（Celery/Redis）、有结构化存储（PostgreSQL）与向量检索（Milvus/PGVector/SaaS）。随着业务增长再逐步替换或自建。 

## 数据库 & MQ 规模评估（按 10,000 PPT）
- **PostgreSQL**：每条 meta 记录约 2 KB，10k 条约 20 MB；加索引后约 50 MB。Supabase 免费层（500MB）完全够用；Neon/Railway 免费层也能覆盖。若未来增长，可升级 Pro 或自建。
- **Redis/Celery**：若每日处理 1k 任务，Redis 占用仅数 MB。Upstash 免费层（10k 请求/天）即可满足；生产阶段可按量升级。
- **消息量估算**：每日新增 100 PPT → 100 个 Celery 任务；payload <1 KB → 队列数据 < 100 KB；几乎不占资源。

## Celery 部署与消息格式建议
1. **部署方式**：
   - 使用 Docker Compose：`celery worker -A app.worker --loglevel=info`，与 FastAPI/RabbitMQ/Redis 放在同一 docker network。
   - 生产环境建议至少 2 个 worker（解析/embedding 分开队列），配合 `celery beat` 定时任务（如定期重试失败任务、刷新统计）。
2. **消息格式**：
   - Celery task 参数保持 JSON 可序列化，示例：
     ```python
     task.apply_async(args=[{
         "ppt_id": 123,
         "file_path": "/data/ppts/123.pptx",
         "priority": "high",
         "operations": ["extract", "summarize", "embed"]
     }], queue="ppt_ingest")
     ```
   - 任务状态使用 Celery result backend（Redis/Postgres）记录，包含：`status`、`error_message`、`retry_count`、`completed_at`。
   - 对长流程任务可拆分：`extract_task` → `summarize_task` → `embedding_task`，使用链或 chord 保证顺序。

3. **可靠性措施**：
   - 设置 `acks_late=True`，保证 worker 异常退出时任务重新入队。
   - 使用 `max_retries` 和 `retry_delay` 自动重试第三方 API（如 embedding 服务）。
   - 记录任务日志（PostgreSQL/ClickHouse）用于审计与成本分析。

## SaaS 免费层可行性总结
| 服务 | 免费层能否满足 10,000 PPT？ | 说明 |
| --- | --- | --- |
| Supabase Postgres | 是 | 10k 条数据 < 100MB，免费层足够 |
| Neon/Railway Postgres | 是 | 免费额度 3-5GB，可轻松覆盖 |
| Upstash Redis | 是 | 10k 请求/天免费，足够当前任务量 |
| RabbitMQ Cloud | 是 | 免费层支持 100 连接，适合任务调度 |
| Pinecone/Qdrant/Vectorize | 是 | Pinecone 免费层 5M、Vectorize 100k 向量，完全满足 |

> 结论：初期可以利用 SaaS 免费/低配层快速搭建；当数据规模接近 1M（Postgres 2GB+、向量库 6GB+）时，需考虑升级或自建（如 4C16G Postgres、Milvus 单机）。
