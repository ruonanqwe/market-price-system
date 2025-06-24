#!/bin/bash

# 快速检查持久化部署状态

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🚀 农产品价格监控系统 - 部署状态"
echo "=================================="

# 获取公网IP
PUBLIC_IP=$(curl -s -m 5 ipinfo.io/ip 2>/dev/null || echo "未获取")
echo "🌐 公网IP: $PUBLIC_IP"
echo "⏰ 检查时间: $(date)"
echo

# 1. 服务进程检查
echo "📋 服务进程状态:"
API_PID=$(pgrep -f "python.*api_server" || echo "")
SCHEDULER_PIDS=$(pgrep -f "python.*scheduler_service" || echo "")

if [ -n "$API_PID" ]; then
    echo -e "  ${GREEN}✅ API服务运行中${NC} (PID: $API_PID)"
else
    echo -e "  ${RED}❌ API服务未运行${NC}"
fi

if [ -n "$SCHEDULER_PIDS" ]; then
    SCHEDULER_COUNT=$(echo "$SCHEDULER_PIDS" | wc -l)
    if [ $SCHEDULER_COUNT -eq 1 ]; then
        echo -e "  ${GREEN}✅ 调度器服务运行中${NC} (PID: $SCHEDULER_PIDS)"
    else
        echo -e "  ${YELLOW}⚠️  多个调度器进程${NC} ($SCHEDULER_COUNT 个): $SCHEDULER_PIDS"
    fi
else
    echo -e "  ${RED}❌ 调度器服务未运行${NC}"
fi

# 2. 端口监听检查
echo
echo "🔌 端口监听状态:"
if netstat -tlnp 2>/dev/null | grep -q ":8000"; then
    PORT_INFO=$(netstat -tlnp 2>/dev/null | grep ":8000")
    echo -e "  ${GREEN}✅ 端口8000正在监听${NC}"
    echo "  $PORT_INFO"
else
    echo -e "  ${RED}❌ 端口8000未监听${NC}"
fi

# 3. API健康检查
echo
echo "💚 API健康检查:"
if curl -s -m 5 http://localhost:8000/api/health > /dev/null 2>&1; then
    HEALTH_RESPONSE=$(curl -s -m 5 http://localhost:8000/api/health)
    echo -e "  ${GREEN}✅ API响应正常${NC}"
    echo "  $HEALTH_RESPONSE"
else
    echo -e "  ${RED}❌ API无响应${NC}"
fi

# 4. 数据文件检查
echo
echo "📊 数据文件状态:"
if [ -f "data/market_prices.csv" ]; then
    CSV_SIZE=$(du -h data/market_prices.csv | cut -f1)
    CSV_LINES=$(wc -l < data/market_prices.csv 2>/dev/null)
    echo -e "  ${GREEN}✅ CSV数据文件${NC}: $CSV_SIZE ($CSV_LINES 行)"
else
    echo -e "  ${RED}❌ CSV数据文件不存在${NC}"
fi

if [ -f "data/market_prices.db" ]; then
    DB_SIZE=$(du -h data/market_prices.db | cut -f1)
    echo -e "  ${GREEN}✅ SQLite数据库${NC}: $DB_SIZE"
else
    echo -e "  ${YELLOW}⚠️  SQLite数据库不存在${NC}"
fi

# 5. 日志文件检查
echo
echo "📝 日志文件状态:"
if [ -f "api_server.log" ]; then
    API_LOG_SIZE=$(du -h api_server.log | cut -f1)
    echo -e "  ${GREEN}✅ API日志${NC}: $API_LOG_SIZE"
    
    # 检查最近错误
    RECENT_ERRORS=$(tail -50 api_server.log | grep -i "error\|exception" | wc -l)
    if [ $RECENT_ERRORS -gt 0 ]; then
        echo -e "  ${YELLOW}⚠️  最近50行发现 $RECENT_ERRORS 个错误${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  API日志文件不存在${NC}"
fi

# 6. 持久化服务检查
echo
echo "🔄 持久化服务检查:"

# Systemd检查
if command -v systemctl &> /dev/null; then
    if systemctl list-unit-files 2>/dev/null | grep -q "market-price"; then
        echo -e "  ${GREEN}✅ 发现Systemd服务${NC}"
        systemctl status market-price-* --no-pager -l 2>/dev/null | grep -E "(Active:|Loaded:)" || true
    else
        echo -e "  ${YELLOW}⚠️  未配置Systemd服务${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  系统不支持Systemd${NC}"
fi

# Supervisor检查
if command -v supervisorctl &> /dev/null; then
    if supervisorctl status 2>/dev/null | grep -q "market-price"; then
        echo -e "  ${GREEN}✅ 发现Supervisor服务${NC}"
        supervisorctl status | grep "market-price" || true
    else
        echo -e "  ${YELLOW}⚠️  未配置Supervisor服务${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  未安装Supervisor${NC}"
fi

# 7. 访问地址
echo
echo "🔗 访问地址:"
echo "  📚 API文档: http://localhost:8000/docs"
if [ "$PUBLIC_IP" != "未获取" ]; then
    echo "  🌐 公网访问: http://$PUBLIC_IP:8000/docs"
fi

# 8. 快速统计
echo
echo "📈 快速统计:"
if curl -s -m 5 http://localhost:8000/api/statistics > /dev/null 2>&1; then
    STATS=$(curl -s -m 5 http://localhost:8000/api/statistics)
    echo "  $STATS"
else
    echo -e "  ${RED}❌ 无法获取统计信息${NC}"
fi

# 9. 系统资源
echo
echo "💻 系统资源:"
echo "  磁盘使用: $(df -h . | tail -1 | awk '{print $5}') ($(df -h . | tail -1 | awk '{print $4}') 可用)"
echo "  内存使用: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "  负载平均: $(uptime | awk -F'load average:' '{print $2}')"

# 10. 建议操作
echo
echo "💡 建议操作:"

if [ -z "$API_PID" ]; then
    echo "  🔧 启动API服务: python3 api_server.py &"
fi

if [ -z "$SCHEDULER_PIDS" ]; then
    echo "  🔧 启动调度器: python3 scheduler_service.py &"
fi

if [ ! -f "data/market_prices.csv" ]; then
    echo "  📊 初始化数据: python3 market_crawler.py"
fi

if ! systemctl list-unit-files 2>/dev/null | grep -q "market-price" && ! supervisorctl status 2>/dev/null | grep -q "market-price"; then
    echo "  🔄 配置持久化: ./huawei-cloud-deploy.sh"
fi

echo
echo "🎯 完整监控: ./deployment-monitor.sh"
echo "🧪 API测试: ./test-api.sh"
echo "📊 详细状态: ./status.sh"
