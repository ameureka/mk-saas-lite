# 最终方案总结（10,000 PPT 规模）

## 1.总体架构
- **前端**：Next.js + shadcn/AntD + Vercel AI SDK（可部署在 Vercel/Cloudflare）。
- **API 层**：FastAPI（或 Serverless 函数），负责搜索、详情、推荐、下载链接。
- **异步任务**：Celery + Redis，用于 PPT 解析、LLM 摘要、embedding 生成、索引导入（10k 规模可使用 Upstash 免费层，后期再自建）。
- **元数据存储**：PostgreSQL（Supabase/Neon 免费层即可，~50MB 数据）。
- **向量库**：Pinecone/Qdrant 免费层（>1M 向量）、或 Cloudflare Vectorize（免费 100k 向量）。随着数据增长再迁移到自建 Milvus。
- **文件存储/CDN**：Cloudflare R2/S3 免费层；可保存 PPT 压缩包与预览图。
- **LLM 摘要**：OpenAI `text-embedding-3-small` + GPT 摘要或 DeepSeek 替代。可在关键模板上使用，以结构化 JSON 输出。

## 2.阶段性策略
| 阶段 | 方案 | 说明 |
| --- | --- | --- |
| MVP（<=10k PPT） | Supabase + Pinecone + Upstash + Cloudflare R2 | 全部使用免费/低配层，快速上线；摘要可采用模板化 |
| 增长（10k-100k PPT） | 升级 Postgres（Supabase Pro/自建），Qdrant/Pinecone 付费层，DeepSeek/OpenAI 混合 | 引入 LLM 摘要、推荐模块，Celery 处理批量任务 |
| 成熟（>100k PPT） | 自建 Milvus + Postgres（4C16G 起），阿里/腾讯向量库或 Cloudflare Vectorize 付费层 | 增强多地部署、权限控制、行为推荐等 |

## 3.成本估算（10k PPT）
| 模块 | 免费层 | 若升级 |
| --- | --- | --- |
| Supabase Postgres | 免费（500MB） | Pro $25/月（当数据>500MB） |
| Pinecone | 免费 Starter（5M 向量） | Standard $0.096/小时（示例） |
| Upstash Redis | 免费（10k 请求/天） | $0.2/百万请求 |
| Cloudflare Vectorize | 免费（100k 向量） | $0.10/百万向量/天 + $0.01/千次查询 |
| OpenAI Embedding | 约 $2/10k PPT | DeepSeek 等国产 API 进一步降成本 |
| FastAPI 部署 | Vercel/Cloudflare 免费层 | 自建 CVM（4C8G）约 ¥1500/年 |

**总计**：在 10k PPT 规模内，可以几乎零成本运行（仅有少量 OpenAI API 费用）。随着规模增长，再转向自建或付费层。

## 4.关键指标与监控
- **数据库容量**：记录当前 meta 条数、索引大小、连接数。
- **向量库**：向量条数、qps、延迟；记录 `embedding_model`、`provider` 以便迁移。
- **任务队列**：Celery 任务成功/失败率、重试次数、平均耗时。
- **LLM 成本**：每月 embedding/摘要 tokens 用量，用于预测费用。
- **用户行为**：搜索词、下载量、推荐点击率，以便优化排序和推荐策略。

## 5.待办与优化方向
1. **摘要生成 pipeline**（解析 → 抽取 → GPT 摘要 → 存储）+ fallback。
2. **向量检索 API**：抽象统一接口，便于在 Pinecone/Milvus/Cloudflare 之间切换。
3. **热榜/推荐**：结合向量相似 + 规则权重（下载数、行业标签）。
4. **权限/版权**：记录每份 PPT 的来源、授权信息，为商业化与 UGC 扩展做准备。
5. **运营工具**：后台控制台（Ant Design Pro）用于管理 PPT、监控任务、查看统计。

---
**整体总结**：以 10,000 份 PPT 为起点，选用“FastAPI + Celery + Supabase + 向量库 SaaS”的轻量架构即可快速上线；成本极低，多数组件可用免费层。随着数据或访问量增长，再逐步迁移到自建 Milvus/Postgres、国产 embedding、云厂商向量库，形成可扩展的语义检索与推荐平台。牢记把关内容来源（合法授权）、embedding 版本、可观测性，以支撑后续商业化和竞品差异化。
