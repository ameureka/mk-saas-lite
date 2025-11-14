# 问题 5：前端架构与组件选择

## 需求回顾
- 支撑“语义检索 + 推荐 + 模板展示”的快速迭代。
- 需要可视化搜索结果、模板预览、标签筛选、个性化推荐模块。
- 希望复用成熟组件/脚手架，减少从零开发成本。

## 技术栈建议
| 模块 | 推荐方案 | 说明 |
| --- | --- | --- |
| 前端框架 | Next.js（React） | 富生态、SSR/ISR 友好、可与 Vercel 部署一体化 |
| UI 组件 | Vercel UI（原 Geist）、Ant Design、Chakra UI | 快速搭建搜索结果页、卡片、分页；若主打海外推荐 Vercel UI，国内可用 AntD |
| 搜索组件 | Vercel AI SDK / LangChain JS（结合向量检索 API） | 提供现成 hook 和 UI pattern，用于“对话式搜素”、“推荐理由”展示 |
| 模板预览 | react-ppt-viewer、reveal.js embed、或直接生成预览图（CDN） | 可用 `react-pdf`/`office-viewer` 展示部分幻灯片，或提前生成 JPG 预览 |
| 交互脚手架 | Next.js + shadcn/ui（Tailwind）/Vite + AntD | 根据团队熟悉度选择；shadcn 提供 search、tabs、cards 等常用 pattern |
| 向量搜索后端 | 需依赖向量数据库（Milvus/PGVector/Pinecone/Cloudflare Vectorize 等）和 Embedding 模型 | 前端仅调用 API，向量检索逻辑在后端完成；可选用 OpenAI/DeepSeek 等模型生成 embedding |

## 设计要点
1. **搜索页**：
   - 顶部提供自然语言搜索框（“输入主题/用途/颜色”）。
   - 结果列表采用卡片模式，展示缩略图、摘要、标签、下载按钮。
   - 侧边栏支持标签筛选（行业/风格/颜色/页数等）。
2. **模板详情页**：
   - 展示 GPT 摘要、章节列表、推荐用途、相似模板。
   - 提供在线预览（前几页）+ 下载按钮 + “收藏/分享”。
3. **推荐模块**：
   - 根据用户浏览/下载历史，调用向量检索 API 显示“与你刚刚查看的相似模板”。
   - 可使用 Next.js API route 调用后端 embedding 服务，前端只需渲染卡片。
4. **脚手架示例**：
   - Next.js + Vercel AI SDK 示例：https://sdk.vercel.ai/docs，内含 ChatUI、SearchResults 等组件，直接整合向量检索返回结果。
   - 若偏向国内生态，可用 Vite + Ant Design Pro，内置列表、筛选、仪表盘模板。 

## 推荐开发流程
1. **快速原型**：Next.js + shadcn/ui（或 AntD）搭建搜索/详情页面，先接 mock 数据。
2. **接入向量检索 API**：使用 Next.js API route 调用后端（FastAPI/Celery 服务），返回 top-K 模板，前端渲染卡片。
3. **增强交互**：集成 Vercel AI SDK，实现“自然语言搜索 + 推荐理由”对话框。
4. **多端适配**：通过 Tailwind/AntD 响应式能力，兼容移动端访问。

## 模型选择 & 成本对比（Embedding）
- 向量检索不一定需要“大模型对话”，只需预先用 Embedding 模型把 PPT 概要转为向量。前端调用的搜索 API 只需发送用户 query，后端生成 query embedding 并与向量库比对即可。
- **模型选择**：
  - OpenAI `text-embedding-3-small`：跨语言好、成本低（约 $0.00002/1K tokens）。适合跨平台部署。
  - DeepSeek Embedding（国产模型，如深度求索 `deepseek-embedding`）：通常提供更低费用（例如 ~¥0.003/千 tokens）并在国内访问更稳定。需要参考最新公开价目。
  - 其它国产模型（如智谱、阿里通义、百度文心等）也提供 embedding API，可根据价格/兼容性选择。
- **成本粗估**（以 100,000 条、每条 1K tokens 为例）：
  - OpenAI `text-embedding-3-small`：约 $2。
  - DeepSeek（假设 ¥0.003/千 tokens）：约 ¥300（$40 左右），但视具体报价而定；若模型提供套餐或本地部署，可更低。
- 若希望完全国产化，可考虑：
  1. 使用 DeepSeek 或 ChatGLM Embedding API（云端）；
  2. 或自建开源中文 embedding（如 bge-large-zh），成本转化为机器算力（需要 GPU 或高性能 CPU）。
- 从前端角度，只需对接一个统一的搜索 API，不必关心后端使用哪种 embedding 模型；后端可根据成本和数据位置切换模型，并在 metadata 中记录 `embedding_model` 字段便于重建。

## 参考组件/脚手架链接
- [Next.js 官方模板](https://github.com/vercel/next.js/tree/canary/examples) – 含 dashboard、e-commerce 示例。
- [shadcn/ui](https://ui.shadcn.com/) – 基于 Tailwind 的 UI 组件集合，样式轻量易改。
- [Vercel AI SDK](https://sdk.vercel.ai/docs) – 提供 Chat、Search、Streaming 组件，适合“对话 + 搜索”场景。
- [Ant Design Pro](https://pro.ant.design/) – 国内常用后台/列表模板，适合快速搭建控制台、数据概览。

> 综上，建议以前端 Next.js + Vercel/Vite 生态为主，选用成熟的 UI 组件库（shadcn/ui 或 AntD），配合 Vercel AI SDK/自定义组件实现语义检索和推荐。这样既能与海外部署（Vercel/cloudflare）兼容，也能在国内通过自建/代理部署。 
