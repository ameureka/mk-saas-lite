#!/bin/bash

# MkSaaS 同步官方更新脚本
# 作用：从官方仓库拉取最新更新并合并到你的私有仓库

set -e  # 遇到错误立即退出

echo "=========================================="
echo "MkSaaS 官方更新同步脚本"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 子项目列表
PROJECTS=("mksaas-app" "mksaas-blog" "mksaas-haitang" "mksaas-outfit" "mksaas-template")

echo "📋 将要同步的项目："
for project in "${PROJECTS[@]}"; do
    echo "  - $project"
done
echo ""

# 选择同步方式
echo "请选择同步方式："
echo "  1) merge  - 合并（保留所有提交历史）"
echo "  2) rebase - 变基（保持提交历史整洁）"
echo ""
read -p "请选择 (1/2，默认1): " -n 1 -r SYNC_METHOD
echo ""

if [ "$SYNC_METHOD" = "2" ]; then
    SYNC_CMD="rebase"
    echo -e "${BLUE}📌 使用 rebase 方式${NC}"
else
    SYNC_CMD="merge"
    echo -e "${BLUE}📌 使用 merge 方式${NC}"
fi

echo ""

# 确认
read -p "确认开始同步？(y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消"
    exit 1
fi

echo ""
echo "🚀 开始同步..."
echo ""

# 记录成功和失败的项目
SUCCESS_PROJECTS=()
FAILED_PROJECTS=()

# 同步每个项目
for project in "${PROJECTS[@]}"; do
    echo "=========================================="
    echo "📦 同步项目: $project"
    echo "=========================================="
    
    # 检查目录是否存在
    if [ ! -d "$project" ]; then
        echo -e "${RED}❌ 错误: 目录 $project 不存在${NC}"
        FAILED_PROJECTS+=("$project (目录不存在)")
        echo ""
        continue
    fi
    
    # 进入项目目录
    cd "$project"
    
    # 检查是否是 Git 仓库
    if [ ! -d ".git" ]; then
        echo -e "${RED}❌ 错误: $project 不是 Git 仓库${NC}"
        FAILED_PROJECTS+=("$project (非Git仓库)")
        cd ..
        echo ""
        continue
    fi
    
    # 检查是否有未提交的更改
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${YELLOW}⚠️  警告: 有未提交的更改${NC}"
        echo "请先提交或暂存更改："
        echo "  git add ."
        echo "  git commit -m \"保存更改\""
        echo "或者暂存："
        echo "  git stash"
        FAILED_PROJECTS+=("$project (有未提交更改)")
        cd ..
        echo ""
        continue
    fi
    
    # 获取当前分支
    CURRENT_BRANCH=$(git branch --show-current)
    echo "📍 当前分支: $CURRENT_BRANCH"
    
    # 检查 upstream 是否存在
    if ! git remote get-url upstream &>/dev/null; then
        echo -e "${RED}❌ 错误: upstream 未配置${NC}"
        echo "请先运行配置脚本"
        FAILED_PROJECTS+=("$project (upstream未配置)")
        cd ..
        echo ""
        continue
    fi
    
    echo "1️⃣ 拉取官方更新..."
    if git fetch upstream; then
        echo -e "${GREEN}✅ 拉取成功${NC}"
    else
        echo -e "${RED}❌ 拉取失败${NC}"
        FAILED_PROJECTS+=("$project (拉取失败)")
        cd ..
        echo ""
        continue
    fi
    
    echo "2️⃣ 同步更新 (使用 $SYNC_CMD)..."
    if [ "$SYNC_CMD" = "rebase" ]; then
        if git rebase upstream/$CURRENT_BRANCH; then
            echo -e "${GREEN}✅ Rebase 成功${NC}"
        else
            echo -e "${RED}❌ Rebase 失败，可能有冲突${NC}"
            echo "请手动解决冲突："
            echo "  1. 编辑冲突文件"
            echo "  2. git add <文件>"
            echo "  3. git rebase --continue"
            echo "或者放弃："
            echo "  git rebase --abort"
            FAILED_PROJECTS+=("$project (rebase冲突)")
            cd ..
            echo ""
            continue
        fi
    else
        if git merge upstream/$CURRENT_BRANCH; then
            echo -e "${GREEN}✅ Merge 成功${NC}"
        else
            echo -e "${RED}❌ Merge 失败，可能有冲突${NC}"
            echo "请手动解决冲突："
            echo "  1. 编辑冲突文件"
            echo "  2. git add <文件>"
            echo "  3. git commit"
            echo "或者放弃："
            echo "  git merge --abort"
            FAILED_PROJECTS+=("$project (merge冲突)")
            cd ..
            echo ""
            continue
        fi
    fi
    
    echo "3️⃣ 推送到你的私有仓库..."
    if git push origin $CURRENT_BRANCH; then
        echo -e "${GREEN}✅ 推送成功${NC}"
        SUCCESS_PROJECTS+=("$project")
    else
        echo -e "${RED}❌ 推送失败${NC}"
        echo "可能需要强制推送（如果使用了 rebase）："
        echo "  git push origin $CURRENT_BRANCH --force-with-lease"
        FAILED_PROJECTS+=("$project (推送失败)")
    fi
    
    echo ""
    
    # 返回上级目录
    cd ..
    
    echo -e "${GREEN}✅ $project 同步完成${NC}"
    echo ""
done

echo "=========================================="
echo "📊 同步结果总结"
echo "=========================================="
echo ""

if [ ${#SUCCESS_PROJECTS[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ 成功同步的项目 (${#SUCCESS_PROJECTS[@]})：${NC}"
    for project in "${SUCCESS_PROJECTS[@]}"; do
        echo "   ✓ $project"
    done
    echo ""
fi

if [ ${#FAILED_PROJECTS[@]} -gt 0 ]; then
    echo -e "${RED}❌ 失败的项目 (${#FAILED_PROJECTS[@]})：${NC}"
    for project in "${FAILED_PROJECTS[@]}"; do
        echo "   ✗ $project"
    done
    echo ""
fi

if [ ${#SUCCESS_PROJECTS[@]} -gt 0 ]; then
    echo "=========================================="
    echo "📚 后续操作"
    echo "=========================================="
    echo ""
    echo "如果你在主仓库中使用了这些子项目，需要更新引用："
    echo ""
    echo "# 在主仓库根目录"
    for project in "${SUCCESS_PROJECTS[@]}"; do
        echo "git add $project"
    done
    echo "git commit -m \"update: 同步官方更新\""
    echo "git push origin main"
    echo ""
fi

echo "✅ 同步完成！"
