#!/bin/bash

# 农产品价格监控系统 - 可视化管理面板启动脚本

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

# 检查Docker环境
check_docker() {
    log_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请启动Docker服务"
        exit 1
    fi
    
    log_info "Docker环境检查通过"
}

# 检查必要文件
check_files() {
    log_step "检查必要文件..."
    
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml文件不存在"
        exit 1
    fi
    
    if [ ! -f "Dockerfile.dashboard" ]; then
        log_error "Dockerfile.dashboard文件不存在"
        exit 1
    fi
    
    if [ ! -d "dashboard" ]; then
        log_error "dashboard目录不存在"
        exit 1
    fi
    
    log_info "必要文件检查通过"
}

# 生成Portainer密码
setup_portainer_password() {
    log_step "设置Portainer密码..."
    
    PORTAINER_PASSWORD="admin123456"
    
    # 创建密码文件
    echo "$PORTAINER_PASSWORD" > portainer_password
    
    log_info "Portainer密码已设置"
    log_warn "默认用户名: admin"
    log_warn "默认密码: $PORTAINER_PASSWORD"
}

# 创建必要目录
create_directories() {
    log_step "创建必要目录..."
    
    mkdir -p data logs reports backups
    mkdir -p grafana/provisioning/dashboards
    mkdir -p grafana/provisioning/datasources
    
    log_info "目录创建完成"
}

# 启动核心服务
start_core_services() {
    log_step "启动核心服务..."
    
    # 停止现有服务
    docker-compose down 2>/dev/null || true
    
    # 只启动核心服务
    docker-compose up -d market-api scheduler portainer dashboard
    
    log_info "核心服务启动完成"
}

# 等待服务启动
wait_for_services() {
    log_step "等待服务启动..."
    
    # 等待API服务
    echo -n "等待API服务启动"
    for i in {1..30}; do
        if curl -s http://localhost:8000/api/health > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # 等待Portainer服务
    echo -n "等待Portainer服务启动"
    for i in {1..30}; do
        if curl -s http://localhost:9000 > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # 等待Dashboard服务
    echo -n "等待Dashboard服务启动"
    for i in {1..30}; do
        if curl -s http://localhost:8080 > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    log_info "所有服务启动完成"
}

# 显示访问信息
show_access_info() {
    echo
    echo "🎉 可视化管理面板启动完成！"
    echo "=================================="
    echo
    echo "📊 访问地址:"
    echo "  🏠 管理面板:     http://localhost:8080"
    echo "  📈 数据面板:     http://localhost:8000/static/"
    echo "  📚 API文档:      http://localhost:8000/docs"
    echo "  🐳 Portainer:    http://localhost:9000"
    echo
    echo "🔐 默认账户信息:"
    echo "  Portainer:    admin / admin123456"
    echo
    echo "🔧 管理命令:"
    echo "  查看状态:     docker-compose ps"
    echo "  查看日志:     docker-compose logs -f"
    echo "  停止服务:     docker-compose down"
    echo "  重启服务:     docker-compose restart"
    echo
    echo "📝 功能说明:"
    echo "  • 管理面板: 统一的系统管理界面"
    echo "  • 数据面板: 农产品价格数据展示"
    echo "  • Portainer: Docker容器可视化管理"
    echo "  • API文档: 接口文档和测试"
    echo
    echo "🚀 下一步:"
    echo "  1. 访问管理面板开始使用"
    echo "  2. 在Portainer中管理Docker容器"
    echo "  3. 查看数据面板了解价格信息"
    echo
}

# 主函数
main() {
    echo "🚀 农产品价格监控系统 - 可视化管理面板"
    echo "=================================="
    echo
    
    check_docker
    check_files
    setup_portainer_password
    create_directories
    start_core_services
    wait_for_services
    show_access_info
}

# 运行主函数
main
