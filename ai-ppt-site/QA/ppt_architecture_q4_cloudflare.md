# Cloudflare Vectorize 方案评估

## 概述
Cloudflare Vectorize 是 Cloudflare Workers AI 的向量存储服务，与 Workers KV / Durable Objects 集成，适合在 Cloudflare 边缘网络上直接部署向量检索逻辑。

## 免费层与费用
- 免费层（截至 2025-11）：
  - 支持 1 个索引，最多 100,000 条向量。
  - 每条向量默认 1536 维（可调整），存储/检索操作有每日免费额度。
- 付费层：
  - 按向量数量 + 请求次数计费（参考：$0.10 / 百万向量存储 / 天；$0.01 / 千次查询）。
  - 具体定价会随公告变化，建议参考 Cloudflare 官方定价页。

## 优势
1. **边缘部署**：与 Cloudflare Workers、Queues、AI 模型推理深度集成，可实现“近用户”的低延迟检索。
2. **免费层友好**：1 个索引 + 100k 向量足够 MVP，且无需自建基础设施。若你初期 embedding 在 10 万级内，可零成本上线。
3. **统一鉴权**：可复用 Cloudflare Access/Zero Trust，简化安全策略。

## 限制/注意
1. 索引数量受限：免费层仅 1 个索引，若需要多索引（按频道/语言拆分），需升级付费层或自行 multiplex。
2. 向量维度和数据类型需与 Cloudflare Vectorize 的支持范围匹配（一般支持 1024/1536/3000 等常见维度）。
3. 仍处于较新阶段，生态/工具链不如 Milvus/Pinecone 成熟，需评估长期路线。
4. 若后端主要部署在国内云，Cloudflare 边缘访问可能涉及跨境延迟；适合面向海外用户或需要全球 CDN 的场景。

## 建议
- **MVP 阶段**：如果你计划先面向海外用户，或已有 Workers 生态，Vectorize 的免费层是零成本验证 embedding 检索的好选择。
- **国内业务**：如需满足国内访问、合规、与云厂商内网互通，仍建议使用阿里/腾讯等国内向量数据库，或自建 Milvus。
- 可以在 `embedding_index` metadata 中记录 `provider=cloudflare`，后续需要迁移到 Milvus/Qdrant 时，重建流程保持一致。
