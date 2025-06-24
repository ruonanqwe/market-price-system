#!/bin/bash

# 农产品市场价格监控系统一键部署脚本
# 适用于 8核32GB CPU环境 ubuntu22.04-py311-torch2.3.1-1.27.0
# 集成 ModelScope Library

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 配置变量
PLUGIN_NAME="农产品市场价格监控系统"
PLUGIN_VERSION="1.0.0"
INSTALL_DIR="$HOME/market-price-plugin"
SERVICE_PORT=8000
NGINX_PORT=80
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090

# 日志函数
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

log_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${PURPLE}"
    echo "=================================================================="
    echo "           $PLUGIN_NAME"
    echo "                    v$PLUGIN_VERSION"
    echo "=================================================================="
    echo -e "${NC}"
    echo "🚀 功能特性:"
    echo "   • 实时监控全国农产品市场价格"
    echo "   • 提供RESTful API接口服务"
    echo "   • 地理位置就近推荐功能"
    echo "   • 价格趋势分析和历史对比"
    echo "   • 支持Docker容器化部署"
    echo "   • 集成监控和告警功能"
    echo
    echo "💻 系统要求:"
    echo "   • Ubuntu 22.04 LTS"
    echo "   • Python 3.11"
    echo "   • 8核CPU + 32GB内存"
    echo "   • 10GB+ 存储空间"
    echo
    echo "🔧 部署选项:"
    echo "   1. Docker部署 (推荐)"
    echo "   2. 本地部署"
    echo "   3. 仅安装依赖"
    echo
}

# 检查系统环境
check_environment() {
    log_step "检查系统环境..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warn "当前系统不是Ubuntu，可能存在兼容性问题"
    fi
    
    # 检查CPU核心数
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 4 ]]; then
        log_warn "CPU核心数不足，推荐8核以上 (当前: ${CPU_CORES}核)"
    else
        log_info "CPU核心数: ${CPU_CORES}核 ✓"
    fi
    
    # 检查内存
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_MEM -lt 16 ]]; then
        log_warn "内存不足，推荐32GB以上 (当前: ${TOTAL_MEM}GB)"
    else
        log_info "内存: ${TOTAL_MEM}GB ✓"
    fi
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $DISK_SPACE -lt 10 ]]; then
        log_error "磁盘空间不足，需要至少10GB (可用: ${DISK_SPACE}GB)"
        exit 1
    else
        log_info "磁盘空间: ${DISK_SPACE}GB可用 ✓"
    fi
    
    # 检查Python版本
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        log_info "Python版本: $PYTHON_VERSION ✓"
    else
        log_error "Python3 未安装"
        exit 1
    fi
    
    # 检查Docker
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log_info "Docker版本: $DOCKER_VERSION ✓"
        DOCKER_AVAILABLE=true
    else
        log_warn "Docker未安装，将使用本地部署"
        DOCKER_AVAILABLE=false
    fi
    
    # 检查端口占用
    check_ports
    
    log_success "环境检查完成"
}

# 检查端口占用
check_ports() {
    local ports=($SERVICE_PORT $NGINX_PORT $GRAFANA_PORT $PROMETHEUS_PORT)
    local occupied_ports=()
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            occupied_ports+=($port)
        fi
    done
    
    if [[ ${#occupied_ports[@]} -gt 0 ]]; then
        log_warn "以下端口已被占用: ${occupied_ports[*]}"
        echo "是否继续安装？占用的端口可能导致服务无法启动。"
        read -p "继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 选择部署方式
choose_deployment_method() {
    echo
    log_step "选择部署方式"
    echo "1. Docker部署 (推荐) - 自动化程度高，易于管理"
    echo "2. 本地部署 - 直接在系统上安装，性能更好"
    echo "3. 仅安装依赖 - 只安装必要的依赖包"
    echo
    
    while true; do
        read -p "请选择部署方式 [1-3]: " choice
        case $choice in
            1)
                if [[ "$DOCKER_AVAILABLE" == "true" ]]; then
                    DEPLOYMENT_METHOD="docker"
                    break
                else
                    log_error "Docker未安装，请选择其他方式或先安装Docker"
                fi
                ;;
            2)
                DEPLOYMENT_METHOD="local"
                break
                ;;
            3)
                DEPLOYMENT_METHOD="deps_only"
                break
                ;;
            *)
                echo "请输入1-3之间的数字"
                ;;
        esac
    done
    
    log_info "已选择: $DEPLOYMENT_METHOD 部署"
}

# 安装系统依赖
install_system_dependencies() {
    log_step "安装系统依赖..."
    
    # 更新包列表
    sudo apt-get update -qq
    
    # 安装基础依赖
    sudo apt-get install -y -qq \
        curl \
        wget \
        git \
        unzip \
        sqlite3 \
        libsqlite3-dev \
        python3-dev \
        python3-pip \
        python3-venv \
        build-essential \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        pkg-config \
        htop \
        tree \
        jq
    
    # 安装ModelScope Library依赖
    log_info "安装ModelScope Library依赖..."
    pip3 install --user modelscope
    
    log_success "系统依赖安装完成"
}

# Docker部署
deploy_with_docker() {
    log_step "开始Docker部署..."
    
    # 创建项目目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 复制文件
    cp -r ../* . 2>/dev/null || true
    
    # 创建数据目录
    mkdir -p data logs reports backups
    
    # 构建并启动服务
    log_info "构建Docker镜像..."
    docker-compose build --no-cache
    
    log_info "启动服务..."
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_success "Docker部署成功！"
        show_service_info
    else
        log_error "Docker部署失败，请检查日志"
        docker-compose logs
        exit 1
    fi
}

# 本地部署
deploy_locally() {
    log_step "开始本地部署..."
    
    # 创建虚拟环境
    VENV_DIR="$HOME/market-price-env"
    if [[ -d "$VENV_DIR" ]]; then
        rm -rf "$VENV_DIR"
    fi
    
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # 升级pip
    pip install --upgrade pip
    
    # 安装Python依赖
    log_info "安装Python依赖..."
    pip install -r requirements.txt
    
    # 创建应用目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 复制应用文件
    cp ../market_crawler.py .
    cp ../api_server.py .
    cp ../database_manager.py .
    cp ../location_service.py .
    cp ../scheduler_service.py .
    cp ../requirements.txt .
    
    # 创建目录结构
    mkdir -p data logs reports backups config
    
    # 创建配置文件
    create_config_files
    
    # 初始化数据库
    python -c "from database_manager import DatabaseManager; DatabaseManager('data/market_data.db')"
    
    # 创建systemd服务
    create_systemd_services
    
    # 启动服务
    sudo systemctl start market-price-api.service
    sudo systemctl start market-price-scheduler.service
    
    log_success "本地部署成功！"
    show_service_info
}

# 创建配置文件
create_config_files() {
    # 应用配置
    cat > config/app_config.json << EOF
{
    "app_name": "$PLUGIN_NAME",
    "version": "$PLUGIN_VERSION",
    "api_host": "0.0.0.0",
    "api_port": $SERVICE_PORT,
    "db_path": "data/market_data.db",
    "log_level": "INFO",
    "data_retention_days": 90,
    "enable_monitoring": true
}
EOF

    # 调度器配置
    cat > scheduler_config.json << EOF
{
    "crawl_interval_minutes": 30,
    "cleanup_interval_hours": 24,
    "report_interval_hours": 6,
    "health_check_interval_minutes": 5,
    "data_retention_days": 90,
    "max_retry_attempts": 3,
    "retry_delay_seconds": 60,
    "enable_notifications": false,
    "provinces_to_crawl": [],
    "priority_varieties": ["白萝卜", "土豆", "白菜", "西红柿", "黄瓜"],
    "performance_monitoring": true
}
EOF

    # 环境变量
    cat > .env << EOF
API_HOST=0.0.0.0
API_PORT=$SERVICE_PORT
DB_PATH=data/market_data.db
LOG_LEVEL=INFO
PYTHONPATH=.
EOF
}

# 创建systemd服务
create_systemd_services() {
    local user=$(whoami)
    local venv_dir="$HOME/market-price-env"
    
    # API服务
    sudo tee /etc/systemd/system/market-price-api.service > /dev/null << EOF
[Unit]
Description=Market Price API Service
After=network.target

[Service]
Type=simple
User=$user
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$venv_dir/bin
ExecStart=$venv_dir/bin/python api_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 调度器服务
    sudo tee /etc/systemd/system/market-price-scheduler.service > /dev/null << EOF
[Unit]
Description=Market Price Scheduler Service
After=network.target

[Service]
Type=simple
User=$user
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$venv_dir/bin
ExecStart=$venv_dir/bin/python scheduler_service.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable market-price-api.service
    sudo systemctl enable market-price-scheduler.service
}

# 显示服务信息
show_service_info() {
    echo
    log_success "🎉 部署完成！"
    echo
    echo -e "${PURPLE}=== 服务访问地址 ===${NC}"
    echo "🌐 API服务:      http://localhost:$SERVICE_PORT"
    echo "📚 API文档:      http://localhost:$SERVICE_PORT/docs"
    echo "❤️  健康检查:    http://localhost:$SERVICE_PORT/api/health"
    
    if [[ "$DEPLOYMENT_METHOD" == "docker" ]]; then
        echo "🔧 Nginx代理:    http://localhost:$NGINX_PORT"
        echo "📊 Grafana监控:  http://localhost:$GRAFANA_PORT (admin/admin123)"
        echo "📈 Prometheus:   http://localhost:$PROMETHEUS_PORT"
    fi
    
    echo
    echo -e "${PURPLE}=== 管理命令 ===${NC}"
    if [[ "$DEPLOYMENT_METHOD" == "docker" ]]; then
        echo "启动服务: cd $INSTALL_DIR && docker-compose up -d"
        echo "停止服务: cd $INSTALL_DIR && docker-compose down"
        echo "查看状态: cd $INSTALL_DIR && docker-compose ps"
        echo "查看日志: cd $INSTALL_DIR && docker-compose logs -f"
    else
        echo "启动服务: sudo systemctl start market-price-api.service"
        echo "停止服务: sudo systemctl stop market-price-api.service"
        echo "查看状态: sudo systemctl status market-price-api.service"
        echo "查看日志: sudo journalctl -u market-price-api.service -f"
    fi
    
    echo
    echo -e "${PURPLE}=== API使用示例 ===${NC}"
    echo "# 健康检查"
    echo "curl http://localhost:$SERVICE_PORT/api/health"
    echo
    echo "# 获取省份列表"
    echo "curl http://localhost:$SERVICE_PORT/api/provinces"
    echo
    echo "# 查询价格数据"
    echo "curl -X POST http://localhost:$SERVICE_PORT/api/prices/query \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"province\":\"广东省\",\"variety_name\":\"白萝卜\",\"limit\":10}'"
    echo
    echo -e "${GREEN}安装目录: $INSTALL_DIR${NC}"
    echo -e "${GREEN}配置文件: $INSTALL_DIR/config/${NC}"
    echo
}

# 测试服务
test_services() {
    log_step "测试服务..."
    
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f http://localhost:$SERVICE_PORT/api/health > /dev/null 2>&1; then
            log_success "服务测试通过 ✓"
            return 0
        fi
        
        log_info "等待服务启动... ($attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    log_warn "服务测试超时，请手动检查服务状态"
    return 1
}

# 清理函数
cleanup() {
    if [[ $? -ne 0 ]]; then
        log_error "部署过程中出现错误"
        echo "如需帮助，请查看日志或联系技术支持"
    fi
}

# 主函数
main() {
    trap cleanup EXIT
    
    show_welcome
    
    read -p "按回车键开始部署..." -r
    
    check_environment
    choose_deployment_method
    install_system_dependencies
    
    case $DEPLOYMENT_METHOD in
        "docker")
            deploy_with_docker
            ;;
        "local")
            deploy_locally
            ;;
        "deps_only")
            log_success "依赖安装完成！"
            exit 0
            ;;
    esac
    
    test_services
    
    echo
    log_success "🎉 $PLUGIN_NAME 部署完成！"
    echo "感谢使用本插件，如有问题请联系技术支持。"
}

# 运行主程序
main "$@"
