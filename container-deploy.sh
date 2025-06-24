#!/bin/bash

# 农产品市场价格监控系统容器环境部署脚本
# 适用于容器环境，不依赖 systemd

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查环境
check_environment() {
    log_step "检查容器环境..."
    
    # 检查Python环境
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 未安装"
        exit 1
    fi
    
    # 检查pip
    if ! command -v pip3 &> /dev/null; then
        log_error "pip3 未安装"
        exit 1
    fi
    
    log_info "Python版本: $(python3 --version)"
    log_info "环境检查完成"
}

# 安装依赖
install_dependencies() {
    log_step "安装Python依赖..."
    
    # 升级pip
    python3 -m pip install --upgrade pip
    
    # 安装依赖
    if [[ -f "requirements.txt" ]]; then
        python3 -m pip install -r requirements.txt
    else
        log_error "requirements.txt 文件不存在"
        exit 1
    fi
    
    log_info "依赖安装完成"
}

# 初始化数据库
initialize_database() {
    log_step "初始化数据库..."
    
    # 创建数据目录
    mkdir -p data logs reports
    
    # 初始化数据库
    python3 -c "
from database_manager import DatabaseManager
db = DatabaseManager()
print('数据库初始化完成')
"
    
    log_info "数据库初始化完成"
}

# 启动API服务
start_api_service() {
    log_step "启动API服务..."
    
    # 后台启动API服务
    nohup python3 api_server.py > logs/api.log 2>&1 &
    API_PID=$!
    echo $API_PID > api.pid
    
    log_info "API服务已启动，PID: $API_PID"
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if kill -0 $API_PID 2>/dev/null; then
        log_info "API服务运行正常"
    else
        log_error "API服务启动失败"
        exit 1
    fi
}

# 启动调度器服务
start_scheduler_service() {
    log_step "启动调度器服务..."
    
    # 后台启动调度器
    nohup python3 scheduler_service.py > logs/scheduler.log 2>&1 &
    SCHEDULER_PID=$!
    echo $SCHEDULER_PID > scheduler.pid
    
    log_info "调度器服务已启动，PID: $SCHEDULER_PID"
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if kill -0 $SCHEDULER_PID 2>/dev/null; then
        log_info "调度器服务运行正常"
    else
        log_error "调度器服务启动失败"
        exit 1
    fi
}

# 测试服务
test_services() {
    log_step "测试服务..."
    
    # 等待服务完全启动
    sleep 10
    
    # 测试API健康检查
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        log_info "API健康检查通过"
    else
        log_warn "API健康检查失败，检查日志: tail -f logs/api.log"
    fi
    
    # 测试数据库连接
    python3 -c "
from database_manager import DatabaseManager
try:
    db = DatabaseManager()
    print('数据库连接测试通过')
except Exception as e:
    print(f'数据库连接测试失败: {e}')
"
}

# 创建管理脚本
create_management_scripts() {
    log_step "创建管理脚本..."
    
    # 状态检查脚本
    cat > status.sh << 'EOF'
#!/bin/bash
echo "=== 农产品市场价格监控系统状态 ==="
echo

# 检查API服务
if [[ -f "api.pid" ]]; then
    API_PID=$(cat api.pid)
    if kill -0 $API_PID 2>/dev/null; then
        echo "✅ API服务运行中 (PID: $API_PID)"
    else
        echo "❌ API服务未运行"
    fi
else
    echo "❌ API服务PID文件不存在"
fi

# 检查调度器服务
if [[ -f "scheduler.pid" ]]; then
    SCHEDULER_PID=$(cat scheduler.pid)
    if kill -0 $SCHEDULER_PID 2>/dev/null; then
        echo "✅ 调度器服务运行中 (PID: $SCHEDULER_PID)"
    else
        echo "❌ 调度器服务未运行"
    fi
else
    echo "❌ 调度器服务PID文件不存在"
fi

echo
echo "端口监听状态:"
netstat -tlnp 2>/dev/null | grep :8000 || echo "端口8000未监听"

echo
echo "最近日志:"
echo "--- API日志 ---"
tail -n 5 logs/api.log 2>/dev/null || echo "无API日志"
echo "--- 调度器日志 ---"
tail -n 5 logs/scheduler.log 2>/dev/null || echo "无调度器日志"
EOF

    # 停止脚本
    cat > stop.sh << 'EOF'
#!/bin/bash
echo "停止农产品市场价格监控系统..."

# 停止API服务
if [[ -f "api.pid" ]]; then
    API_PID=$(cat api.pid)
    if kill -0 $API_PID 2>/dev/null; then
        kill $API_PID
        echo "API服务已停止"
    fi
    rm -f api.pid
fi

# 停止调度器服务
if [[ -f "scheduler.pid" ]]; then
    SCHEDULER_PID=$(cat scheduler.pid)
    if kill -0 $SCHEDULER_PID 2>/dev/null; then
        kill $SCHEDULER_PID
        echo "调度器服务已停止"
    fi
    rm -f scheduler.pid
fi

echo "所有服务已停止"
EOF

    # 重启脚本
    cat > restart.sh << 'EOF'
#!/bin/bash
echo "重启农产品市场价格监控系统..."
./stop.sh
sleep 3
./container-deploy.sh
EOF

    # 日志查看脚本
    cat > logs.sh << 'EOF'
#!/bin/bash
if [[ "$1" == "api" ]]; then
    tail -f logs/api.log
elif [[ "$1" == "scheduler" ]]; then
    tail -f logs/scheduler.log
else
    echo "用法: $0 [api|scheduler]"
    echo "或者直接查看日志文件:"
    echo "  API日志: tail -f logs/api.log"
    echo "  调度器日志: tail -f logs/scheduler.log"
fi
EOF

    # 设置执行权限
    chmod +x *.sh
    
    log_info "管理脚本创建完成"
}

# 显示完成信息
show_completion_info() {
    log_info "容器环境部署完成！"
    echo
    echo "=== 农产品市场价格监控系统 ==="
    echo "部署目录: $(pwd)"
    echo
    echo "服务访问地址:"
    echo "  API服务: http://localhost:8000"
    echo "  API文档: http://localhost:8000/docs"
    echo "  健康检查: http://localhost:8000/health"
    echo
    echo "管理命令:"
    echo "  查看状态: ./status.sh"
    echo "  停止服务: ./stop.sh"
    echo "  重启服务: ./restart.sh"
    echo "  查看日志: ./logs.sh [api|scheduler]"
    echo
    echo "日志文件:"
    echo "  API日志: logs/api.log"
    echo "  调度器日志: logs/scheduler.log"
    echo
    echo "测试命令:"
    echo "  curl http://localhost:8000/health"
    echo "  curl -X POST http://localhost:8000/predict -H 'Content-Type: application/json' -d '{\"symbol\":\"AAPL\",\"days\":7}'"
}

# 主部署流程
main() {
    echo "=== 农产品市场价格监控系统容器环境部署 ==="
    echo "适用于容器环境，不依赖 systemd"
    echo
    
    check_environment
    install_dependencies
    initialize_database
    create_management_scripts
    start_api_service
    start_scheduler_service
    test_services
    show_completion_info
}

# 运行主程序
main "$@"
