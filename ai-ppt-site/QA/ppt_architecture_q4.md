# 问题 4：向量数据库方案与成本

### 可选方案
| 类别 | 产品 | 部署方式 | 费用/限制 | 说明 |
| --- | --- | --- | --- | --- |
| 开源自托管 | Milvus | 自建（K8s / Docker） | 免费，需服务器成本 | 分布式、支持亿级向量、社区成熟；需维护集群与监控 |
| 开源自托管 | FAISS | 嵌入在服务中（单机内存型） | 免费，受内存限制 | 适合中小规模或离线批处理；不自带服务端，需要自行封装 API |
| 托管 SaaS | Zilliz Cloud | 云托管（Milvus） | 按量计费，提供免费额度 | 兼容 Milvus API，省去运维，适合快速上线 |
| 托管 SaaS | Qdrant Cloud / Pinecone / Weaviate Cloud / Cloudflare Vectorize | 云托管 | 免费/试用层 + 按量收费 | Pinecone/Qdrant 提供免费层；Cloudflare Vectorize 免费层 100k 向量，适合海外/边缘部署 MVP |
| 轻量化方案 | PGVector (PostgreSQL) | 自建/托管 PostgreSQL | 免费，依赖 DB 扩容 | 直接在 Postgres 中存向量，架构更简单，适合 50-100 万级别数据 |
| 云厂商方案 | 阿里云灵积向量数据库 / 腾讯云向量数据库 / 华为云 GAUSSDB(for Redis VSS) | 云托管 | 按量计费，国内延迟低 | 与云厂商生态深度集成，支持专线/VPC、合规性较好 |

### 成本评估
- **自托管 Milvus/FAISS**：主要成本在服务器（CPU/GPU、存储）与运维人力。适合已有 K8s/DevOps 能力、数据量较大（> 100 万）时使用。
- **PGVector**：若已有 PostgreSQL，可快速集成；但向量检索性能受限，适合中小规模或过渡阶段。
- **云托管服务**：
  - Pinecone：Starter 免费层 5M 向量（单维度限制），超出后按小时计费。
  - Qdrant Cloud：提供免费 tier（1M 向量），可按需扩展。
  - Zilliz Cloud：有免费额度，可逐步升级。适合不想自己运维但又需要 Milvus 兼容性的场景。
  - Cloudflare Vectorize：免费层 1 索引 / 100k 向量；付费层按量计费（示例：$0.10/百万向量/天 + $0.01/千次查询）。如存 1M 向量，约 $0.10 × 1 ≈ $0.10/天（≈$3/月），再叠加查询费用；适合早期或海外场景。

### 推荐策略
1. **MVP 阶段**：优先考虑 SaaS 免费/试用层（Pinecone、Qdrant、Zilliz Cloud），可快速上线验证，成本为 $0 或极低。
2. **稳定阶段**：当数据量增长或需精细控制成本时，评估自建 Milvus（若有运维能力）或 PGVector（若数据<1-2M）。
3. **大规模/高并发**：Milvus + Zilliz Cloud、自建 Milvus 集群，或选择国内云厂商的托管向量库（阿里云灵积、腾讯云向量 DB），可兼顾性能和合规。

### 架构注意
- 无论采用何种方案，注意记录 `embedding_model`、`version` 字段，方便后续重新计算。 
- 建议在向量库旁边存一份冗余（如 S3/OSS 导出），以免需要迁移时重新计算。
