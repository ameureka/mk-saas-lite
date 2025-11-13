# 问题16：关于营销的SEO优化甚至是GEO优化的逻辑在设计之前就融入到对现有的体系设计之中

## 概述

MkSaaS 从架构设计之初就深度集成了 SEO 和 GEO（地理位置）优化策略，利用 Next.js 15 的强大功能和现代化的 SEO 最佳实践，确保网站在搜索引擎中获得最佳排名和全球用户的优质体验。

## 一、SEO 架构设计

### 1. Next.js SEO 优势

```
Next.js 15 SEO 特性:

├── Server Components (默认)
│   ├── 更快的首屏渲染
│   ├── 更好的 SEO 爬取
│   └── 减少客户端 JavaScript
│
├── 自动元数据生成
│   ├── generateMetadata()
│   ├── 静态和动态元数据
│   └── 类型安全
│
├── 自动 Sitemap 生成
│   ├── sitemap.ts
│   ├── 动态路由支持
│   └── 多语言支持
│
├── Robots.txt 生成
│   ├── robots.ts
│   ├── 自定义规则
│   └── Sitemap 链接
│
└── 图片优化
    ├── next/image
    ├── 自动 WebP
    └── 响应式图片
```

### 2. 元数据系统

#### 统一元数据生成

```typescript
// src/lib/metadata.ts
import { websiteConfig } from '@/config/website';
import { defaultMessages } from '@/i18n/messages';
import { routing } from '@/i18n/routing';
import type { Metadata } from 'next';
import type { Locale } from 'next-intl';
import { generateAlternates, getCurrentHreflang } from './hreflang';
import { getBaseUrl, getImageUrl, getUrlWithLocale } from './urls/urls';

/**
 * 构建页面元数据
 */
export function constructMetadata({
  title,
  description,
  image,
  noIndex = false,
  locale,
  pathname,
}: {
  title?: string;
  description?: string;
  image?: string;
  noIndex?: boolean;
  locale?: Locale;
  pathname?: string;
} = {}): Metadata {
  // 使用默认值
  title = title || defaultMessages.Metadata.title;
  description = description || defaultMessages.Metadata.description;
  image = image || websiteConfig.metadata.images?.ogImage;
  
  // 生成完整的图片 URL
  const ogImageUrl = getImageUrl(image || '');
  
  // 生成规范 URL
  const canonicalUrl = locale
    ? getUrlWithLocale(pathname || '', locale).replace(/\/$/, '')
    : undefined;
  
  // 生成 hreflang 替代链接
  const alternates =
    pathname && routing.locales.length > 1
      ? {
          canonical: canonicalUrl,
          ...generateAlternates(pathname),
        }
      : canonicalUrl
        ? { canonical: canonicalUrl }
        : undefined;
  
  return {
    title,
    description,
    alternates,
    
    // Open Graph (Facebook, LinkedIn)
    openGraph: {
      type: 'website',
      locale: locale ? getCurrentHreflang(locale).replace('-', '_') : 'en_US',
      url: canonicalUrl,
      title,
      description,
      siteName: defaultMessages.Metadata.name,
      images: [
        {
          url: ogImageUrl.toString(),
          width: 1200,
          height: 630,
          alt: title,
        },
      ],
    },
    
    // Twitter Card
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [ogImageUrl.toString()],
      site: '@mksaascom',
      creator: '@indie_maker_fox',
    },
    
    // 图标
    icons: {
      icon: '/favicon.ico',
      shortcut: '/favicon-32x32.png',
      apple: '/apple-touch-icon.png',
    },
    
    // 基础 URL
    metadataBase: new URL(getBaseUrl()),
    
    // PWA Manifest
    manifest: `${getBaseUrl()}/manifest.webmanifest`,
    
    // Robots 指令
    ...(noIndex && {
      robots: {
        index: false,
        follow: false,
      },
    }),
    
    // 其他元数据
    keywords: defaultMessages.Metadata.keywords,
    authors: [
      {
        name: 'MkSaaS',
        url: 'https://mksaas.com',
      },
    ],
    creator: 'MkSaaS',
    publisher: 'MkSaaS',
    
    // 验证标签
    verification: {
      google: process.env.NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION,
      yandex: process.env.NEXT_PUBLIC_YANDEX_VERIFICATION,
      bing: process.env.NEXT_PUBLIC_BING_VERIFICATION,
    },
  };
}
```

#### 页面级元数据

```typescript
// src/app/[locale]/(marketing)/blog/[...slug]/page.tsx
import { constructMetadata } from '@/lib/metadata';
import type { Metadata } from 'next';

interface PageProps {
  params: {
    locale: string;
    slug: string[];
  };
}

export async function generateMetadata({ 
  params 
}: PageProps): Promise<Metadata> {
  const { locale, slug } = params;
  
  // 获取文章数据
  const post = await getPost(slug);
  
  if (!post) {
    return constructMetadata({
      title: 'Post Not Found',
      noIndex: true,
    });
  }
  
  return constructMetadata({
    title: post.data.title,
    description: post.data.description,
    image: post.data.image,
    locale: locale as Locale,
    pathname: `/blog/${slug.join('/')}`,
  });
}

export default function BlogPostPage({ params }: PageProps) {
  // 页面内容
}
```

### 3. Sitemap 生成

#### 动态 Sitemap

```typescript
// src/app/sitemap.ts
import { websiteConfig } from '@/config/website';
import { getLocalePathname } from '@/i18n/navigation';
import { routing } from '@/i18n/routing';
import { generateHreflangUrls } from '@/lib/hreflang';
import { blogSource, categorySource, source } from '@/lib/source';
import type { MetadataRoute } from 'next';
import type { Locale } from 'next-intl';
import { getBaseUrl } from '../lib/urls/urls';

/**
 * 静态路由列表
 */
const staticRoutes = [
  '/',
  '/about',
  ...(websiteConfig.blog.enable ? ['/blog'] : []),
  ...(websiteConfig.docs.enable ? ['/docs'] : []),
];

/**
 * 生成完整的 Sitemap
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const sitemapList: MetadataRoute.Sitemap = [];
  
  // 1. 添加静态路由
  sitemapList.push(
    ...staticRoutes.flatMap((route) => {
      return routing.locales.map((locale) => ({
        url: getUrl(route, locale),
        lastModified: new Date(),
        changeFrequency: 'weekly' as const,
        priority: route === '/' ? 1.0 : 0.8,
        alternates: {
          languages: generateHreflangUrls(route),
        },
      }));
    })
  );
  
  // 2. 添加博客相关路由
  if (websiteConfig.blog.enable) {
    // 博客列表分页
    routing.locales.forEach((locale) => {
      const posts = blogSource
        .getPages(locale)
        .filter((post) => post.data.published);
      
      const totalPages = Math.max(
        1,
        Math.ceil(posts.length / websiteConfig.blog.paginationSize)
      );
      
      // 分页路由 /blog/page/[page]
      for (let page = 2; page <= totalPages; page++) {
        sitemapList.push({
          url: getUrl(`/blog/page/${page}`, locale),
          lastModified: new Date(),
          changeFrequency: 'daily',
          priority: 0.7,
          alternates: {
            languages: generateHreflangUrls(`/blog/page/${page}`),
          },
        });
      }
    });
    
    // 分类页面
    routing.locales.forEach((locale) => {
      const categories = categorySource.getPages(locale);
      
      categories.forEach((category) => {
        const postsInCategory = blogSource
          .getPages(locale)
          .filter((post) => post.data.published)
          .filter((post) =>
            post.data.categories.some((cat) => cat === category.slugs[0])
          );
        
        const totalPages = Math.max(
          1,
          Math.ceil(postsInCategory.length / websiteConfig.blog.paginationSize)
        );
        
        // 分类首页
        sitemapList.push({
          url: getUrl(`/blog/category/${category.slugs[0]}`, locale),
          lastModified: new Date(),
          changeFrequency: 'weekly',
          priority: 0.7,
          alternates: {
            languages: generateHreflangUrls(
              `/blog/category/${category.slugs[0]}`
            ),
          },
        });
        
        // 分类分页
        for (let page = 2; page <= totalPages; page++) {
          sitemapList.push({
            url: getUrl(
              `/blog/category/${category.slugs[0]}/page/${page}`,
              locale
            ),
            lastModified: new Date(),
            changeFrequency: 'weekly',
            priority: 0.6,
            alternates: {
              languages: generateHreflangUrls(
                `/blog/category/${category.slugs[0]}/page/${page}`
              ),
            },
          });
        }
      });
    });
    
    // 文章详情页
    routing.locales.forEach((locale) => {
      const posts = blogSource
        .getPages(locale)
        .filter((post) => post.data.published);
      
      posts.forEach((post) => {
        sitemapList.push({
          url: getUrl(`/blog/${post.slugs.join('/')}`, locale),
          lastModified: new Date(post.data.date),
          changeFrequency: 'monthly',
          priority: 0.9,
          alternates: {
            languages: generateHreflangUrls(`/blog/${post.slugs.join('/')}`),
          },
        });
      });
    });
  }
  
  // 3. 添加文档路由
  if (websiteConfig.docs.enable) {
    const docsParams = source.generateParams();
    
    sitemapList.push(
      ...docsParams.flatMap((param) =>
        routing.locales.map((locale) => ({
          url: getUrl(`/docs/${param.slug.join('/')}`, locale),
          lastModified: new Date(),
          changeFrequency: 'weekly' as const,
          priority: 0.8,
          alternates: {
            languages: generateHreflangUrls(`/docs/${param.slug.join('/')}`),
          },
        }))
      )
    );
  }
  
  return sitemapList;
}

function getUrl(href: string, locale: Locale) {
  const pathname = getLocalePathname({ locale, href });
  return getBaseUrl() + pathname;
}
```

### 4. Robots.txt

```typescript
// src/app/robots.ts
import type { MetadataRoute } from 'next';
import { getBaseUrl } from '../lib/urls/urls';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/api/*',
          '/_next/*',
          '/settings/*',
          '/dashboard/*',
          '/admin/*',
          '/auth/*',
        ],
      },
      {
        userAgent: 'GPTBot',
        disallow: ['/'],  // 禁止 AI 爬虫
      },
    ],
    sitemap: `${getBaseUrl()}/sitemap.xml`,
    host: getBaseUrl(),
  };
}
```

## 二、国际化 SEO (Hreflang)

### 1. Hreflang 实现

```typescript
// src/lib/hreflang.ts
import { routing } from '@/i18n/routing';
import type { Locale } from 'next-intl';
import { getUrlWithLocale } from './urls/urls';

/**
 * 获取当前语言的 hreflang 代码
 */
export function getCurrentHreflang(locale: Locale): string {
  const localeConfig = routing.locales.find(l => l === locale);
  
  // 映射到标准的 hreflang 代码
  const hreflangMap: Record<string, string> = {
    en: 'en',
    zh: 'zh-CN',
    ja: 'ja',
    ko: 'ko',
    es: 'es',
    fr: 'fr',
    de: 'de',
  };
  
  return hreflangMap[locale] || locale;
}

/**
 * 生成所有语言的 hreflang URLs
 */
export function generateHreflangUrls(pathname: string): Record<string, string> {
  const urls: Record<string, string> = {};
  
  // 为每个语言生成 URL
  routing.locales.forEach((locale) => {
    const hreflang = getCurrentHreflang(locale);
    urls[hreflang] = getUrlWithLocale(pathname, locale);
  });
  
  // 添加 x-default（通常指向默认语言）
  urls['x-default'] = getUrlWithLocale(pathname, routing.defaultLocale);
  
  return urls;
}

/**
 * 生成 alternates 对象（用于 Next.js metadata）
 */
export function generateAlternates(pathname: string) {
  return {
    languages: generateHreflangUrls(pathname),
  };
}
```

### 2. 页面中使用 Hreflang

```typescript
// src/app/[locale]/layout.tsx
import { constructMetadata } from '@/lib/metadata';

export async function generateMetadata({ params }) {
  return constructMetadata({
    locale: params.locale,
    pathname: '/',
  });
}

// 生成的 HTML 包含:
// <link rel="alternate" hreflang="en" href="https://example.com/en" />
// <link rel="alternate" hreflang="zh-CN" href="https://example.com/zh" />
// <link rel="alternate" hreflang="x-default" href="https://example.com/en" />
```

## 三、结构化数据 (Schema.org)

### 1. 组织结构化数据

```typescript
// src/components/seo/organization-schema.tsx
import { websiteConfig } from '@/config/website';
import { getBaseUrl } from '@/lib/urls/urls';

export function OrganizationSchema() {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'MkSaaS',
    url: getBaseUrl(),
    logo: `${getBaseUrl()}/logo.png`,
    description: 'Make AI SaaS in a weekend',
    sameAs: [
      websiteConfig.metadata.social.twitter,
      websiteConfig.metadata.social.github,
      websiteConfig.metadata.social.discord,
    ],
    contactPoint: {
      '@type': 'ContactPoint',
      email: 'support@mksaas.com',
      contactType: 'Customer Support',
    },
  };
  
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  );
}
```

### 2. 文章结构化数据

```typescript
// src/components/seo/article-schema.tsx
import { getBaseUrl } from '@/lib/urls/urls';

interface ArticleSchemaProps {
  title: string;
  description: string;
  image: string;
  datePublished: string;
  dateModified: string;
  author: string;
  url: string;
}

export function ArticleSchema({
  title,
  description,
  image,
  datePublished,
  dateModified,
  author,
  url,
}: ArticleSchemaProps) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: title,
    description,
    image: `${getBaseUrl()}${image}`,
    datePublished,
    dateModified,
    author: {
      '@type': 'Person',
      name: author,
    },
    publisher: {
      '@type': 'Organization',
      name: 'MkSaaS',
      logo: {
        '@type': 'ImageObject',
        url: `${getBaseUrl()}/logo.png`,
      },
    },
    mainEntityOfPage: {
      '@type': 'WebPage',
      '@id': url,
    },
  };
  
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  );
}
```

### 3. 面包屑结构化数据

```typescript
// src/components/seo/breadcrumb-schema.tsx
import { getBaseUrl } from '@/lib/urls/urls';

interface BreadcrumbItem {
  name: string;
  url: string;
}

interface BreadcrumbSchemaProps {
  items: BreadcrumbItem[];
}

export function BreadcrumbSchema({ items }: BreadcrumbSchemaProps) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: `${getBaseUrl()}${item.url}`,
    })),
  };
  
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  );
}
```

## 四、GEO 优化（地理位置优化）

### 1. 边缘部署

```typescript
// 使用 Vercel Edge Network 或 Cloudflare Workers
// 自动将内容分发到全球边缘节点

// next.config.ts
export default {
  // 启用边缘运行时
  experimental: {
    runtime: 'edge',
  },
};
```

### 2. 地理位置检测

```typescript
// src/middleware.ts
import { NextRequest, NextResponse } from 'next/server';

export function middleware(req: NextRequest) {
  // 获取用户地理位置信息
  const country = req.geo?.country;
  const city = req.geo?.city;
  const region = req.geo?.region;
  
  // 根据地理位置自定义响应
  if (country === 'CN') {
    // 中国用户特殊处理
    // 例如：使用国内 CDN、显示特定内容等
  }
  
  // 添加地理位置头
  const response = NextResponse.next();
  response.headers.set('X-User-Country', country || 'unknown');
  
  return response;
}
```

### 3. 语言自动检测

```typescript
// src/middleware.ts
import { routing } from './i18n/routing';
import { NextRequest } from 'next/server';

export function detectUserLocale(req: NextRequest): string {
  // 1. 检查 Cookie
  const cookieLocale = req.cookies.get('NEXT_LOCALE')?.value;
  if (cookieLocale && routing.locales.includes(cookieLocale)) {
    return cookieLocale;
  }
  
  // 2. 检查 Accept-Language 头
  const acceptLanguage = req.headers.get('accept-language');
  if (acceptLanguage) {
    const preferredLocale = acceptLanguage
      .split(',')[0]
      .split('-')[0];
    
    if (routing.locales.includes(preferredLocale)) {
      return preferredLocale;
    }
  }
  
  // 3. 根据地理位置
  const country = req.geo?.country;
  const countryLocaleMap: Record<string, string> = {
    CN: 'zh',
    TW: 'zh',
    HK: 'zh',
    JP: 'ja',
    KR: 'ko',
    ES: 'es',
    FR: 'fr',
    DE: 'de',
  };
  
  if (country && countryLocaleMap[country]) {
    return countryLocaleMap[country];
  }
  
  // 4. 默认语言
  return routing.defaultLocale;
}
```

### 4. CDN 配置

```typescript
// vercel.json
{
  "regions": ["all"],  // 部署到所有区域
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=3600, s-maxage=86400, stale-while-revalidate"
        }
      ]
    }
  ]
}
```

## 五、性能优化（Core Web Vitals）

### 1. 图片优化

```typescript
// 使用 Next.js Image 组件
import Image from 'next/image';

export function OptimizedImage() {
  return (
    <Image
      src="/hero.jpg"
      alt="Hero image"
      width={1200}
      height={630}
      priority  // 首屏图片优先加载
      placeholder="blur"  // 模糊占位符
      quality={85}  // 质量设置
    />
  );
}
```

### 2. 字体优化

```typescript
// src/app/layout.tsx
import { Inter } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',  // 字体交换策略
  variable: '--font-inter',
  preload: true,
});

export default function RootLayout({ children }) {
  return (
    <html className={inter.variable}>
      <body>{children}</body>
    </html>
  );
}
```

### 3. 代码分割

```typescript
// 动态导入减少初始加载
import dynamic from 'next/dynamic';

const HeavyComponent = dynamic(
  () => import('@/components/heavy-component'),
  {
    loading: () => <div>Loading...</div>,
    ssr: false,  // 仅客户端渲染
  }
);
```

### 4. 预加载关键资源

```typescript
// src/app/layout.tsx
export default function RootLayout({ children }) {
  return (
    <html>
      <head>
        <link
          rel="preconnect"
          href="https://fonts.googleapis.com"
        />
        <link
          rel="dns-prefetch"
          href="https://api.stripe.com"
        />
        <link
          rel="preload"
          href="/hero.jpg"
          as="image"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
```

## 六、内容 SEO 优化

### 1. 标题优化

```typescript
// 标题层级结构
export function BlogPost({ post }) {
  return (
    <article>
      <h1>{post.title}</h1>  {/* 每页只有一个 H1 */}
      
      <section>
        <h2>Section 1</h2>
        <h3>Subsection 1.1</h3>
        <h3>Subsection 1.2</h3>
      </section>
      
      <section>
        <h2>Section 2</h2>
        <h3>Subsection 2.1</h3>
      </section>
    </article>
  );
}
```

### 2. 语义化 HTML

```typescript
export function SemanticPage() {
  return (
    <>
      <header>
        <nav>导航</nav>
      </header>
      
      <main>
        <article>
          <header>
            <h1>文章标题</h1>
            <time dateTime="2024-01-01">2024年1月1日</time>
          </header>
          
          <section>
            <h2>章节标题</h2>
            <p>内容...</p>
          </section>
        </article>
        
        <aside>
          <h2>相关文章</h2>
        </aside>
      </main>
      
      <footer>
        页脚
      </footer>
    </>
  );
}
```

### 3. 内部链接优化

```typescript
// 使用 Next.js Link 组件
import Link from 'next/link';

export function InternalLinks() {
  return (
    <nav>
      <Link href="/blog" prefetch={true}>
        Blog
      </Link>
      <Link href="/docs" prefetch={true}>
        Docs
      </Link>
      <Link href="/pricing" prefetch={false}>
        Pricing
      </Link>
    </nav>
  );
}
```

## 七、移动端优化

### 1. 响应式设计

```typescript
// 使用 Tailwind CSS 响应式类
export function ResponsiveComponent() {
  return (
    <div className="
      px-4 sm:px-6 lg:px-8
      text-base sm:text-lg lg:text-xl
      grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3
    ">
      内容
    </div>
  );
}
```

### 2. Viewport 配置

```typescript
// src/app/layout.tsx
export const viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
  userScalable: true,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#000000' },
  ],
};
```

### 3. 触摸优化

```css
/* 增大点击区域 */
.button {
  min-height: 44px;
  min-width: 44px;
  padding: 12px 24px;
}

/* 禁用点击高亮 */
* {
  -webkit-tap-highlight-color: transparent;
}
```

## 八、安全性 SEO

### 1. HTTPS

```typescript
// 强制 HTTPS 重定向
// next.config.ts
export default {
  async redirects() {
    return [
      {
        source: '/:path*',
        has: [
          {
            type: 'header',
            key: 'x-forwarded-proto',
            value: 'http',
          },
        ],
        destination: 'https://yourdomain.com/:path*',
        permanent: true,
      },
    ];
  },
};
```

### 2. 安全头

```typescript
// next.config.ts
export default {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=63072000; includeSubDomains; preload',
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
          {
            key: 'Permissions-Policy',
            value: 'camera=(), microphone=(), geolocation=()',
          },
        ],
      },
    ];
  },
};
```

## 九、社交媒体优化

### 1. Open Graph 完整配置

```typescript
export const metadata: Metadata = {
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://example.com',
    siteName: 'MkSaaS',
    title: 'Make AI SaaS in a weekend',
    description: 'Complete Next.js boilerplate',
    images: [
      {
        url: 'https://example.com/og.png',
        width: 1200,
        height: 630,
        alt: 'MkSaaS',
        type: 'image/png',
      },
    ],
  },
};
```

### 2. Twitter Card

```typescript
export const metadata: Metadata = {
  twitter: {
    card: 'summary_large_image',
    site: '@mksaascom',
    creator: '@indie_maker_fox',
    title: 'Make AI SaaS in a weekend',
    description: 'Complete Next.js boilerplate',
    images: ['https://example.com/twitter-card.png'],
  },
};
```

### 3. 社交分享按钮

```typescript
// src/components/social-share.tsx
'use client';

export function SocialShare({ url, title }: { url: string; title: string }) {
  const shareUrls = {
    twitter: `https://twitter.com/intent/tweet?url=${encodeURIComponent(url)}&text=${encodeURIComponent(title)}`,
    facebook: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`,
    linkedin: `https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(url)}`,
    reddit: `https://reddit.com/submit?url=${encodeURIComponent(url)}&title=${encodeURIComponent(title)}`,
  };
  
  return (
    <div className="flex gap-2">
      <a href={shareUrls.twitter} target="_blank" rel="noopener noreferrer">
        Twitter
      </a>
      <a href={shareUrls.facebook} target="_blank" rel="noopener noreferrer">
        Facebook
      </a>
      <a href={shareUrls.linkedin} target="_blank" rel="noopener noreferrer">
        LinkedIn
      </a>
    </div>
  );
}
```

## 十、监控和分析

### 1. Google Search Console 集成

```html
<!-- 添加验证标签 -->
<meta name="google-site-verification" content="your-verification-code" />
```

### 2. 性能监控

```typescript
// src/app/layout.tsx
import { SpeedInsights } from '@vercel/speed-insights/next';
import { Analytics } from '@vercel/analytics/react';

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <SpeedInsights />
        <Analytics />
      </body>
    </html>
  );
}
```

### 3. 自定义事件追踪

```typescript
// src/lib/analytics.ts
export function trackEvent(eventName: string, properties?: Record<string, any>) {
  if (typeof window !== 'undefined' && window.gtag) {
    window.gtag('event', eventName, properties);
  }
}

// 使用
trackEvent('button_click', {
  button_name: 'subscribe',
  location: 'hero_section',
});
```

## 十一、最佳实践清单

### SEO 检查清单

```markdown
✅ 元数据
- [ ] 每个页面有唯一的 title
- [ ] 每个页面有描述性的 description
- [ ] 使用合适的 keywords
- [ ] 配置 Open Graph 标签
- [ ] 配置 Twitter Card

✅ 内容
- [ ] 每页只有一个 H1
- [ ] 使用语义化 HTML
- [ ] 图片有 alt 属性
- [ ] 内部链接优化
- [ ] 内容原创且有价值

✅ 技术
- [ ] 生成 sitemap.xml
- [ ] 配置 robots.txt
- [ ] 实现 hreflang 标签
- [ ] HTTPS 启用
- [ ] 移动端友好

✅ 性能
- [ ] Core Web Vitals 优化
- [ ] 图片优化
- [ ] 代码分割
- [ ] 缓存策略
- [ ] CDN 使用

✅ 结构化数据
- [ ] Organization schema
- [ ] Article schema
- [ ] Breadcrumb schema
- [ ] FAQ schema (如适用)
- [ ] Product schema (如适用)
```

## 十二、常见问题

### 1. 如何检查 SEO 效果？

使用以下工具：
- Google Search Console
- Google PageSpeed Insights
- Lighthouse
- Ahrefs
- SEMrush

### 2. 多久能看到 SEO 效果？

- 技术 SEO：1-2周
- 内容 SEO：1-3个月
- 链接建设：3-6个月

### 3. 如何提高排名？

- 创建高质量内容
- 优化页面速度
- 获取高质量外链
- 改善用户体验
- 定期更新内容

## 总结

MkSaaS 的 SEO 和 GEO 优化策略：

1. **完整的元数据系统**: 自动生成优化的元数据
2. **动态 Sitemap**: 自动包含所有页面和多语言版本
3. **国际化 SEO**: 完整的 hreflang 实现
4. **结构化数据**: Schema.org 标记
5. **性能优化**: Core Web Vitals 优化
6. **地理位置优化**: 边缘部署和自动语言检测
7. **移动端优化**: 响应式设计和触摸优化
8. **安全性**: HTTPS 和安全头配置
9. **社交媒体**: Open Graph 和 Twitter Card
10. **监控分析**: 完整的分析和追踪

通过这些策略，确保网站在搜索引擎中获得最佳排名和全球用户的优质体验。
