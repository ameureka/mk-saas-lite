# 问题10：目前有哪些关于 AI SDK 的插件系列的部署以及相关的应用？常见的工具系列 Chatbox、RAG

## 概述

MkSaaS 集成了 **Vercel AI SDK**，这是一个强大的 AI 应用开发框架，支持多种 AI 提供商和功能。项目中已经集成了文本生成、图片生成、聊天对话等 AI 功能。

## AI SDK 技术栈

### 核心依赖

从 `package.json` 可以看到 MkSaaS 集成了以下 AI SDK：

```json
{
  "dependencies": {
    "@ai-sdk/deepseek": "^1.0.0",      // DeepSeek AI
    "@ai-sdk/fal": "^1.0.0",           // Fal.ai (图片生成)
    "@ai-sdk/fireworks": "^1.0.0",     // Fireworks AI
    "@ai-sdk/google": "^2.0.0",        // Google Gemini
    "@ai-sdk/openai": "^2.0.0",        // OpenAI GPT
    "@ai-sdk/react": "^2.0.22",        // React Hooks
    "@ai-sdk/replicate": "^1.0.0",     // Replicate
    "@openrouter/ai-sdk-provider": "^1.0.0-beta.6",  // OpenRouter
    "ai": "^5.0.0",                    // Vercel AI SDK 核心
    "@mendable/firecrawl-js": "^1.29.1",  // 网页爬取
    "@orama/orama": "^3.1.4",          // 全文搜索
    "@orama/tokenizers": "^3.1.4",     // 分词器
  }
}
```

## AI 功能模块

### 目录结构

```
src/ai/
├── chat/                      # AI 聊天功能
│   └── components/           # 聊天组件
│       ├── chat-interface.tsx
│       ├── message-list.tsx
│       └── input-area.tsx
├── image/                     # AI 图片生成
│   ├── components/           # 图片组件
│   │   ├── image-generator.tsx
│   │   └── image-gallery.tsx
│   ├── hooks/                # 图片 Hooks
│   │   └── use-image-generation.ts
│   └── lib/                  # 图片工具
│       └── image-utils.ts
└── text/                      # AI 文本生成
    ├── components/           # 文本组件
    │   ├── text-generator.tsx
    │   └── web-content-analyzer.tsx
    └── utils/                # 文本工具
        └── text-utils.ts
```

## 1. AI 聊天功能 (Chatbox)

### 特性

- 流式响应
- 多轮对话
- 上下文记忆
- Markdown 渲染
- 代码高亮
- 文件上传
- 语音输入

### 实现示例

#### API 路由

```typescript
// src/app/api/chat/route.ts
import { openai } from '@ai-sdk/openai';
import { streamText } from 'ai';

export const runtime = 'edge';

export async function POST(req: Request) {
  const { messages } = await req.json();
  
  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
    system: 'You are a helpful assistant.',
    temperature: 0.7,
    maxTokens: 2000,
  });
  
  return result.toDataStreamResponse();
}
```

#### 前端组件

```typescript
// src/ai/chat/components/chat-interface.tsx
'use client';

import { useChat } from '@ai-sdk/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

export function ChatInterface() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
    onError: (error) => {
      console.error('Chat error:', error);
    },
  });
  
  return (
    <div className="flex flex-col h-screen">
      {/* 消息列表 */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((message) => (
          <div
            key={message.id}
            className={`flex ${
              message.role === 'user' ? 'justify-end' : 'justify-start'
            }`}
          >
            <div
              className={`max-w-[80%] rounded-lg p-4 ${
                message.role === 'user'
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-muted'
              }`}
            >
              {message.content}
            </div>
          </div>
        ))}
        
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-muted rounded-lg p-4">
              <div className="flex space-x-2">
                <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" />
                <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce delay-100" />
                <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce delay-200" />
              </div>
            </div>
          </div>
        )}
      </div>
      
      {/* 输入区域 */}
      <form onSubmit={handleSubmit} className="p-4 border-t">
        <div className="flex space-x-2">
          <Input
            value={input}
            onChange={handleInputChange}
            placeholder="输入消息..."
            disabled={isLoading}
            className="flex-1"
          />
          <Button type="submit" disabled={isLoading}>
            发送
          </Button>
        </div>
      </form>
    </div>
  );
}
```

### 高级功能

#### 1. 函数调用 (Function Calling)

```typescript
import { openai } from '@ai-sdk/openai';
import { streamText, tool } from 'ai';
import { z } from 'zod';

export async function POST(req: Request) {
  const { messages } = await req.json();
  
  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
    tools: {
      weather: tool({
        description: '获取指定城市的天气信息',
        parameters: z.object({
          city: z.string().describe('城市名称'),
        }),
        execute: async ({ city }) => {
          // 调用天气 API
          const weather = await getWeather(city);
          return weather;
        },
      }),
      search: tool({
        description: '搜索网络信息',
        parameters: z.object({
          query: z.string().describe('搜索关键词'),
        }),
        execute: async ({ query }) => {
          // 调用搜索 API
          const results = await searchWeb(query);
          return results;
        },
      }),
    },
  });
  
  return result.toDataStreamResponse();
}
```

#### 2. 多模态输入

```typescript
const result = streamText({
  model: openai('gpt-4-vision-preview'),
  messages: [
    {
      role: 'user',
      content: [
        { type: 'text', text: '这张图片里有什么？' },
        {
          type: 'image',
          image: 'https://example.com/image.jpg',
        },
      ],
    },
  ],
});
```

#### 3. 流式对象生成

```typescript
import { streamObject } from 'ai';
import { z } from 'zod';

const result = streamObject({
  model: openai('gpt-4-turbo'),
  schema: z.object({
    recipe: z.object({
      name: z.string(),
      ingredients: z.array(z.string()),
      steps: z.array(z.string()),
    }),
  }),
  prompt: '生成一个巧克力蛋糕的食谱',
});

// 使用
for await (const partialObject of result.partialObjectStream) {
  console.log(partialObject);
}
```

## 2. AI 文本生成

### 实现示例

#### API 路由

```typescript
// src/app/api/generate-text/route.ts
import { openai } from '@ai-sdk/openai';
import { generateText } from 'ai';

export async function POST(req: Request) {
  const { prompt, model = 'gpt-4-turbo' } = await req.json();
  
  try {
    const { text, usage } = await generateText({
      model: openai(model),
      prompt,
      temperature: 0.7,
      maxTokens: 1000,
    });
    
    return Response.json({
      success: true,
      text,
      usage,
    });
  } catch (error) {
    return Response.json(
      { success: false, error: error.message },
      { status: 500 }
    );
  }
}
```

#### 前端组件

```typescript
// src/ai/text/components/text-generator.tsx
'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';

export function TextGenerator() {
  const [prompt, setPrompt] = useState('');
  const [result, setResult] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  const handleGenerate = async () => {
    setIsLoading(true);
    
    try {
      const response = await fetch('/api/generate-text', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt }),
      });
      
      const data = await response.json();
      
      if (data.success) {
        setResult(data.text);
      } else {
        console.error('Generation failed:', data.error);
      }
    } catch (error) {
      console.error('Error:', error);
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <div className="space-y-4">
      <Textarea
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        placeholder="输入提示词..."
        rows={4}
      />
      
      <Button onClick={handleGenerate} disabled={isLoading}>
        {isLoading ? '生成中...' : '生成文本'}
      </Button>
      
      {result && (
        <div className="p-4 bg-muted rounded-lg">
          <p className="whitespace-pre-wrap">{result}</p>
        </div>
      )}
    </div>
  );
}
```

## 3. AI 图片生成

### 支持的提供商

- **Fal.ai**: 快速图片生成
- **Replicate**: Stable Diffusion 等模型
- **OpenAI DALL-E**: 高质量图片生成

### 实现示例

#### API 路由

```typescript
// src/app/api/generate-images/route.ts
import { fal } from '@ai-sdk/fal';
import { generateImage } from 'ai';

export async function POST(req: Request) {
  const { prompt, model = 'fal-ai/flux/schnell' } = await req.json();
  
  try {
    const { image } = await generateImage({
      model: fal(model),
      prompt,
      size: '1024x1024',
      n: 1,
    });
    
    return Response.json({
      success: true,
      imageUrl: image.url,
    });
  } catch (error) {
    return Response.json(
      { success: false, error: error.message },
      { status: 500 }
    );
  }
}
```

#### 前端组件

```typescript
// src/ai/image/components/image-generator.tsx
'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import Image from 'next/image';

export function ImageGenerator() {
  const [prompt, setPrompt] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  const handleGenerate = async () => {
    setIsLoading(true);
    
    try {
      const response = await fetch('/api/generate-images', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt }),
      });
      
      const data = await response.json();
      
      if (data.success) {
        setImageUrl(data.imageUrl);
      }
    } catch (error) {
      console.error('Error:', error);
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <div className="space-y-4">
      <Input
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        placeholder="描述你想生成的图片..."
      />
      
      <Button onClick={handleGenerate} disabled={isLoading}>
        {isLoading ? '生成中...' : '生成图片'}
      </Button>
      
      {imageUrl && (
        <div className="relative w-full aspect-square">
          <Image
            src={imageUrl}
            alt="Generated image"
            fill
            className="object-contain rounded-lg"
          />
        </div>
      )}
    </div>
  );
}
```

## 4. RAG (检索增强生成)

### 技术栈

- **Orama**: 全文搜索引擎
- **Firecrawl**: 网页内容爬取
- **Embeddings**: 向量嵌入

### 实现示例

#### 1. 内容索引

```typescript
// src/lib/search/index.ts
import { create, insert, search } from '@orama/orama';

// 创建搜索索引
export async function createSearchIndex() {
  const db = await create({
    schema: {
      id: 'string',
      title: 'string',
      content: 'string',
      url: 'string',
      embedding: 'vector[1536]',  // OpenAI embeddings
    },
  });
  
  return db;
}

// 添加文档
export async function addDocument(db, document) {
  await insert(db, {
    id: document.id,
    title: document.title,
    content: document.content,
    url: document.url,
    embedding: await getEmbedding(document.content),
  });
}

// 搜索文档
export async function searchDocuments(db, query) {
  const queryEmbedding = await getEmbedding(query);
  
  const results = await search(db, {
    term: query,
    properties: ['title', 'content'],
    vector: {
      value: queryEmbedding,
      property: 'embedding',
    },
    limit: 5,
  });
  
  return results.hits;
}
```

#### 2. 网页爬取

```typescript
// src/lib/crawl/firecrawl.ts
import FirecrawlApp from '@mendable/firecrawl-js';

const firecrawl = new FirecrawlApp({
  apiKey: process.env.FIRECRAWL_API_KEY!,
});

export async function crawlWebsite(url: string) {
  const result = await firecrawl.scrapeUrl(url, {
    formats: ['markdown', 'html'],
  });
  
  return {
    title: result.metadata?.title,
    content: result.markdown,
    url: result.metadata?.sourceURL,
  };
}
```

#### 3. RAG API 路由

```typescript
// src/app/api/analyze-content/route.ts
import { openai } from '@ai-sdk/openai';
import { streamText } from 'ai';
import { searchDocuments } from '@/lib/search';
import { crawlWebsite } from '@/lib/crawl/firecrawl';

export async function POST(req: Request) {
  const { query, url } = await req.json();
  
  // 1. 爬取网页内容（如果提供了 URL）
  let context = '';
  if (url) {
    const crawled = await crawlWebsite(url);
    context = crawled.content;
  } else {
    // 2. 从索引中搜索相关文档
    const results = await searchDocuments(db, query);
    context = results.map(r => r.document.content).join('\n\n');
  }
  
  // 3. 使用检索到的内容作为上下文
  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages: [
      {
        role: 'system',
        content: `你是一个有帮助的助手。使用以下上下文回答用户的问题：\n\n${context}`,
      },
      {
        role: 'user',
        content: query,
      },
    ],
  });
  
  return result.toDataStreamResponse();
}
```

#### 4. 前端组件

```typescript
// src/ai/text/components/web-content-analyzer.tsx
'use client';

import { useChat } from '@ai-sdk/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

export function WebContentAnalyzer() {
  const [url, setUrl] = useState('');
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/analyze-content',
    body: { url },
  });
  
  return (
    <div className="space-y-4">
      <Input
        value={url}
        onChange={(e) => setUrl(e.target.value)}
        placeholder="输入网页 URL..."
      />
      
      <div className="space-y-2">
        {messages.map((message) => (
          <div key={message.id} className="p-4 bg-muted rounded-lg">
            <p className="font-semibold">{message.role}</p>
            <p className="whitespace-pre-wrap">{message.content}</p>
          </div>
        ))}
      </div>
      
      <form onSubmit={handleSubmit} className="flex space-x-2">
        <Input
          value={input}
          onChange={handleInputChange}
          placeholder="询问关于这个网页的问题..."
          disabled={isLoading}
        />
        <Button type="submit" disabled={isLoading}>
          提问
        </Button>
      </form>
    </div>
  );
}
```

## 5. 向量数据库集成

### 支持的向量数据库

1. **Pinecone**: 托管向量数据库
2. **Weaviate**: 开源向量搜索引擎
3. **Qdrant**: 高性能向量数据库
4. **Chroma**: 轻量级向量数据库
5. **Supabase Vector**: PostgreSQL + pgvector

### Pinecone 集成示例

```typescript
// src/lib/vector/pinecone.ts
import { Pinecone } from '@pinecone-database/pinecone';
import { openai } from '@ai-sdk/openai';
import { embed } from 'ai';

const pinecone = new Pinecone({
  apiKey: process.env.PINECONE_API_KEY!,
});

const index = pinecone.index('my-index');

// 生成嵌入向量
export async function getEmbedding(text: string) {
  const { embedding } = await embed({
    model: openai.embedding('text-embedding-3-small'),
    value: text,
  });
  
  return embedding;
}

// 存储向量
export async function storeVector(id: string, text: string, metadata: any) {
  const embedding = await getEmbedding(text);
  
  await index.upsert([
    {
      id,
      values: embedding,
      metadata: {
        text,
        ...metadata,
      },
    },
  ]);
}

// 相似度搜索
export async function similaritySearch(query: string, topK: number = 5) {
  const queryEmbedding = await getEmbedding(query);
  
  const results = await index.query({
    vector: queryEmbedding,
    topK,
    includeMetadata: true,
  });
  
  return results.matches;
}
```

## 6. AI 提供商配置

### OpenAI

```typescript
import { openai } from '@ai-sdk/openai';

// GPT-4 Turbo
const model = openai('gpt-4-turbo');

// GPT-4
const model = openai('gpt-4');

// GPT-3.5 Turbo
const model = openai('gpt-3.5-turbo');

// 自定义配置
const model = openai('gpt-4-turbo', {
  apiKey: process.env.OPENAI_API_KEY,
  organization: process.env.OPENAI_ORG_ID,
});
```

### Google Gemini

```typescript
import { google } from '@ai-sdk/google';

// Gemini Pro
const model = google('gemini-pro');

// Gemini Pro Vision
const model = google('gemini-pro-vision');
```

### DeepSeek

```typescript
import { deepseek } from '@ai-sdk/deepseek';

const model = deepseek('deepseek-chat');
```

### Fireworks AI

```typescript
import { fireworks } from '@ai-sdk/fireworks';

const model = fireworks('accounts/fireworks/models/llama-v3-70b-instruct');
```

### OpenRouter (多模型聚合)

```typescript
import { openrouter } from '@openrouter/ai-sdk-provider';

// 使用任意模型
const model = openrouter('anthropic/claude-3-opus');
const model = openrouter('meta-llama/llama-3-70b-instruct');
const model = openrouter('google/gemini-pro');
```

## 7. 积分消费集成

### 消费积分

```typescript
// src/app/api/chat/route.ts
import { consumeCreditsAction } from '@/actions/consume-credits';

export async function POST(req: Request) {
  const { messages } = await req.json();
  const session = await getSession();
  
  // 检查积分余额
  const balance = await getCreditBalance(session.user.id);
  const requiredCredits = 10; // 每次对话消耗 10 积分
  
  if (balance < requiredCredits) {
    return Response.json(
      { error: '积分不足' },
      { status: 402 }
    );
  }
  
  // 生成响应
  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
  });
  
  // 消费积分
  await consumeCreditsAction({
    amount: requiredCredits,
    description: 'AI 对话',
  });
  
  return result.toDataStreamResponse();
}
```

## 8. 错误处理和重试

### 实现重试逻辑

```typescript
import { openai } from '@ai-sdk/openai';
import { generateText } from 'ai';

async function generateWithRetry(prompt: string, maxRetries: number = 3) {
  let lastError;
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      const result = await generateText({
        model: openai('gpt-4-turbo'),
        prompt,
      });
      
      return result;
    } catch (error) {
      lastError = error;
      
      // 等待后重试
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
  
  throw lastError;
}
```

## 9. 流式响应优化

### 服务端流式处理

```typescript
import { openai } from '@ai-sdk/openai';
import { streamText } from 'ai';

export async function POST(req: Request) {
  const { messages } = await req.json();
  
  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
    onChunk: ({ chunk }) => {
      // 处理每个 chunk
      console.log('Chunk:', chunk);
    },
    onFinish: ({ text, usage }) => {
      // 完成时的回调
      console.log('Finished:', text);
      console.log('Usage:', usage);
    },
  });
  
  return result.toDataStreamResponse();
}
```

### 客户端流式处理

```typescript
'use client';

import { useChat } from '@ai-sdk/react';

export function ChatComponent() {
  const { messages, input, handleInputChange, handleSubmit, isLoading, error } = useChat({
    api: '/api/chat',
    onResponse: (response) => {
      console.log('Response received');
    },
    onFinish: (message) => {
      console.log('Message finished:', message);
    },
    onError: (error) => {
      console.error('Error:', error);
    },
  });
  
  // ... 组件实现
}
```

## 10. 性能优化

### 1. 缓存响应

```typescript
import { openai } from '@ai-sdk/openai';
import { generateText } from 'ai';

const cache = new Map();

export async function generateWithCache(prompt: string) {
  // 检查缓存
  if (cache.has(prompt)) {
    return cache.get(prompt);
  }
  
  // 生成响应
  const result = await generateText({
    model: openai('gpt-4-turbo'),
    prompt,
  });
  
  // 存入缓存
  cache.set(prompt, result);
  
  return result;
}
```

### 2. 批量处理

```typescript
async function batchGenerate(prompts: string[]) {
  const results = await Promise.all(
    prompts.map(prompt =>
      generateText({
        model: openai('gpt-4-turbo'),
        prompt,
      })
    )
  );
  
  return results;
}
```

### 3. 使用更快的模型

```typescript
// 对于简单任务使用 GPT-3.5
const fastModel = openai('gpt-3.5-turbo');

// 对于复杂任务使用 GPT-4
const powerfulModel = openai('gpt-4-turbo');
```

## 11. 安全性

### 1. 输入验证

```typescript
import { z } from 'zod';

const chatSchema = z.object({
  messages: z.array(z.object({
    role: z.enum(['user', 'assistant', 'system']),
    content: z.string().max(10000),
  })),
});

export async function POST(req: Request) {
  const body = await req.json();
  
  // 验证输入
  const validated = chatSchema.parse(body);
  
  // ... 处理请求
}
```

### 2. 速率限制

```typescript
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'), // 每分钟 10 次
});

export async function POST(req: Request) {
  const session = await getSession();
  
  // 检查速率限制
  const { success } = await ratelimit.limit(session.user.id);
  
  if (!success) {
    return Response.json(
      { error: '请求过于频繁' },
      { status: 429 }
    );
  }
  
  // ... 处理请求
}
```

### 3. 内容过滤

```typescript
import { Moderation } from 'openai';

async function moderateContent(text: string) {
  const moderation = await openai.moderations.create({
    input: text,
  });
  
  const flagged = moderation.results[0].flagged;
  
  if (flagged) {
    throw new Error('内容违反使用政策');
  }
}
```

## 12. 监控和日志

### 使用 Vercel AI SDK 的内置日志

```typescript
import { openai } from '@ai-sdk/openai';
import { streamText } from 'ai';

export async function POST(req: Request) {
  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
    experimental_telemetry: {
      isEnabled: true,
      functionId: 'chat-completion',
      metadata: {
        userId: session.user.id,
        model: 'gpt-4-turbo',
      },
    },
  });
  
  return result.toDataStreamResponse();
}
```

## 13. 环境变量配置

```env
# OpenAI
OPENAI_API_KEY=sk-...

# Google Gemini
GOOGLE_GENERATIVE_AI_API_KEY=...

# DeepSeek
DEEPSEEK_API_KEY=...

# Fireworks AI
FIREWORKS_API_KEY=...

# OpenRouter
OPENROUTER_API_KEY=...

# Fal.ai (图片生成)
FAL_KEY=...

# Replicate
REPLICATE_API_TOKEN=...

# Firecrawl (网页爬取)
FIRECRAWL_API_KEY=...

# Pinecone (向量数据库)
PINECONE_API_KEY=...
PINECONE_ENVIRONMENT=...
```

## 总结

MkSaaS 集成了完整的 AI 功能栈：

1. **多模型支持**: OpenAI、Google、DeepSeek、Fireworks 等
2. **聊天功能**: 流式对话、函数调用、多模态输入
3. **文本生成**: 各种文本生成任务
4. **图片生成**: Fal.ai、Replicate、DALL-E
5. **RAG 系统**: Orama 搜索 + Firecrawl 爬取
6. **向量数据库**: Pinecone 等向量存储
7. **积分系统**: 与 AI 功能深度集成
8. **性能优化**: 缓存、批处理、模型选择
9. **安全性**: 输入验证、速率限制、内容过滤
10. **监控**: 完整的日志和遥测

通过这些工具和最佳实践，可以快速构建强大的 AI 应用。
