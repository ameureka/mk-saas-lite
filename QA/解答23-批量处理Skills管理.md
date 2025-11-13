# 问题23：批量处理 Skills 的使用和管理

## 概述

MkSaaS 提供了完整的 Skills（技能/标签）管理系统，支持批量创建、更新、导入导出等操作。Skills 系统用于内容分类、用户技能标记、搜索优化等多个场景。

## 一、Skills 数据模型

### 1. 数据库模式

```typescript
// src/db/schema.ts
export const skills = pgTable('skills', {
  id: text('id').primaryKey().$defaultFn(() => nanoid()),
  name: text('name').notNull().unique(),
  slug: text('slug').notNull().unique(),
  description: text('description'),
  category: text('category'), // 技能分类
  icon: text('icon'), // 图标
  color: text('color'), // 颜色标识
  level: integer('level').default(1), // 难度等级 1-5
  popularity: integer('popularity').default(0), // 热度
  verified: boolean('verified').default(false), // 是否认证
  metadata: jsonb('metadata'), // 额外元数据
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

// 内容与技能关联
export const contentSkills = pgTable('content_skills', {
  id: text('id').primaryKey().$defaultFn(() => nanoid()),
  contentId: text('content_id').notNull(),
  skillId: text('skill_id').notNull().references(() => skills.id, {
    onDelete: 'cascade',
  }),
  relevance: integer('relevance').default(100), // 相关度 0-100
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

// 用户技能
export const userSkills = pgTable('user_skills', {
  id: text('id').primaryKey().$defaultFn(() => nanoid()),
  userId: text('user_id').notNull().references(() => users.id, {
    onDelete: 'cascade',
  }),
  skillId: text('skill_id').notNull().references(() => skills.id, {
    onDelete: 'cascade',
  }),
  level: integer('level').default(1), // 熟练度 1-5
  yearsOfExperience: integer('years_of_experience'),
  verified: boolean('verified').default(false),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

// 索引
export const skillsIndex = index('skills_name_idx').on(skills.name);
export const skillsSlugIndex = index('skills_slug_idx').on(skills.slug);
export const skillsCategoryIndex = index('skills_category_idx').on(skills.category);
```

### 2. TypeScript 类型

```typescript
// src/types/skills.ts
export interface Skill {
  id: string;
  name: string;
  slug: string;
  description?: string;
  category?: string;
  icon?: string;
  color?: string;
  level?: number;
  popularity: number;
  verified: boolean;
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

export interface SkillWithStats extends Skill {
  contentCount: number;
  userCount: number;
  trendingScore: number;
}

export interface UserSkill {
  id: string;
  userId: string;
  skillId: string;
  skill: Skill;
  level: number;
  yearsOfExperience?: number;
  verified: boolean;
}
```

## 二、批量创建 Skills

### 1. 批量创建 API

```typescript
// src/app/api/skills/batch/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/lib/auth';
import { db } from '@/db';
import { skills } from '@/db/schema';
import { slugify } from '@/lib/utils';

export async function POST(req: NextRequest) {
  const session = await auth();
  
  if (!session?.user?.isAdmin) {
    return new NextResponse('Unauthorized', { status: 403 });
  }
  
  const { skills: skillsData } = await req.json();
  
  if (!Array.isArray(skillsData) || skillsData.length === 0) {
    return new NextResponse('Invalid data', { status: 400 });
  }
  
  try {
    // 批量插入
    const result = await db.insert(skills).values(
      skillsData.map((skill) => ({
        name: skill.name,
        slug: skill.slug || slugify(skill.name),
        description: skill.description,
        category: skill.category,
        icon: skill.icon,
        color: skill.color,
        level: skill.level || 1,
        verified: skill.verified || false,
        metadata: skill.metadata,
      }))
    ).onConflictDoNothing(); // 忽略重复
    
    return NextResponse.json({
      success: true,
      count: result.rowCount,
    });
  } catch (error) {
    console.error('Batch create skills error:', error);
    return new NextResponse('Internal error', { status: 500 });
  }
}
```

### 2. 批量创建服务

```typescript
// src/lib/skills/batch.ts
export async function batchCreateSkills(skillsData: Partial<Skill>[]) {
  const BATCH_SIZE = 100;
  const batches = chunk(skillsData, BATCH_SIZE);
  
  const results = [];
  
  for (const batch of batches) {
    const result = await db.insert(skills).values(
      batch.map((skill) => ({
        name: skill.name!,
        slug: skill.slug || slugify(skill.name!),
        description: skill.description,
        category: skill.category,
        icon: skill.icon,
        color: skill.color,
        level: skill.level || 1,
        verified: skill.verified || false,
        metadata: skill.metadata,
      }))
    ).onConflictDoNothing().returning();
    
    results.push(...result);
  }
  
  return results;
}
```

### 3. 从 CSV 导入

```typescript
// src/lib/skills/import.ts
import { parse } from 'csv-parse/sync';

export async function importSkillsFromCSV(csvContent: string) {
  // 解析 CSV
  const records = parse(csvContent, {
    columns: true,
    skip_empty_lines: true,
  });
  
  // 转换数据
  const skillsData = records.map((record: any) => ({
    name: record.name,
    slug: record.slug || slugify(record.name),
    description: record.description,
    category: record.category,
    icon: record.icon,
    color: record.color,
    level: parseInt(record.level) || 1,
    verified: record.verified === 'true',
  }));
  
  // 批量创建
  return batchCreateSkills(skillsData);
}

// 使用示例
export async function handleCSVUpload(file: File) {
  const content = await file.text();
  const result = await importSkillsFromCSV(content);
  
  return {
    success: true,
    imported: result.length,
  };
}
```

### 4. 从 JSON 导入

```typescript
// src/lib/skills/import-json.ts
export async function importSkillsFromJSON(jsonContent: string) {
  const data = JSON.parse(jsonContent);
  
  if (!Array.isArray(data)) {
    throw new Error('Invalid JSON format');
  }
  
  return batchCreateSkills(data);
}

// 从 API 导入
export async function importSkillsFromAPI(apiUrl: string) {
  const response = await fetch(apiUrl);
  const data = await response.json();
  
  return batchCreateSkills(data.skills || data);
}
```

## 三、批量更新 Skills

### 1. 批量更新 API

```typescript
// src/app/api/skills/batch-update/route.ts
export async function PATCH(req: NextRequest) {
  const session = await auth();
  
  if (!session?.user?.isAdmin) {
    return new NextResponse('Unauthorized', { status: 403 });
  }
  
  const { updates } = await req.json();
  
  if (!Array.isArray(updates) || updates.length === 0) {
    return new NextResponse('Invalid data', { status: 400 });
  }
  
  try {
    // 批量更新
    const results = await Promise.all(
      updates.map((update) =>
        db.update(skills)
          .set({
            ...update.data,
            updatedAt: new Date(),
          })
          .where(eq(skills.id, update.id))
      )
    );
    
    return NextResponse.json({
      success: true,
      updated: results.length,
    });
  } catch (error) {
    console.error('Batch update skills error:', error);
    return new NextResponse('Internal error', { status: 500 });
  }
}
```

### 2. 批量更新服务

```typescript
// src/lib/skills/batch-update.ts
export async function batchUpdateSkills(
  updates: Array<{ id: string; data: Partial<Skill> }>
) {
  const BATCH_SIZE = 50;
  const batches = chunk(updates, BATCH_SIZE);
  
  for (const batch of batches) {
    await Promise.all(
      batch.map((update) =>
        db.update(skills)
          .set({
            ...update.data,
            updatedAt: new Date(),
          })
          .where(eq(skills.id, update.id))
      )
    );
  }
}

// 批量更新分类
export async function batchUpdateCategory(
  skillIds: string[],
  category: string
) {
  return db.update(skills)
    .set({ category, updatedAt: new Date() })
    .where(inArray(skills.id, skillIds));
}

// 批量验证
export async function batchVerifySkills(skillIds: string[]) {
  return db.update(skills)
    .set({ verified: true, updatedAt: new Date() })
    .where(inArray(skills.id, skillIds));
}
```

## 四、批量删除 Skills

### 1. 批量删除 API

```typescript
// src/app/api/skills/batch-delete/route.ts
export async function DELETE(req: NextRequest) {
  const session = await auth();
  
  if (!session?.user?.isAdmin) {
    return new NextResponse('Unauthorized', { status: 403 });
  }
  
  const { ids } = await req.json();
  
  if (!Array.isArray(ids) || ids.length === 0) {
    return new NextResponse('Invalid data', { status: 400 });
  }
  
  try {
    // 批量删除
    const result = await db.delete(skills)
      .where(inArray(skills.id, ids));
    
    return NextResponse.json({
      success: true,
      deleted: result.rowCount,
    });
  } catch (error) {
    console.error('Batch delete skills error:', error);
    return new NextResponse('Internal error', { status: 500 });
  }
}
```

### 2. 安全删除

```typescript
// src/lib/skills/batch-delete.ts
export async function safeDeleteSkills(skillIds: string[]) {
  // 检查是否有关联内容
  const contentCount = await db
    .select({ count: count() })
    .from(contentSkills)
    .where(inArray(contentSkills.skillId, skillIds));
  
  if (contentCount[0].count > 0) {
    throw new Error('Cannot delete skills with associated content');
  }
  
  // 检查是否有关联用户
  const userCount = await db
    .select({ count: count() })
    .from(userSkills)
    .where(inArray(userSkills.skillId, skillIds));
  
  if (userCount[0].count > 0) {
    throw new Error('Cannot delete skills with associated users');
  }
  
  // 执行删除
  return db.delete(skills).where(inArray(skills.id, skillIds));
}

// 强制删除（包括关联数据）
export async function forceDeleteSkills(skillIds: string[]) {
  // 删除关联的内容技能
  await db.delete(contentSkills)
    .where(inArray(contentSkills.skillId, skillIds));
  
  // 删除关联的用户技能
  await db.delete(userSkills)
    .where(inArray(userSkills.skillId, skillIds));
  
  // 删除技能
  return db.delete(skills).where(inArray(skills.id, skillIds));
}
```

## 五、批量导出 Skills

### 1. 导出为 CSV

```typescript
// src/lib/skills/export.ts
import { stringify } from 'csv-stringify/sync';

export async function exportSkillsToCSV(filters?: SkillFilters) {
  // 查询技能
  let query = db.select().from(skills);
  
  if (filters?.category) {
    query = query.where(eq(skills.category, filters.category));
  }
  
  const skillsData = await query;
  
  // 转换为 CSV
  const csv = stringify(skillsData, {
    header: true,
    columns: [
      'id',
      'name',
      'slug',
      'description',
      'category',
      'icon',
      'color',
      'level',
      'popularity',
      'verified',
    ],
  });
  
  return csv;
}
```


### 2. 导出为 JSON

```typescript
export async function exportSkillsToJSON(filters?: SkillFilters) {
  let query = db.select().from(skills);
  
  if (filters?.category) {
    query = query.where(eq(skills.category, filters.category));
  }
  
  const skillsData = await query;
  
  return JSON.stringify(skillsData, null, 2);
}

// 导出带统计信息
export async function exportSkillsWithStats() {
  const skillsWithStats = await db
    .select({
      skill: skills,
      contentCount: count(contentSkills.id),
      userCount: count(userSkills.id),
    })
    .from(skills)
    .leftJoin(contentSkills, eq(skills.id, contentSkills.skillId))
    .leftJoin(userSkills, eq(skills.id, userSkills.skillId))
    .groupBy(skills.id);
  
  return JSON.stringify(skillsWithStats, null, 2);
}
```

### 3. 导出 API

```typescript
// src/app/api/skills/export/route.ts
export async function GET(req: NextRequest) {
  const session = await auth();
  
  if (!session?.user?.isAdmin) {
    return new NextResponse('Unauthorized', { status: 403 });
  }
  
  const format = req.nextUrl.searchParams.get('format') || 'json';
  const category = req.nextUrl.searchParams.get('category');
  
  try {
    let content: string;
    let contentType: string;
    let filename: string;
    
    if (format === 'csv') {
      content = await exportSkillsToCSV({ category });
      contentType = 'text/csv';
      filename = 'skills.csv';
    } else {
      content = await exportSkillsToJSON({ category });
      contentType = 'application/json';
      filename = 'skills.json';
    }
    
    return new NextResponse(content, {
      headers: {
        'Content-Type': contentType,
        'Content-Disposition': `attachment; filename="${filename}"`,
      },
    });
  } catch (error) {
    console.error('Export skills error:', error);
    return new NextResponse('Internal error', { status: 500 });
  }
}
```

## 六、Skills 管理界面

### 1. 批量操作组件

```typescript
// src/components/admin/skills-batch-actions.tsx
'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

interface SkillsBatchActionsProps {
  skills: Skill[];
  onUpdate: () => void;
}

export function SkillsBatchActions({ skills, onUpdate }: SkillsBatchActionsProps) {
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  
  const handleSelectAll = () => {
    if (selectedIds.length === skills.length) {
      setSelectedIds([]);
    } else {
      setSelectedIds(skills.map(s => s.id));
    }
  };
  
  const handleBatchDelete = async () => {
    if (!confirm(`确定要删除 ${selectedIds.length} 个技能吗？`)) {
      return;
    }
    
    await fetch('/api/skills/batch-delete', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ids: selectedIds }),
    });
    
    setSelectedIds([]);
    onUpdate();
  };
  
  const handleBatchVerify = async () => {
    await fetch('/api/skills/batch-update', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        updates: selectedIds.map(id => ({
          id,
          data: { verified: true },
        })),
      }),
    });
    
    setSelectedIds([]);
    onUpdate();
  };
  
  const handleBatchCategory = async (category: string) => {
    await fetch('/api/skills/batch-update', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        updates: selectedIds.map(id => ({
          id,
          data: { category },
        })),
      }),
    });
    
    setSelectedIds([]);
    onUpdate();
  };
  
  return (
    <div className="flex items-center gap-4">
      <Checkbox
        checked={selectedIds.length === skills.length}
        onCheckedChange={handleSelectAll}
      />
      
      {selectedIds.length > 0 && (
        <>
          <span className="text-sm text-muted-foreground">
            已选择 {selectedIds.length} 项
          </span>
          
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="sm">
                批量操作
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent>
              <DropdownMenuItem onClick={handleBatchVerify}>
                批量验证
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => handleBatchCategory('frontend')}>
                设为前端
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => handleBatchCategory('backend')}>
                设为后端
              </DropdownMenuItem>
              <DropdownMenuItem onClick={handleBatchDelete} className="text-red-600">
                批量删除
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </>
      )}
    </div>
  );
}
```

### 2. 导入组件

```typescript
// src/components/admin/skills-import.tsx
'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Upload } from 'lucide-react';

export function SkillsImport({ onImport }: { onImport: () => void }) {
  const [isUploading, setIsUploading] = useState(false);
  
  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    setIsUploading(true);
    
    try {
      const formData = new FormData();
      formData.append('file', file);
      
      const response = await fetch('/api/skills/import', {
        method: 'POST',
        body: formData,
      });
      
      if (response.ok) {
        const result = await response.json();
        alert(`成功导入 ${result.imported} 个技能`);
        onImport();
      } else {
        alert('导入失败');
      }
    } catch (error) {
      console.error('Import error:', error);
      alert('导入失败');
    } finally {
      setIsUploading(false);
    }
  };
  
  return (
    <div className="flex items-center gap-4">
      <Input
        type="file"
        accept=".csv,.json"
        onChange={handleFileUpload}
        disabled={isUploading}
      />
      <Button disabled={isUploading}>
        <Upload className="mr-2 h-4 w-4" />
        {isUploading ? '导入中...' : '导入技能'}
      </Button>
    </div>
  );
}
```

### 3. 导出组件

```typescript
// src/components/admin/skills-export.tsx
'use client';

import { Button } from '@/components/ui/button';
import { Download } from 'lucide-react';

export function SkillsExport() {
  const handleExport = async (format: 'csv' | 'json') => {
    const response = await fetch(`/api/skills/export?format=${format}`);
    const blob = await response.blob();
    
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `skills.${format}`;
    a.click();
    
    window.URL.revokeObjectURL(url);
  };
  
  return (
    <div className="flex gap-2">
      <Button variant="outline" onClick={() => handleExport('csv')}>
        <Download className="mr-2 h-4 w-4" />
        导出 CSV
      </Button>
      <Button variant="outline" onClick={() => handleExport('json')}>
        <Download className="mr-2 h-4 w-4" />
        导出 JSON
      </Button>
    </div>
  );
}
```

## 七、Skills 搜索与过滤

### 1. 高级搜索

```typescript
// src/lib/skills/search.ts
export interface SkillSearchParams {
  query?: string;
  category?: string;
  level?: number;
  verified?: boolean;
  minPopularity?: number;
  sortBy?: 'name' | 'popularity' | 'createdAt';
  sortOrder?: 'asc' | 'desc';
  limit?: number;
  offset?: number;
}

export async function searchSkills(params: SkillSearchParams) {
  let query = db.select().from(skills);
  
  // 文本搜索
  if (params.query) {
    query = query.where(
      or(
        ilike(skills.name, `%${params.query}%`),
        ilike(skills.description, `%${params.query}%`)
      )
    );
  }
  
  // 分类过滤
  if (params.category) {
    query = query.where(eq(skills.category, params.category));
  }
  
  // 等级过滤
  if (params.level) {
    query = query.where(eq(skills.level, params.level));
  }
  
  // 验证状态过滤
  if (params.verified !== undefined) {
    query = query.where(eq(skills.verified, params.verified));
  }
  
  // 热度过滤
  if (params.minPopularity) {
    query = query.where(gte(skills.popularity, params.minPopularity));
  }
  
  // 排序
  const sortField = params.sortBy || 'name';
  const sortOrder = params.sortOrder || 'asc';
  query = query.orderBy(
    sortOrder === 'asc' ? asc(skills[sortField]) : desc(skills[sortField])
  );
  
  // 分页
  if (params.limit) {
    query = query.limit(params.limit);
  }
  if (params.offset) {
    query = query.offset(params.offset);
  }
  
  return query;
}
```

### 2. 全文搜索

```typescript
// src/lib/skills/full-text-search.ts
export async function fullTextSearchSkills(query: string) {
  // 使用 PostgreSQL 全文搜索
  const results = await db.execute(sql`
    SELECT *,
      ts_rank(
        to_tsvector('english', name || ' ' || COALESCE(description, '')),
        plainto_tsquery('english', ${query})
      ) AS rank
    FROM skills
    WHERE to_tsvector('english', name || ' ' || COALESCE(description, ''))
      @@ plainto_tsquery('english', ${query})
    ORDER BY rank DESC
    LIMIT 50
  `);
  
  return results.rows;
}
```

## 八、Skills 统计与分析

### 1. 统计服务

```typescript
// src/lib/skills/analytics.ts
export async function getSkillsStatistics() {
  const [total, byCategory, byLevel, trending] = await Promise.all([
    // 总数
    db.select({ count: count() }).from(skills),
    
    // 按分类统计
    db.select({
      category: skills.category,
      count: count(),
    })
      .from(skills)
      .groupBy(skills.category),
    
    // 按等级统计
    db.select({
      level: skills.level,
      count: count(),
    })
      .from(skills)
      .groupBy(skills.level),
    
    // 热门技能
    db.select()
      .from(skills)
      .orderBy(desc(skills.popularity))
      .limit(10),
  ]);
  
  return {
    total: total[0].count,
    byCategory,
    byLevel,
    trending,
  };
}

// 获取技能使用趋势
export async function getSkillTrends(skillId: string, days: number = 30) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  
  const trends = await db
    .select({
      date: sql<string>`DATE(${contentSkills.createdAt})`,
      count: count(),
    })
    .from(contentSkills)
    .where(
      and(
        eq(contentSkills.skillId, skillId),
        gte(contentSkills.createdAt, startDate)
      )
    )
    .groupBy(sql`DATE(${contentSkills.createdAt})`)
    .orderBy(sql`DATE(${contentSkills.createdAt})`);
  
  return trends;
}
```

### 2. 热度计算

```typescript
// src/lib/skills/popularity.ts
export async function updateSkillPopularity(skillId: string) {
  // 计算热度分数
  const [contentCount, userCount, recentActivity] = await Promise.all([
    // 内容数量
    db.select({ count: count() })
      .from(contentSkills)
      .where(eq(contentSkills.skillId, skillId)),
    
    // 用户数量
    db.select({ count: count() })
      .from(userSkills)
      .where(eq(userSkills.skillId, skillId)),
    
    // 最近30天活动
    db.select({ count: count() })
      .from(contentSkills)
      .where(
        and(
          eq(contentSkills.skillId, skillId),
          gte(contentSkills.createdAt, new Date(Date.now() - 30 * 24 * 60 * 60 * 1000))
        )
      ),
  ]);
  
  // 计算热度分数
  const popularity = 
    contentCount[0].count * 10 +
    userCount[0].count * 5 +
    recentActivity[0].count * 20;
  
  // 更新热度
  await db.update(skills)
    .set({ popularity, updatedAt: new Date() })
    .where(eq(skills.id, skillId));
  
  return popularity;
}

// 批量更新所有技能热度
export async function updateAllSkillsPopularity() {
  const allSkills = await db.select({ id: skills.id }).from(skills);
  
  for (const skill of allSkills) {
    await updateSkillPopularity(skill.id);
  }
}
```

## 九、Skills 推荐系统

### 1. 相关技能推荐

```typescript
// src/lib/skills/recommendations.ts
export async function getRelatedSkills(skillId: string, limit: number = 5) {
  // 查找经常一起使用的技能
  const related = await db
    .select({
      skillId: contentSkills.skillId,
      skill: skills,
      count: count(),
    })
    .from(contentSkills)
    .innerJoin(skills, eq(contentSkills.skillId, skills.id))
    .where(
      and(
        ne(contentSkills.skillId, skillId),
        inArray(
          contentSkills.contentId,
          db.select({ contentId: contentSkills.contentId })
            .from(contentSkills)
            .where(eq(contentSkills.skillId, skillId))
        )
      )
    )
    .groupBy(contentSkills.skillId, skills.id)
    .orderBy(desc(count()))
    .limit(limit);
  
  return related;
}

// 为用户推荐技能
export async function recommendSkillsForUser(userId: string, limit: number = 10) {
  // 获取用户已有技能
  const userSkillIds = await db
    .select({ skillId: userSkills.skillId })
    .from(userSkills)
    .where(eq(userSkills.userId, userId));
  
  const userSkillIdList = userSkillIds.map(s => s.skillId);
  
  // 推荐相关技能
  const recommended = await db
    .select({
      skill: skills,
      relevance: count(),
    })
    .from(contentSkills)
    .innerJoin(skills, eq(contentSkills.skillId, skills.id))
    .where(
      and(
        notInArray(skills.id, userSkillIdList),
        inArray(
          contentSkills.contentId,
          db.select({ contentId: contentSkills.contentId })
            .from(contentSkills)
            .where(inArray(contentSkills.skillId, userSkillIdList))
        )
      )
    )
    .groupBy(skills.id)
    .orderBy(desc(count()))
    .limit(limit);
  
  return recommended;
}
```

## 十、定时任务

### 1. 定时更新热度

```typescript
// src/lib/cron/update-skills-popularity.ts
import { CronJob } from 'cron';

// 每天凌晨2点更新所有技能热度
export const updateSkillsPopularityJob = new CronJob(
  '0 2 * * *',
  async () => {
    console.log('Starting skills popularity update...');
    
    try {
      await updateAllSkillsPopularity();
      console.log('Skills popularity updated successfully');
    } catch (error) {
      console.error('Failed to update skills popularity:', error);
    }
  },
  null,
  true,
  'Asia/Shanghai'
);
```

### 2. 清理未使用的技能

```typescript
// src/lib/cron/cleanup-unused-skills.ts
export const cleanupUnusedSkillsJob = new CronJob(
  '0 3 * * 0', // 每周日凌晨3点
  async () => {
    console.log('Starting unused skills cleanup...');
    
    try {
      // 查找未使用的技能（无内容、无用户、创建超过30天）
      const unusedSkills = await db
        .select({ id: skills.id })
        .from(skills)
        .leftJoin(contentSkills, eq(skills.id, contentSkills.skillId))
        .leftJoin(userSkills, eq(skills.id, userSkills.skillId))
        .where(
          and(
            isNull(contentSkills.id),
            isNull(userSkills.id),
            lt(skills.createdAt, new Date(Date.now() - 30 * 24 * 60 * 60 * 1000))
          )
        );
      
      if (unusedSkills.length > 0) {
        await db.delete(skills)
          .where(inArray(skills.id, unusedSkills.map(s => s.id)));
        
        console.log(`Cleaned up ${unusedSkills.length} unused skills`);
      }
    } catch (error) {
      console.error('Failed to cleanup unused skills:', error);
    }
  },
  null,
  true,
  'Asia/Shanghai'
);
```

## 十一、最佳实践

### 1. 性能优化

```typescript
// 使用索引优化查询
export const skillsOptimizedQuery = db
  .select()
  .from(skills)
  .where(eq(skills.category, 'frontend')) // 使用索引
  .orderBy(desc(skills.popularity)) // 考虑添加索引
  .limit(20);

// 批量操作使用事务
export async function batchOperationWithTransaction(operations: any[]) {
  return db.transaction(async (tx) => {
    for (const op of operations) {
      await op(tx);
    }
  });
}
```

### 2. 数据验证

```typescript
// src/lib/skills/validation.ts
import { z } from 'zod';

export const skillSchema = z.object({
  name: z.string().min(1).max(100),
  slug: z.string().min(1).max(100).regex(/^[a-z0-9-]+$/),
  description: z.string().max(500).optional(),
  category: z.string().max(50).optional(),
  level: z.number().int().min(1).max(5).optional(),
  verified: z.boolean().optional(),
});

export function validateSkill(data: any) {
  return skillSchema.parse(data);
}
```

## 总结

MkSaaS 提供了完整的 Skills 批量管理系统：

1. **批量操作**: 创建、更新、删除
2. **导入导出**: CSV、JSON 格式支持
3. **搜索过滤**: 全文搜索、高级过滤
4. **统计分析**: 热度计算、趋势分析
5. **推荐系统**: 相关技能、用户推荐
6. **定时任务**: 自动更新、清理
7. **管理界面**: 批量操作、导入导出组件

通过这些功能，可以高效管理大量技能数据。
