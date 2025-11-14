#!/bin/bash

# 检查官方更新脚本
# 只检查是否有更新，不执行同步

echo "=========================================="
echo "检查 MkSaaS 官方更新"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 子项目列表
PROJECTS=("mksaas-app" "mksaas-blog" "mksaas-haitang" "mksaas-outfit" "mksaas-template")

HAS_UPDATES=0

for project in "${PROJECTS[@]}"; do
    echo "=========================================="
    echo "📦 检查项目: $project"
    echo "=========================================="
    
    if [ ! -d "$project" ]; then
        echo "❌ 目录不存在"
        echo ""
        continue
    fi
    
    # 进入项目目录
    cd "$project"
    
    # 获取当前分支
    CURRENT_BRANCH=$(git branch --show-current)
    echo "📍 当前分支: $CURRENT_BRANCH"
    
    # 拉取官方更新信息
    echo "🔍 拉取官方仓库信息..."
    if git fetch upstream 2>/dev/null; then
        echo -e "${GREEN}✅ 拉取成功${NC}"
        
        # 检查是否有新提交
        BEHIND=$(git rev-list --count HEAD..upstream/$CURRENT_BRANCH 2>/dev/null || echo "0")
        AHEAD=$(git rev-list --count upstream/$CURRENT_BRANCH..HEAD 2>/dev/null || echo "0")
        
        if [ "$BEHIND" -gt 0 ]; then
            echo -e "${YELLOW}📥 官方有 $BEHIND 个新提交${NC}"
            echo ""
            echo "最新的提交："
            git log HEAD..upstream/$CURRENT_BRANCH --oneline --max-count=5 2>/dev/null || echo "无法获取提交信息"
            HAS_UPDATES=1
        else
            echo -e "${GREEN}✅ 已是最新版本${NC}"
        fi
        
        if [ "$AHEAD" -gt 0 ]; then
            echo -e "${BLUE}📤 你有 $AHEAD 个本地提交未推送${NC}"
        fi
    else
        echo "❌ 拉取失败（upstream 可能未配置）"
    fi
    
    echo ""
    
    # 返回上级目录
    cd ..
done

echo "=========================================="
echo "📊 检查结果总结"
echo "=========================================="
echo ""

if [ $HAS_UPDATES -eq 1 ]; then
    echo -e "${YELLOW}⚠️  有官方更新可用${NC}"
    echo ""
    echo "运行以下命令同步更新："
    echo "  ./同步官方更新脚本.sh"
else
    echo -e "${GREEN}✅ 所有项目都是最新版本${NC}"
fi

echo ""
echo "✅ 检查完成！"
