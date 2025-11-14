#!/bin/bash

# MkSaaS 子项目配置为私有仓库脚本
# 作用：将5个子项目配置为使用你的私有仓库，同时保留官方仓库用于同步更新

set -e  # 遇到错误立即退出

echo "=========================================="
echo "MkSaaS 子项目私有仓库配置脚本"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 子项目列表
PROJECTS=("mksaas-app" "mksaas-blog" "mksaas-haitang" "mksaas-outfit" "mksaas-template")

# 你的 GitHub 用户名
GITHUB_USER="ameureka"

echo "📋 将要配置的项目："
for project in "${PROJECTS[@]}"; do
    echo "  - $project"
done
echo ""

# 确认
read -p "确认开始配置？(y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消"
    exit 1
fi

echo ""
echo "🚀 开始配置..."
echo ""

# 配置每个项目
for project in "${PROJECTS[@]}"; do
    echo "=========================================="
    echo "📦 配置项目: $project"
    echo "=========================================="
    
    # 检查目录是否存在
    if [ ! -d "$project" ]; then
        echo -e "${RED}❌ 错误: 目录 $project 不存在${NC}"
        continue
    fi
    
    # 进入项目目录
    cd "$project"
    
    # 检查是否是 Git 仓库
    if [ ! -d ".git" ]; then
        echo -e "${RED}❌ 错误: $project 不是 Git 仓库${NC}"
        cd ..
        continue
    fi
    
    echo "1️⃣ 获取当前 remote 信息..."
    CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ -z "$CURRENT_ORIGIN" ]; then
        echo -e "${RED}❌ 错误: 无法获取 origin URL${NC}"
        cd ..
        continue
    fi
    
    echo "   当前 origin: $CURRENT_ORIGIN"
    
    echo "2️⃣ 检查是否已有 upstream..."
    if git remote get-url upstream &>/dev/null; then
        echo -e "${YELLOW}⚠️  upstream 已存在，跳过${NC}"
    else
        echo "3️⃣ 添加官方仓库为 upstream..."
        git remote add upstream "$CURRENT_ORIGIN"
        echo -e "${GREEN}✅ upstream 添加成功${NC}"
    fi
    
    echo "4️⃣ 更新 origin 为你的私有仓库..."
    git remote set-url origin "https://github.com/$GITHUB_USER/$project.git"
    echo -e "${GREEN}✅ origin 更新成功${NC}"
    
    echo "5️⃣ 验证 remote 配置..."
    echo "   Remote 列表："
    git remote -v | sed 's/^/   /'
    
    echo "6️⃣ 推送到你的私有仓库..."
    if git push -u origin main 2>/dev/null; then
        echo -e "${GREEN}✅ 推送成功${NC}"
    elif git push -u origin master 2>/dev/null; then
        echo -e "${GREEN}✅ 推送成功 (master 分支)${NC}"
    else
        echo -e "${RED}❌ 推送失败，请检查：${NC}"
        echo "   1. 是否已在 GitHub 创建私有仓库: $GITHUB_USER/$project"
        echo "   2. 是否有推送权限"
        echo "   3. 网络连接是否正常"
    fi
    
    echo ""
    
    # 返回上级目录
    cd ..
    
    echo -e "${GREEN}✅ $project 配置完成${NC}"
    echo ""
done

echo "=========================================="
echo "🎉 所有项目配置完成！"
echo "=========================================="
echo ""

echo "📊 配置总结："
echo ""
for project in "${PROJECTS[@]}"; do
    if [ -d "$project/.git" ]; then
        echo "📦 $project:"
        cd "$project"
        echo "   origin   → $(git remote get-url origin 2>/dev/null || echo '未配置')"
        echo "   upstream → $(git remote get-url upstream 2>/dev/null || echo '未配置')"
        cd ..
        echo ""
    fi
done

echo "=========================================="
echo "📚 后续操作指南"
echo "=========================================="
echo ""
echo "1️⃣ 修改代码："
echo "   cd mksaas-app"
echo "   # 编辑文件..."
echo "   git add ."
echo "   git commit -m \"feat: 添加新功能\""
echo "   git push origin main"
echo ""
echo "2️⃣ 同步官方更新："
echo "   cd mksaas-app"
echo "   git fetch upstream"
echo "   git merge upstream/main"
echo "   git push origin main"
echo ""
echo "3️⃣ 更新主仓库的子项目引用："
echo "   # 在主仓库根目录"
echo "   git add mksaas-app"
echo "   git commit -m \"update: 更新子项目\""
echo "   git push origin main"
echo ""

echo "✅ 完成！"
