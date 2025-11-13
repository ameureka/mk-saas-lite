# 问题16：关于营销的 SEO 优化甚至是 GEO 优化的逻辑在设计之前就融入到对现有的体系设计之中

## 概述

MkSaaS 从架构设计之初就深度集成了 SEO 和 GEO（地理位置）优化，利用 Next.js 15 的强大功能和现代化的 SEO 最佳实践，确保网站在搜索引擎中获得最佳排名和全球用户的最佳体验。

## 一、SEO 架构设计

### 1. Next.js SEO 优势

MkSaaS 基于 Next.js 15，天然具备 SEO 优势：

```
SEO 优势:
├── Server-Side Rendering (SSR)
│   └── 完整的 HTML 内容供爬虫抓取
├── Static Site Generation (SSG)
│   └── 预渲染页面，极快加载速度
├── Incremental Static Regeneration (ISR)
│   └── 动态更新静态内容
├── 自动代码分割
│   └── 优化页面加载性能
└── 内置图片优化
    └── 自动 WebP 转换和懒加载
```

### 2. 元数据管理系统

#### 统一的元数据生成

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
  
  const ogImageUrl = getImageUrl(image || '');
  
  // 生成规范 URL
  const canonicalUrl = locale
    ? getUrlWithLocale(pathname || '', locale).replace(/\/$/, '')
    : undefined;
  
  // 生成 hreflang 替代链接
  const alternates = pathname && routing.locales.length > 1
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
    
    // Open Graph
    openGraph: {
      type: 'website',
      locale: locale ? getCurrentHreflang(locale).replace('-', '_') : 'en_US',
      url: canonicalUrl,
      title,
      description,
      siteName: defaultMessages.Metadata.name,
      images: [ogImageUrl.toString()],
    },
    
    // Twitter Card
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [ogImageUrl.toString()],
      site: getBaseUrl(),
    },
    
    // 图标
    icons: {
      icon: '/favicon.ico',
      shortcut: '/favicon-32x32.png',
      apple: '/apple-touch-icon.png',
    },
    
    metadataBase: new URL(getBaseUrl()),
    manifest: `${getBaseUrl()}/manifest.webmanifest`,
    
    // 控制索引
    ...(noIndex && {
      robots: {
        index: false,
        follow: false,
      },
    }),
  };
}
```

#### 页面级元数据

```typescript
// src/app/[locale]/(marketing)/blog/[...slug]/page.tsx
import { constructMetadata } from '@/lib/metadata';
import type { Metadata } from 'next';

export async function generateMetadata({ 
  params 
}): Promise<Metadata> {
  const post = await getPost(params.slug);
  
  return constructMetadata({
    title: post.data.title,
    description: post.data.description,
    image: post.data.image,
    locale: params.locale,
    pathname: `/blog/${params.slug.join('/')}`,
  });
}

export default function BlogPostPage({ params }) {
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

// 静态路由
const staticRoutes = [
  '/',
  '/about',
  ...(websiteConfig.blog.enable ? ['/blog'] : []),
  ...(websiteConfig.docs.enable ? ['/docs'] : []),
];

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const sitemapList: MetadataRoute.Sitemap = [];
  
  // 1. 添加静态路由
  sitemapList.push(
    ...staticRoutes.flatMap((route) => {
      return routing.locales.map((locale) => ({
        url: getUrl(route, locale),
        alternates: {
          languages: generateHreflangUrls(route),
        },
        lastModified: new Date(),
        changeFrequency: 'weekly' as const,
        priority: route === '/' ? 1.0 : 0.8,
      }));
    })
  );
  
  // 2. 添加博客文章
  if (websiteConfig.blog.enable) {
    routing.locales.forEach((locale) => {
      const posts = blogSource
        .getPages(locale)
        .filter((post) => post.data.published);
      
      posts.forEach((post) => {
        sitemapList.push({
          url: getUrl(`/blog/${post.slugs.join('/')}`, locale),
          alternates: {
            languages: generateHreflangUrls(`/blog/${post.slugs.join('/')}`),
          },
          lastModified: new Date(post.data.date),
          changeFrequency: 'monthly' as const,
          priority: 0.7,
        });
      });
    });
    
    // 3. 添加分类页面
    routing.locales.forEach((locale) => {
      const categories = categorySource.getPages(locale);
      
      categories.forEach((category) => {
        sitemapList.push({
          url: getUrl(`/blog/category/${category.slugs[0]}`, locale),
          alternates: {
            languages: generateHreflangUrls(
              `/blog/category/${category.slugs[0]}`
            ),
          },
          lastModified: new Date(),
          changeFrequency: 'weekly' as const,
          priority: 0.6,
        });
      });
    });
  }
  
  // 4. 添加文档页面
  if (websiteConfig.docs.enable) {
    const docsParams = source.generateParams();
    
    sitemapList.push(
      ...docsParams.flatMap((param) =>
        routing.locales.map((locale) => ({
          url: getUrl(`/docs/${param.slug.join('/')}`, locale),
          alternates: {
            languages: generateHreflangUrls(`/docs/${param.slug.join('/')}`),
          },
          lastModified: new Date(),
          changeFrequency: 'weekly' as const,
          priority: 0.7,
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
      // 特定爬虫规则
      {
        userAgent: 'Googlebot',
        allow: '/',
        disallow: ['/api/*', '/_next/*'],
      },
    ],
    sitemap: `${getBaseUrl()}/sitemap.xml`,
  };
}
```

## 二、国际化 SEO (Hreflang)

### 1. Hreflang 标签生成

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
  
  // 映射到标准 hreflang 代码
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
  const hreflangUrls: Record<string, string> = {};
  
  // 为每个语言生成 URL
  routing.locales.forEach((locale) => {
    const hreflang = getCurrentHreflang(locale);
    const url = getUrlWithLocale(pathname, locale);
    hreflangUrls[hreflang] = url;
  });
  
  // 添加 x-default（通常指向默认语言）
  hreflangUrls['x-default'] = getUrlWithLocale(
    pathname,
    routing.defaultLocale
  );
  
  return hreflangUrls;
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

### 2. 语言切换器

```typescript
// src/components/layout/locale-switcher.tsx
'use client';

import { useLocale } from 'next-intl';
import { usePathname, useRouter } from '@/i18n/navigation';
import { routing } from '@/i18n/routing';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

export function LocaleSwitcher() {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  
  const handleChange = (newLocale: string) => {
    router.replace(pathname, { locale: newLocale });
  };
  
  return (
    <Select value={locale} onValueChange={handleChange}>
      <SelectTrigger className="w-[140px]">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {routing.locales.map((loc) => (
          <SelectItem key={loc} value={loc}>
            <span className="mr-2">
              {routing.locales[loc]?.flag}
            </span>
            {routing.locales[loc]?.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
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

### 3. 面包屑导航

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

MkSaaS 支持全球边缘部署：

```typescript
// Vercel 自动边缘部署
// 或 Cloudflare Workers 全球分布

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
// src/lib/geo/location.ts
import { headers } from 'next/headers';

export interface GeoLocation {
  country: string;
  region: string;
  city: string;
  timezone: string;
  currency: string;
  language: string;
}

/**
 * 从请求头获取地理位置信息
 */
export async function getGeoLocation(): Promise<GeoLocation | null> {
  const headersList = headers();
  
  // Vercel 提供的地理位置头
  const country = headersList.get('x-vercel-ip-country') || '';
  const region = headersList.get('x-vercel-ip-country-region') || '';
  const city = headersList.get('x-vercel-ip-city') || '';
  const timezone = headersList.get('x-vercel-ip-timezone') || '';
  
  // Cloudflare 提供的地理位置头
  const cfCountry = headersList.get('cf-ipcountry') || '';
  const cfTimezone = headersList.get('cf-timezone') || '';
  
  if (!country && !cfCountry) {
    return null;
  }
  
  return {
    country: country || cfCountry,
    region,
    city,
    timezone: timezone || cfTimezone,
    currency: getCurrencyByCountry(country || cfCountry),
    language: getLanguageByCountry(country || cfCountry),
  };
}

/**
 * 根据国家获取货币
 */
function getCurrencyByCountry(country: string): string {
  const currencyMap: Record<string, string> = {
    US: 'USD',
    CN: 'CNY',
    JP: 'JPY',
    GB: 'GBP',
    EU: 'EUR',
    // ... 更多国家
  };
  
  return currencyMap[country] || 'USD';
}

/**
 * 根据国家获取语言
 */
function getLanguageByCountry(country: string): string {
  const languageMap: Record<string, string> = {
    US: 'en',
    CN: 'zh',
    JP: 'ja',
    KR: 'ko',
    // ... 更多国家
  };
  
  return languageMap[country] || 'en';
}
```

### 3. 自动语言重定向

```typescript
// src/middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { getGeoLocation } from '@/lib/geo/location';
import { routing } from '@/i18n/routing';

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  
  // 检查是否已经有语言前缀
  const hasLocale = routing.locales.some(locale =>
    pathname.startsWith(`/${locale}`)
  );
  
  if (!hasLocale && pathname === '/') {
    // 获取地理位置
    const geo = await getGeoLocation();
    
    if (geo) {
      // 根据地理位置推荐语言
      const suggestedLocale = geo.language;
      
      // 检查是否支持该语言
      if (routing.locales.includes(suggestedLocale)) {
        return NextResponse.redirect(
          new URL(`/${suggestedLocale}`, req.url)
        );
      }
    }
  }
  
  return NextResponse.next();
}
```

### 4. 地理位置定价

```typescript
// src/lib/pricing/geo-pricing.ts
import { getGeoLocation } from '@/lib/geo/location';

interface GeoPricing {
  currency: string;
  symbol: string;
  multiplier: number;
}

const geoPricingMap: Record<string, GeoPricing> = {
  US: { currency: 'USD', symbol: '$', multiplier: 1.0 },
  CN: { currency: 'CNY', symbol: '¥', multiplier: 7.0 },
  EU: { currency: 'EUR', symbol: '€', multiplier: 0.9 },
  GB: { currency: 'GBP', symbol: '£', multiplier: 0.8 },
  JP: { currency: 'JPY', symbol: '¥', multiplier: 140.0 },
};

export async function getLocalizedPrice(basePrice: number): Promise<{
  amount: number;
  currency: string;
  symbol: string;
  formatted: string;
}> {
  const geo = await getGeoLocation();
  const country = geo?.country || 'US';
  
  const pricing = geoPricingMap[country] || geoPricingMap.US;
  const amount = Math.round(basePrice * pricing.multiplier);
  
  return {
    amount,
    currency: pricing.currency,
    symbol: pricing.symbol,
    formatted: `${pricing.symbol}${amount.toFixed(2)}`,
  };
}
```
