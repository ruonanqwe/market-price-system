#!/bin/bash

# Docker容器化部署脚本
# 适用于 ubuntu22.04-py311-torch2.3.1-1.27.0 环境

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

# 检查Docker环境
check_docker() {
    log_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        echo "安装命令:"
        echo "curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "sudo sh get-docker.sh"
        echo "sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        echo "安装命令:"
        echo "sudo curl -L \"https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
        echo "sudo chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
    
    # 检查Docker服务状态
    if ! sudo systemctl is-active --quiet docker; then
        log_warn "Docker服务未运行，正在启动..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    log_info "Docker环境检查完成"
}

# 创建项目目录
create_project_structure() {
    log_step "创建项目目录结构..."
    
    PROJECT_DIR="$HOME/market-price-docker"
    
    if [[ -d "$PROJECT_DIR" ]]; then
        log_warn "项目目录已存在，将备份现有目录"
        mv "$PROJECT_DIR" "${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # 创建数据目录
    mkdir -p data logs reports backups ssl grafana/provisioning
    
    # 复制应用文件
    cp *.py .
    cp requirements.txt .
    cp Dockerfile .
    cp docker-compose.yml .
    cp nginx.conf .
    
    log_info "项目目录创建完成: $PROJECT_DIR"
}

# 创建配置文件
create_config_files() {
    log_step "创建配置文件..."
    
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
    "notification_webhook": "",
    "provinces_to_crawl": [],
    "priority_varieties": ["白萝卜", "土豆", "白菜", "西红柿", "黄瓜"],
    "performance_monitoring": true
}
EOF

    # Prometheus配置
    cat > prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'market-api'
    static_configs:
      - targets: ['market-api:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s
EOF

    # 环境变量文件
    cat > .env << EOF
# 应用配置
API_HOST=0.0.0.0
API_PORT=8000
DB_PATH=/app/market_data.db
LOG_LEVEL=INFO

# 数据库配置
SQLITE_DB_PATH=./market_data.db

# 监控配置
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
GRAFANA_ADMIN_PASSWORD=admin123

# Nginx配置
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
EOF

    log_info "配置文件创建完成"
}

# 创建管理脚本
create_management_scripts() {
    log_step "创建Docker管理脚本..."
    
    # 启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
echo "启动农产品市场价格监控系统（Docker版）..."

# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

echo "系统启动完成！"
echo
echo "服务访问地址:"
echo "  API服务: http://localhost:8000"
echo "  API文档: http://localhost:8000/docs"
echo "  Nginx代理: http://localhost:80"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana: http://localhost:3000 (admin/admin123)"
echo
echo "查看服务状态: docker-compose ps"
echo "查看日志: docker-compose logs -f [service-name]"
EOF

    # 停止脚本
    cat > stop.sh << 'EOF'
#!/bin/bash
echo "停止农产品市场价格监控系统..."
docker-compose down
echo "系统已停止"
EOF

    # 重启脚本
    cat > restart.sh << 'EOF'
#!/bin/bash
echo "重启农产品市场价格监控系统..."
docker-compose down
docker-compose up -d
echo "系统已重启"
EOF

    # 状态检查脚本
    cat > status.sh << 'EOF'
#!/bin/bash
echo "=== 农产品市场价格监控系统状态（Docker版）==="
echo
echo "容器状态:"
docker-compose ps
echo
echo "系统资源使用:"
docker stats --no-stream
echo
echo "最近日志:"
echo "--- API服务日志 ---"
docker-compose logs --tail=10 market-api
echo
echo "--- 调度器日志 ---"
docker-compose logs --tail=10 scheduler
EOF

    # 日志查看脚本
    cat > logs.sh << 'EOF'
#!/bin/bash
if [[ -z "$1" ]]; then
    echo "用法: $0 [service-name]"
    echo "可用服务:"
    echo "  market-api    - API服务"
    echo "  scheduler     - 调度器服务"
    echo "  nginx         - Nginx代理"
    echo "  prometheus    - Prometheus监控"
    echo "  grafana       - Grafana仪表板"
    echo
    echo "查看所有日志: docker-compose logs -f"
    exit 1
fi

docker-compose logs -f "$1"
EOF

    # 备份脚本
    cat > backup.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backups/docker_backup_$TIMESTAMP.tar.gz"

echo "创建Docker数据备份..."
mkdir -p backups

# 停止服务（可选）
read -p "是否停止服务进行备份？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down
    RESTART_AFTER=true
else
    RESTART_AFTER=false
fi

# 创建备份
tar -czf "$BACKUP_FILE" data/ logs/ reports/ market_data.db
echo "备份完成: $BACKUP_FILE"

# 重启服务
if [[ "$RESTART_AFTER" == "true" ]]; then
    docker-compose up -d
    echo "服务已重启"
fi
EOF

    # 更新脚本
    cat > update.sh << 'EOF'
#!/bin/bash
echo "更新农产品市场价格监控系统..."

# 拉取最新代码（如果使用Git）
if [[ -d ".git" ]]; then
    git pull
fi

# 重新构建镜像
docker-compose build --no-cache

# 重启服务
docker-compose down
docker-compose up -d

echo "系统更新完成"
EOF

    # 清理脚本
    cat > cleanup.sh << 'EOF'
#!/bin/bash
echo "清理Docker资源..."

# 停止并删除容器
docker-compose down

# 删除未使用的镜像
docker image prune -f

# 删除未使用的卷
docker volume prune -f

# 删除未使用的网络
docker network prune -f

echo "清理完成"
EOF

    # 设置执行权限
    chmod +x *.sh
    
    log_info "管理脚本创建完成"
}

# 初始化数据库
initialize_database() {
    log_step "初始化数据库..."
    
    # 创建空的数据库文件
    touch market_data.db
    
    log_info "数据库文件创建完成"
}

# 构建和启动服务
build_and_start() {
    log_step "构建Docker镜像并启动服务..."
    
    # 构建镜像
    docker-compose build
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_info "服务启动成功"
    else
        log_error "服务启动失败，请检查日志"
        docker-compose logs
        exit 1
    fi
}

# 测试服务
test_services() {
    log_step "测试服务..."
    
    # 测试API服务
    if curl -f http://localhost:8000/api/health > /dev/null 2>&1; then
        log_info "API服务测试通过"
    else
        log_warn "API服务测试失败，可能需要更多时间启动"
    fi
    
    # 测试Nginx代理
    if curl -f http://localhost:80/api/health > /dev/null 2>&1; then
        log_info "Nginx代理测试通过"
    else
        log_warn "Nginx代理测试失败"
    fi
}

# 显示完成信息
show_completion_info() {
    log_info "Docker部署完成！"
    echo
    echo "=== 农产品市场价格监控系统（Docker版）==="
    echo "项目目录: $(pwd)"
    echo
    echo "服务访问地址:"
    echo "  API服务: http://localhost:8000"
    echo "  API文档: http://localhost:8000/docs"
    echo "  Nginx代理: http://localhost:80"
    echo "  Prometheus监控: http://localhost:9090"
    echo "  Grafana仪表板: http://localhost:3000 (admin/admin123)"
    echo
    echo "管理命令:"
    echo "  启动系统: ./start.sh"
    echo "  停止系统: ./stop.sh"
    echo "  重启系统: ./restart.sh"
    echo "  查看状态: ./status.sh"
    echo "  查看日志: ./logs.sh [service-name]"
    echo "  数据备份: ./backup.sh"
    echo "  系统更新: ./update.sh"
    echo "  清理资源: ./cleanup.sh"
    echo
    echo "Docker命令:"
    echo "  查看容器: docker-compose ps"
    echo "  查看日志: docker-compose logs -f"
    echo "  进入容器: docker-compose exec market-api bash"
    echo
    echo "配置文件:"
    echo "  Docker配置: docker-compose.yml"
    echo "  调度配置: scheduler_config.json"
    echo "  环境变量: .env"
}

# 主安装流程
main() {
    echo "=== 农产品市场价格监控系统Docker部署程序 ==="
    echo "适用于 ubuntu22.04-py311-torch2.3.1-1.27.0 环境"
    echo
    
    check_docker
    create_project_structure
    create_config_files
    create_management_scripts
    initialize_database
    build_and_start
    test_services
    show_completion_info
}

# 运行主程序
main "$@"
