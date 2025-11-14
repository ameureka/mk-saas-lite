# 问题 7：哪些组件是必需的？哪些可选？免费/开源方案综述

## 核心目标
搭建一个“PPT 语义检索 + 推荐 + 下载”平台，需要在不同阶段权衡组件必要性与成本。

## 组件必要性矩阵
| 组件 | MVP 阶段 | 增长阶段 | 说明 |
| --- | --- | --- | --- |
| FastAPI（或任意 API 层） | 必需 | 必需 | 统一对外接口，既可自建也可用 Serverless；关键是有稳定 API 管理层 |
| 向量数据库（Milvus/Pinecone） | 必需 | 必需 | 语义检索核心；MVP 可用 SaaS 免费层，增长后再自建或升级 |
| PostgreSQL（Meta 库） | 必需 | 必需 | 存模板信息、摘要、标签；也可用 Supabase/Railway 免费层 |
| Celery + Redis | 可选 | 推荐 / 必需 | MVP 可用同步任务或简单队列；当解析/embedding 任务多时需引入 Celery |
| LLM 摘要（GPT/DeepSeek） | 可选 | 推荐 | MVP 可使用模板化摘要（标题+目录），之后再接入 LLM 生成结构化摘要提升体验 |
| 对话式搜索（Vercel AI SDK） | 可选 | 可选 | 基本搜索只需向量检索；对话式交互可在后期扩展 |
| 模板预览服务 | 推荐 | 推荐 | 可用静态图片/CDN，无需复杂服务；若需在线编辑/转码可后期引入 |
| 行为统计/推荐权重 | 可选 | 推荐 | 初期可用简单记录；增长阶段接入 ClickHouse/Supabase Analytics 等 |

## 免费/开源方案汇总
| 模块 | 免费 SaaS | 开源/自建 |
| --- | --- | --- |
| API 层 | Vercel Serverless / Cloudflare Workers 免费层 | FastAPI + Uvicorn（Docker 部署） |
| Meta 数据库 | Supabase / Neon / Railway 免费层（500MB-5GB） | PostgreSQL（Docker、自建） |
| 向量库 | Pinecone Starter（5M）、Qdrant Cloud（1M）、Cloudflare Vectorize（100k） | Milvus、PGVector、自建 Qdrant |
| 队列 & 缓存 | Upstash Redis 免费层 / RabbitMQ Cloud | Redis / RabbitMQ 自建 |
| LLM 摘要 | OpenAI 免费额度 / DeepSeek 公测额度 | 自托管 LLM（成本高）、或手写模板摘要 |
| 文件存储 | Cloudflare R2 / AWS S3 免费层 | 本地 NAS / 阿里 OSS（按量计费） |

## 推荐路径
1. **MVP**：
   - API：FastAPI + Supabase/Postgres 免费层。\n   - 向量库：Pinecone/Qdrant/Vectorize 免费层。\n   - 异步任务：先用同步任务或简单线程队列。\n   - 摘要：可采用规则化摘要（标题+目录）或少量手动生成。\n2. **增长阶段**：
   - 引入 Celery + Redis，支持批量解析、重试机制。\n   - 升级数据库/向量库（自建 Milvus + Postgres，或云厂商托管）。\n   - 使用 LLM 摘要 + 语义推荐，提升用户体验。\n   - 引入日志/统计系统（ClickHouse、Supabase Analytics）。\n3. **成熟阶段**：
   - 实现多索引、分级存储（热门/冷门）、多语言支持。\n   - 引入推荐模型（协同过滤 + embedding）及个性化权重。\n   - 结合权限/付费体系，引入用户资产管理。\n\n> 总结：FastAPI + 向量库 + Postgres 是基础三件套；Celery/Redis、LLM 摘要、推荐系统等可按阶段逐步引入。利用免费 SaaS（Supabase、Pinecone、Upstash）可快速搞定 MVP，再视成本/合规需求迁移到自建集群。\n*** End Patch
