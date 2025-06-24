#!/bin/bash

# 农产品价格监控系统 - 停止可视化管理面板脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# 主函数
main() {
    echo "🛑 农产品价格监控系统 - 停止可视化管理面板"
    echo "=================================="
    echo
    
    log_step "停止Docker服务..."
    
    # 停止所有服务
    if docker-compose down; then
        log_info "所有服务已停止"
    else
        log_error "停止服务时出现错误"
        exit 1
    fi
    
    # 显示状态
    log_step "检查服务状态..."
    docker-compose ps
    
    echo
    log_info "可视化管理面板已停止"
    echo
    echo "🔧 其他管理命令:"
    echo "  启动服务:     ./start-dashboard.sh"
    echo "  查看状态:     docker-compose ps"
    echo "  查看日志:     docker-compose logs"
    echo "  清理资源:     docker-compose down -v --remove-orphans"
    echo
}

# 运行主函数
main
