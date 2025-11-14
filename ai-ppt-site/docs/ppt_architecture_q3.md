# 问题 3：Embedding 方案与成本评估

### 方案选型
| 方案 | 模型 | 部署方式 | 单次 1K tokens 费用 | 备注 |
| --- | --- | --- | --- | --- |
| OpenAI API | `text-embedding-3-small` | 云端 API | ~$0.00002 | 1536 维，成本最低，支持中英混合，高可用，有速率限制 |
| OpenAI API | `text-embedding-3-large` | 云端 API | ~$0.00013 | 3072 维，精度更高，成本 ~6x small，适合高要求检索 |
| Google Vertex AI | `textembedding-gecko` | 云端 API | ~$0.0001 | 768 维，支持多语言；需 GCP 项目/配额 |
| 本地模型 | `bge-large-zh`、`m3e-base` 等 | 自托管 | 仅算力/显卡成本 | 需 GPU 或高性能 CPU，部署维护成本高，需自行扩缩容 |

### 成本估算（以 100,000 份 PPT、平均 1K tokens 为例）
| 模型 | 估算成本 |
| --- | --- |
| text-embedding-3-small | ~$2 (100k × 0.00002) |
| text-embedding-3-large | ~$13 |
| textembedding-gecko | ~$10 |
| 本地模型 | 无 API 费用，但需 GPU（如 1× A100 每月几百美金） |

### 存储占用估算（以 float32 表示）
> 公式：`size = 向量数 × 维度 × 4 字节`；再预留 20% 索引开销。

| 向量数 | 1536 维 (`text-embedding-3-small`) | 3072 维 (`text-embedding-3-large`) |
| --- | --- | --- |
| 50,000 | ≈ 300 MB (含索引 360 MB) | ≈ 600 MB (含索引 720 MB) |
| 100,000 | ≈ 600 MB (含索引 720 MB) | ≈ 1.2 GB (含索引 1.44 GB) |
| 500,000 | ≈ 3.0 GB (含索引 3.6 GB) | ≈ 6.0 GB (含索引 7.2 GB) |
| 1,000,000 | ≈ 6.0 GB (含索引 7.2 GB) | ≈ 12.0 GB (含索引 14.4 GB) |

**SaaS 选择建议**
- Pinecone Starter（5M 向量免费层）可覆盖 1M 以内向量（1536 维占用约 6 GB），适合作为 MVP。  
- Qdrant/Zilliz Cloud 的免费/开发者层通常提供 1M 向量或 2-4 GB 内存，也可支持前期数据量。  
- 若预计超过 5M 向量或 10 GB 内存，需进入付费层或自建 Milvus。建议在处理前统计 PPT 数量，按上表推算占用，再选 SaaS 等级。

### 推荐策略
1. **初期/快速验证**：采用 OpenAI `text-embedding-3-small`。优点：  
   - 成本极低（百万级文档也在数十美元内）。  
   - 跨语言效果好，部署简单。  
   - 可以与 OpenAI 的 GPT 摘要流程共享 API Key / 网络配置。
2. **扩展/多云备份**：可增加 Vertex AI `textembedding-gecko` 作为备份或特定区域访问。  
3. **在地化/成本进一步优化**：当数据量达到千万级或需离线部署时，再评估本地模型（例如用 `bge-large-zh` + Faiss GPU）。需具备：  
   - Docker/K8s 部署能力  
   - GPU 资源或高性能 CPU 集群  
   - 运维监控体系

### 额外注意
- 统计每次 embedding 的 tokens 数量，便于精确计费与预估。  
- 建议将 embedding 任务做成 Celery 异步任务，对失败请求自动重试。  
- 对于重复 PPT，考虑做内容哈希（如 SimHash）避免重复嵌入，节省成本。  
- 默认采用 1536 维向量即可满足语义检索，不必一开始就使用大型模型。  
- 将 embedding 结果与 PPT 元数据一起保存，后续若切换模型可记录版本号，方便重建。
