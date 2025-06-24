#!/bin/bash

# 农产品价格监控系统 - 持久化部署监控脚本
# 用于查看和管理系统的持久化部署状态

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# 获取公网IP
get_public_ip() {
    PUBLIC_IP=$(curl -s -m 5 ipinfo.io/ip 2>/dev/null || curl -s -m 5 ifconfig.me 2>/dev/null || echo "未获取到")
    echo $PUBLIC_IP
}

# 检查服务状态
check_service_status() {
    echo "🔍 服务状态检查"
    echo "=================================="
    
    # API服务检查
    API_PID=$(pgrep -f "python.*api_server" || echo "")
    if [ -n "$API_PID" ]; then
        log_success "✅ API服务运行中 (PID: $API_PID)"
        
        # 检查端口监听
        if netstat -tlnp 2>/dev/null | grep -q ":8000.*$API_PID"; then
            log_success "✅ 端口8000正常监听"
        else
            log_warn "⚠️  端口8000未正常监听"
        fi
        
        # 检查API响应
        if curl -s -m 5 http://localhost:8000/api/health > /dev/null 2>&1; then
            log_success "✅ API健康检查通过"
        else
            log_error "❌ API健康检查失败"
        fi
    else
        log_error "❌ API服务未运行"
    fi
    
    # 调度器服务检查
    SCHEDULER_PIDS=$(pgrep -f "python.*scheduler_service" || echo "")
    if [ -n "$SCHEDULER_PIDS" ]; then
        SCHEDULER_COUNT=$(echo "$SCHEDULER_PIDS" | wc -l)
        if [ $SCHEDULER_COUNT -eq 1 ]; then
            log_success "✅ 调度器服务运行中 (PID: $SCHEDULER_PIDS)"
        else
            log_warn "⚠️  发现多个调度器进程 ($SCHEDULER_COUNT 个): $SCHEDULER_PIDS"
        fi
    else
        log_error "❌ 调度器服务未运行"
    fi
    
    echo
}

# 检查持久化配置
check_persistence_config() {
    echo "💾 持久化配置检查"
    echo "=================================="
    
    # 检查Systemd服务
    if command -v systemctl &> /dev/null; then
        log_step "检查Systemd服务..."
        
        if systemctl list-unit-files | grep -q "market-price-api"; then
            API_STATUS=$(systemctl is-active market-price-api 2>/dev/null || echo "inactive")
            API_ENABLED=$(systemctl is-enabled market-price-api 2>/dev/null || echo "disabled")
            echo "  📋 API服务: $API_STATUS ($API_ENABLED)"
        else
            log_warn "  ⚠️  未找到market-price-api systemd服务"
        fi
        
        if systemctl list-unit-files | grep -q "market-price-scheduler"; then
            SCHEDULER_STATUS=$(systemctl is-active market-price-scheduler 2>/dev/null || echo "inactive")
            SCHEDULER_ENABLED=$(systemctl is-enabled market-price-scheduler 2>/dev/null || echo "disabled")
            echo "  📋 调度器服务: $SCHEDULER_STATUS ($SCHEDULER_ENABLED)"
        else
            log_warn "  ⚠️  未找到market-price-scheduler systemd服务"
        fi
    else
        log_warn "  ⚠️  系统不支持systemctl"
    fi
    
    # 检查Supervisor配置
    if command -v supervisorctl &> /dev/null; then
        log_step "检查Supervisor服务..."
        
        if supervisorctl status 2>/dev/null | grep -q "market-price"; then
            supervisorctl status | grep "market-price" | while read line; do
                echo "  📋 $line"
            done
        else
            log_warn "  ⚠️  未找到Supervisor中的market-price服务"
        fi
    else
        log_warn "  ⚠️  未安装Supervisor"
    fi
    
    # 检查Docker容器
    if command -v docker &> /dev/null; then
        log_step "检查Docker容器..."
        
        CONTAINERS=$(docker ps -a --filter "name=market-price" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "")
        if [ -n "$CONTAINERS" ]; then
            echo "$CONTAINERS"
        else
            log_warn "  ⚠️  未找到market-price相关容器"
        fi
    else
        log_warn "  ⚠️  未安装Docker"
    fi
    
    # 检查Crontab任务
    log_step "检查Crontab任务..."
    CRON_JOBS=$(crontab -l 2>/dev/null | grep -i "market\|price" || echo "")
    if [ -n "$CRON_JOBS" ]; then
        echo "$CRON_JOBS" | while read line; do
            echo "  📋 $line"
        done
    else
        log_warn "  ⚠️  未找到相关的Crontab任务"
    fi
    
    echo
}

# 检查数据持久化
check_data_persistence() {
    echo "📊 数据持久化检查"
    echo "=================================="
    
    # 检查数据目录
    if [ -d "data" ]; then
        log_success "✅ 数据目录存在"
        
        # CSV文件检查
        if [ -f "data/market_prices.csv" ]; then
            CSV_SIZE=$(du -h data/market_prices.csv | cut -f1)
            CSV_LINES=$(wc -l < data/market_prices.csv 2>/dev/null || echo "0")
            log_success "✅ CSV数据文件: $CSV_SIZE, $CSV_LINES 行"
        else
            log_error "❌ CSV数据文件不存在"
        fi
        
        # 数据库文件检查
        if [ -f "data/market_prices.db" ]; then
            DB_SIZE=$(du -h data/market_prices.db | cut -f1)
            log_success "✅ SQLite数据库: $DB_SIZE"
        else
            log_warn "⚠️  SQLite数据库文件不存在"
        fi
        
        # 备份文件检查
        BACKUP_COUNT=$(ls data/*.backup* 2>/dev/null | wc -l || echo "0")
        if [ $BACKUP_COUNT -gt 0 ]; then
            log_info "📦 发现 $BACKUP_COUNT 个备份文件"
        else
            log_warn "⚠️  未找到备份文件"
        fi
    else
        log_error "❌ 数据目录不存在"
    fi
    
    echo
}

# 检查日志文件
check_logs() {
    echo "📝 日志文件检查"
    echo "=================================="
    
    # API日志
    if [ -f "api_server.log" ]; then
        API_LOG_SIZE=$(du -h api_server.log | cut -f1)
        API_LOG_LINES=$(wc -l < api_server.log)
        log_success "✅ API日志: $API_LOG_SIZE, $API_LOG_LINES 行"
        
        # 检查最近的错误
        ERROR_COUNT=$(tail -100 api_server.log | grep -i "error\|exception" | wc -l)
        if [ $ERROR_COUNT -gt 0 ]; then
            log_warn "⚠️  最近100行中发现 $ERROR_COUNT 个错误"
        fi
    else
        log_warn "⚠️  API日志文件不存在"
    fi
    
    # 调度器日志
    if [ -f "scheduler_service.log" ]; then
        SCHEDULER_LOG_SIZE=$(du -h scheduler_service.log | cut -f1)
        SCHEDULER_LOG_LINES=$(wc -l < scheduler_service.log)
        log_success "✅ 调度器日志: $SCHEDULER_LOG_SIZE, $SCHEDULER_LOG_LINES 行"
    else
        log_warn "⚠️  调度器日志文件不存在"
    fi
    
    # 系统日志检查
    if command -v journalctl &> /dev/null; then
        log_step "检查系统日志中的相关记录..."
        JOURNAL_ERRORS=$(journalctl -u market-price-* --since "1 hour ago" --no-pager -q 2>/dev/null | grep -i "error\|failed" | wc -l || echo "0")
        if [ $JOURNAL_ERRORS -gt 0 ]; then
            log_warn "⚠️  系统日志中发现 $JOURNAL_ERRORS 个错误"
        else
            log_success "✅ 系统日志正常"
        fi
    fi
    
    echo
}

# 检查网络访问
check_network_access() {
    echo "🌐 网络访问检查"
    echo "=================================="
    
    PUBLIC_IP=$(get_public_ip)
    log_info "公网IP: $PUBLIC_IP"
    
    # 本地访问测试
    log_step "本地访问测试..."
    if curl -s -m 5 http://localhost:8000/api/health > /dev/null; then
        log_success "✅ 本地API访问正常"
    else
        log_error "❌ 本地API访问失败"
    fi
    
    # 公网访问测试（如果有公网IP）
    if [ "$PUBLIC_IP" != "未获取到" ] && [ "$PUBLIC_IP" != "127.0.0.1" ]; then
        log_step "公网访问测试..."
        if curl -s -m 10 "http://$PUBLIC_IP:8000/api/health" > /dev/null; then
            log_success "✅ 公网API访问正常"
        else
            log_warn "⚠️  公网API访问失败（可能需要配置安全组）"
        fi
    fi
    
    echo
}

# 显示访问地址
show_access_urls() {
    echo "🔗 访问地址"
    echo "=================================="
    
    PUBLIC_IP=$(get_public_ip)
    
    echo "📱 本地访问:"
    echo "  🏠 API文档: http://localhost:8000/docs"
    echo "  💚 健康检查: http://localhost:8000/api/health"
    echo "  📊 统计信息: http://localhost:8000/api/statistics"
    echo "  🔍 价格查询: http://localhost:8000/api/prices"
    
    if [ "$PUBLIC_IP" != "未获取到" ] && [ "$PUBLIC_IP" != "127.0.0.1" ]; then
        echo
        echo "🌐 公网访问:"
        echo "  🏠 API文档: http://$PUBLIC_IP:8000/docs"
        echo "  💚 健康检查: http://$PUBLIC_IP:8000/api/health"
        echo "  📊 统计信息: http://$PUBLIC_IP:8000/api/statistics"
        echo "  🔍 价格查询: http://$PUBLIC_IP:8000/api/prices"
    fi
    
    echo
}

# 显示管理命令
show_management_commands() {
    echo "🔧 管理命令"
    echo "=================================="
    
    echo "📋 服务管理:"
    echo "  启动服务: ./start-services.sh"
    echo "  停止服务: ./stop-services.sh"
    echo "  重启服务: ./restart-services.sh"
    echo "  查看状态: ./status.sh"
    
    echo
    echo "📊 数据管理:"
    echo "  修复数据: python3 fix-csv-data.py"
    echo "  备份数据: cp data/market_prices.csv data/backup_\$(date +%Y%m%d).csv"
    echo "  查看数据: head -10 data/market_prices.csv"
    
    echo
    echo "📝 日志管理:"
    echo "  查看API日志: tail -f api_server.log"
    echo "  查看调度器日志: tail -f scheduler_service.log"
    echo "  清理日志: > api_server.log && > scheduler_service.log"
    
    echo
    echo "🧪 测试命令:"
    echo "  测试API: curl http://localhost:8000/api/health"
    echo "  运行测试: ./test-api.sh"
    echo "  性能测试: ab -n 100 -c 10 http://localhost:8000/api/health"
    
    echo
}

# 生成部署报告
generate_deployment_report() {
    REPORT_FILE="deployment-report-$(date +%Y%m%d_%H%M%S).txt"
    
    echo "📄 生成部署报告: $REPORT_FILE"
    
    {
        echo "农产品价格监控系统 - 部署状态报告"
        echo "生成时间: $(date)"
        echo "服务器IP: $(get_public_ip)"
        echo "=================================="
        echo
        
        echo "1. 服务状态"
        echo "----------"
        ps aux | grep -E "python.*(api_server|scheduler_service)" | grep -v grep
        echo
        
        echo "2. 端口监听"
        echo "----------"
        netstat -tlnp | grep :8000
        echo
        
        echo "3. 数据文件"
        echo "----------"
        ls -la data/ 2>/dev/null || echo "数据目录不存在"
        echo
        
        echo "4. 日志文件"
        echo "----------"
        ls -la *.log 2>/dev/null || echo "无日志文件"
        echo
        
        echo "5. 系统资源"
        echo "----------"
        df -h | grep -E "(Filesystem|/dev/)"
        echo
        free -h
        echo
        
        echo "6. 最近错误"
        echo "----------"
        tail -20 api_server.log 2>/dev/null | grep -i "error\|exception" || echo "无错误记录"
        
    } > "$REPORT_FILE"
    
    log_success "✅ 部署报告已生成: $REPORT_FILE"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "🚀 农产品价格监控系统 - 持久化部署监控"
        echo "=================================="
        echo "服务器IP: $(get_public_ip)"
        echo "当前时间: $(date)"
        echo
        echo "请选择操作："
        echo "1. 📊 完整状态检查"
        echo "2. 🔍 服务状态检查"
        echo "3. 💾 持久化配置检查"
        echo "4. 📊 数据持久化检查"
        echo "5. 📝 日志文件检查"
        echo "6. 🌐 网络访问检查"
        echo "7. 🔗 显示访问地址"
        echo "8. 🔧 显示管理命令"
        echo "9. 📄 生成部署报告"
        echo "0. 退出"
        echo
        read -p "请选择 (0-9): " choice
        
        case $choice in
            1)
                clear
                check_service_status
                check_persistence_config
                check_data_persistence
                check_logs
                check_network_access
                show_access_urls
                ;;
            2)
                clear
                check_service_status
                ;;
            3)
                clear
                check_persistence_config
                ;;
            4)
                clear
                check_data_persistence
                ;;
            5)
                clear
                check_logs
                ;;
            6)
                clear
                check_network_access
                ;;
            7)
                clear
                show_access_urls
                ;;
            8)
                clear
                show_management_commands
                ;;
            9)
                clear
                generate_deployment_report
                ;;
            0)
                echo "👋 再见！"
                exit 0
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
        
        echo
        read -p "按回车键继续..."
    done
}

# 如果有参数，直接执行对应功能
if [ $# -gt 0 ]; then
    case $1 in
        "status")
            check_service_status
            ;;
        "config")
            check_persistence_config
            ;;
        "data")
            check_data_persistence
            ;;
        "logs")
            check_logs
            ;;
        "network")
            check_network_access
            ;;
        "urls")
            show_access_urls
            ;;
        "commands")
            show_management_commands
            ;;
        "report")
            generate_deployment_report
            ;;
        "all")
            check_service_status
            check_persistence_config
            check_data_persistence
            check_logs
            check_network_access
            show_access_urls
            ;;
        *)
            echo "用法: $0 [status|config|data|logs|network|urls|commands|report|all]"
            exit 1
            ;;
    esac
else
    # 无参数时显示菜单
    main_menu
fi
